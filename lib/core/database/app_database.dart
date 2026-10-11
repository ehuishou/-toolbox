import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/ledger/data/ledger_dao.dart';
import '../../features/ledger/data/ledger_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  // 新工具的表加在这里
  tables: [Accounts, Categories, LedgerEntries, PendingBills, CategoryRules],
  daos: [LedgerDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
          await _seedAccounts();
          await _seedCategoryRules();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 -> v2：新增自动记账的两张表 + LedgerEntries 加来源两列
            await m.createTable(pendingBills);
            await m.createTable(categoryRules);
            await m.addColumn(ledgerEntries, ledgerEntries.sourceType);
            await m.addColumn(ledgerEntries, ledgerEntries.sourceId);
            await _seedCategoryRules();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedCategories() async {
    const expense = <(String, String, int)>[
      ('餐饮', 'food', 0xFFF97316),
      ('交通', 'transport', 0xFF3B82F6),
      ('购物', 'shopping', 0xFFEC4899),
      ('居住', 'home', 0xFF8B5CF6),
      ('娱乐', 'entertainment', 0xFF06B6D4),
      ('医疗', 'medical', 0xFFEF4444),
      ('学习', 'education', 0xFF10B981),
      ('其他', 'other', 0xFF64748B),
    ];
    const income = <(String, String, int)>[
      ('工资', 'salary', 0xFF10B981),
      ('奖金', 'bonus', 0xFFF59E0B),
      ('理财', 'investment', 0xFF6366F1),
      ('其他', 'other', 0xFF64748B),
    ];

    await batch((b) {
      var order = 0;
      for (final (name, icon, color) in expense) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: name,
            iconKey: icon,
            colorValue: color,
            kind: EntryKind.expense,
            sortOrder: Value(order++),
            isBuiltIn: const Value(true),
          ),
        );
      }
      order = 0;
      for (final (name, icon, color) in income) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: name,
            iconKey: icon,
            colorValue: color,
            kind: EntryKind.income,
            sortOrder: Value(order++),
            isBuiltIn: const Value(true),
          ),
        );
      }
    });
  }

  Future<void> _seedAccounts() async {
    await batch((b) {
      b.insertAll(accounts, [
        AccountsCompanion.insert(
          name: '现金',
          iconKey: const Value('cash'),
          colorValue: 0xFF10B981,
          sortOrder: const Value(0),
        ),
        AccountsCompanion.insert(
          name: '银行卡',
          iconKey: const Value('bank'),
          colorValue: 0xFF3B82F6,
          sortOrder: const Value(1),
        ),
        AccountsCompanion.insert(
          name: '移动支付',
          iconKey: const Value('wallet'),
          colorValue: 0xFFF59E0B,
          sortOrder: const Value(2),
        ),
      ]);
    });
  }

  Future<void> _seedCategoryRules() async {
    // 关键词 → 支出分类的 iconKey（与 _seedCategories 里的 iconKey 对应）
    const rules = <String, String>{
      // 餐饮
      '美团': 'food', '饿了么': 'food', '肯德基': 'food', '麦当劳': 'food', '星巴克': 'food',
      // 交通
      '滴滴': 'transport', '地铁': 'transport', '公交': 'transport', '高铁': 'transport', '加油': 'transport',
      // 购物
      '淘宝': 'shopping', '京东': 'shopping', '拼多多': 'shopping', '天猫': 'shopping',
      // 居住
      '房租': 'home', '水费': 'home', '电费': 'home', '燃气': 'home', '物业': 'home',
      // 娱乐
      '电影': 'entertainment', '游戏': 'entertainment', '网易云': 'entertainment', '腾讯视频': 'entertainment',
      // 医疗
      '药店': 'medical', '医院': 'medical', '挂号': 'medical',
    };

    final expenseCategories = await (select(categories)
          ..where((t) => t.kind.equalsValue(EntryKind.expense)))
        .get();
    final idByIcon = <String, int>{
      for (final c in expenseCategories) c.iconKey: c.id,
    };

    await batch((b) {
      for (final entry in rules.entries) {
        final categoryId = idByIcon[entry.value];
        if (categoryId == null) continue;
        b.insert(
          categoryRules,
          CategoryRulesCompanion.insert(
            keyword: entry.key,
            categoryId: categoryId,
            isBuiltIn: const Value(true),
          ),
        );
      }
    });
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'toolbox.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
