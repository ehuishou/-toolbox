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
  tables: [Accounts, Categories, LedgerEntries],
  daos: [LedgerDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
          await _seedAccounts();
        },
        // 后续加表时：schemaVersion++ 并在这里写 onUpgrade
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
