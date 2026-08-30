import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
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

@DriftAccessor(tables: [Accounts, Categories, LedgerEntries])
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
}
