import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/dedup.dart';
import 'ledger_tables.dart';

part 'ledger_dao.g.dart';

/// 一条流水 + 关联的分类和账户
class EntryDetail {
  const EntryDetail({
    required this.entry,
    this.category,
    this.account,
    this.toAccount,
  });

  final LedgerEntry entry;
  final Category? category;
  final Account? account;
  final Account? toAccount;

  /// 有符号金额，用于余额计算
  int get signedCents =>
      entry.kind == EntryKind.income ? entry.amountCents : -entry.amountCents;
}

class PeriodSummary {
  const PeriodSummary({this.incomeCents = 0, this.expenseCents = 0});

  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;
}

class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.totalCents,
  });

  final int? categoryId;
  final String name;
  final String iconKey;
  final int colorValue;
  final int totalCents;
}

@DriftAccessor(tables: [Accounts, Categories, LedgerEntries, PendingBills, CategoryRules])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  Expression<bool> _alive() => ledgerEntries.deletedAt.isNull();

  Stream<List<EntryDetail>> watchEntries({
    required DateTime start,
    required DateTime end,
  }) {
    final toAccounts = alias(accounts, 'to_account');

    final query = select(ledgerEntries).join([
      leftOuterJoin(
        categories,
        categories.id.equalsExp(ledgerEntries.categoryId),
      ),
      leftOuterJoin(accounts, accounts.id.equalsExp(ledgerEntries.accountId)),
      leftOuterJoin(
        toAccounts,
        toAccounts.id.equalsExp(ledgerEntries.toAccountId),
      ),
    ])
      ..where(
        ledgerEntries.occurredAt.isBiggerOrEqualValue(start) &
            ledgerEntries.occurredAt.isSmallerThanValue(end) &
            _alive(),
      )
      ..orderBy([
        OrderingTerm.desc(ledgerEntries.occurredAt),
        OrderingTerm.desc(ledgerEntries.id),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => EntryDetail(
                  entry: row.readTable(ledgerEntries),
                  category: row.readTableOrNull(categories),
                  account: row.readTableOrNull(accounts),
                  toAccount: row.readTableOrNull(toAccounts),
                ),
              )
              .toList(),
        );
  }

  Stream<PeriodSummary> watchSummary({
    required DateTime start,
    required DateTime end,
  }) {
    final total = ledgerEntries.amountCents.sum();

    final query = selectOnly(ledgerEntries)
      ..addColumns([ledgerEntries.kind, total])
      ..where(
        ledgerEntries.occurredAt.isBiggerOrEqualValue(start) &
            ledgerEntries.occurredAt.isSmallerThanValue(end) &
            _alive(),
      )
      ..groupBy([ledgerEntries.kind]);

    return query.watch().map((rows) {
      var income = 0;
      var expense = 0;
      for (final row in rows) {
        final kind = row.read(ledgerEntries.kind);
        final value = row.read(total) ?? 0;
        if (kind == EntryKind.income.name) {
          income = value;
        } else if (kind == EntryKind.expense.name) {
          expense = value;
        }
      }
      return PeriodSummary(incomeCents: income, expenseCents: expense);
    });
  }

  /// 分类占比，用于饼图
  Stream<List<CategoryTotal>> watchCategoryTotals({
    required DateTime start,
    required DateTime end,
    required EntryKind kind,
  }) {
    final total = ledgerEntries.amountCents.sum();

    final query = selectOnly(ledgerEntries).join([
      leftOuterJoin(
        categories,
        categories.id.equalsExp(ledgerEntries.categoryId),
      ),
    ])
      ..addColumns([
        ledgerEntries.categoryId,
        categories.name,
        categories.iconKey,
        categories.colorValue,
        total,
      ])
      ..where(
        ledgerEntries.occurredAt.isBiggerOrEqualValue(start) &
            ledgerEntries.occurredAt.isSmallerThanValue(end) &
            ledgerEntries.kind.equalsValue(kind) &
            _alive(),
      )
      ..groupBy([ledgerEntries.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => CategoryTotal(
                  categoryId: row.read(ledgerEntries.categoryId),
                  name: row.read(categories.name) ?? '未分类',
                  iconKey: row.read(categories.iconKey) ?? 'other',
                  colorValue: row.read(categories.colorValue) ?? 0xFF64748B,
                  totalCents: row.read(total) ?? 0,
                ),
              )
              .toList(),
        );
  }

  Stream<List<Category>> watchCategories(EntryKind kind) {
    return (select(categories)
          ..where((t) => t.kind.equalsValue(kind) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Stream<List<Account>> watchAccounts() {
    return (select(accounts)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<int> insertEntry(LedgerEntriesCompanion entry) =>
      into(ledgerEntries).insert(entry);

  Future<bool> updateEntry(LedgerEntry entry) => update(ledgerEntries)
      .replace(entry.copyWith(updatedAt: DateTime.now()));

  Future<void> softDeleteEntry(int id) async {
    await (update(ledgerEntries)..where((t) => t.id.equals(id))).write(
      LedgerEntriesCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<int> createCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  // ===== 自动记账：待确认队列 =====

  /// 未处理的待确认交易，按置信度升序（最需要人工判断的在前）。
  Stream<List<PendingBill>> watchPendingBills() {
    return (select(pendingBills)
          ..where((t) => t.resolvedEntryId.isNull() & t.ignoredAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.confidence),
            (t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  /// 插入待确认交易。返回 0 表示被 (sourceType, sourceId) 唯一索引忽略（重复导入）。
  Future<int> insertPendingBill(PendingBillsCompanion bill) =>
      into(pendingBills).insert(bill, mode: InsertMode.insertOrIgnore);

  Future<void> resolvePendingBill(int id, int entryId) async {
    await (update(pendingBills)..where((t) => t.id.equals(id))).write(
      PendingBillsCompanion(resolvedEntryId: Value(entryId)),
    );
  }

  Future<void> ignorePendingBill(int id) async {
    await (update(pendingBills)..where((t) => t.id.equals(id))).write(
      PendingBillsCompanion(ignoredAt: Value(DateTime.now())),
    );
  }

  /// 第三层去重：查正式账本里同金额同时间窗的记录，判断用户是否已手动记过。
  Stream<List<LedgerEntry>> watchEntriesNear({
    required DateTime time,
    required int amountCents,
    required EntryKind kind,
  }) {
    const window = BillDeduplicator.dedupWindow;
    return (select(ledgerEntries)
          ..where(
            (t) =>
                t.amountCents.equals(amountCents) &
                t.kind.equalsValue(kind) &
                t.occurredAt.isBiggerOrEqualValue(time.subtract(window)) &
                t.occurredAt.isSmallerOrEqualValue(time.add(window)) &
                t.deletedAt.isNull(),
          ))
        .watch();
  }

  // ===== 自动记账：分类规则 =====

  Stream<List<CategoryRule>> watchCategoryRules() =>
      (select(categoryRules)..orderBy([(t) => OrderingTerm.desc(t.hitCount)]))
          .watch();

  /// 确认待确认账单：写入正式流水，标记已处理，更新分类规则。
  Future<int> confirmPendingBill({
    required int pendingBillId,
    required int accountId,
    int? categoryId,
    String? note,
  }) async {
    final bill = await (select(pendingBills)
          ..where((t) => t.id.equals(pendingBillId)))
        .getSingle();

    // 插入正式流水
    final entryId = await into(ledgerEntries).insert(
      LedgerEntriesCompanion.insert(
        kind: bill.kind,
        amountCents: bill.amountCents,
        accountId: accountId,
        categoryId: Value(categoryId ?? bill.suggestedCategoryId),
        occurredAt: bill.occurredAt,
        note: Value(note ?? bill.merchant ?? ''),
        sourceType: Value(bill.sourceType),
        sourceId: Value(bill.sourceId),
      ),
    );

    // 标记待确认项为已处理
    await resolvePendingBill(pendingBillId, entryId);

    // 更新规则命中次数（学习用户修正）
    final finalCategoryId = categoryId ?? bill.suggestedCategoryId;
    if (finalCategoryId != null && bill.merchant != null) {
      await _updateCategoryRuleHitCount(bill.merchant!, finalCategoryId);
    }

    return entryId;
  }

  /// 内部方法：更新或插入分类规则，提取关键词。
  Future<void> _updateCategoryRuleHitCount(
      String merchant, int categoryId) async {
    // 提取关键词：取前 10 个字符或到第一个空格/标点
    final keyword = merchant.length <= 10
        ? merchant
        : merchant.substring(
            0,
            merchant.indexOf(RegExp(r'[\s\-\.]')) > 0
                ? merchant.indexOf(RegExp(r'[\s\-\.]'))
                : 10);

    await recordCategoryRuleHit(keyword, categoryId);
  }

  /// 用户确认（或修正）分类后调用：已存在的规则 hitCount +1，没有则新建。
  Future<void> recordCategoryRuleHit(String keyword, int categoryId) async {
    final existing = await (select(categoryRules)
          ..where((t) => t.keyword.equals(keyword)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(categoryRules)..where((t) => t.id.equals(existing.id)))
          .write(CategoryRulesCompanion(
              hitCount: Value(existing.hitCount + 1)));
    } else {
      await into(categoryRules).insert(
        CategoryRulesCompanion.insert(
          keyword: keyword,
          categoryId: categoryId,
          isBuiltIn: const Value(false),
        ),
      );
    }
  }
}
