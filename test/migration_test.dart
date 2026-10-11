import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:toolbox/core/database/app_database.dart';
import 'package:toolbox/features/ledger/data/ledger_tables.dart';

void main() {
  test('v1 -> v2 迁移：旧数据保留，新表与新列可用', () async {
    final dir = await Directory.systemTemp.createTemp('toolbox_migration');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final file = File('${dir.path}/test.sqlite');

    // 1. 用 sqlite3 直接建 v1 库（老 schema：无 PendingBills/CategoryRules，LedgerEntries 无来源两列）
    final raw = sqlite3.open(file.path);
    raw.execute(
        'CREATE TABLE accounts ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        "icon_key TEXT NOT NULL DEFAULT 'wallet', "
        'color_value INTEGER NOT NULL, '
        'opening_balance_cents INTEGER NOT NULL DEFAULT 0, '
        'sort_order INTEGER NOT NULL DEFAULT 0, '
        'is_archived INTEGER NOT NULL DEFAULT 0)');
    raw.execute(
        'CREATE TABLE categories ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'icon_key TEXT NOT NULL, '
        'color_value INTEGER NOT NULL, '
        'kind TEXT NOT NULL, '
        'parent_id INTEGER, '
        'sort_order INTEGER NOT NULL DEFAULT 0, '
        'is_built_in INTEGER NOT NULL DEFAULT 0, '
        'is_archived INTEGER NOT NULL DEFAULT 0)');
    raw.execute(
        'CREATE TABLE ledger_entries ('
        'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'kind TEXT NOT NULL, '
        'amount_cents INTEGER NOT NULL, '
        'category_id INTEGER, '
        'account_id INTEGER NOT NULL, '
        'to_account_id INTEGER, '
        "note TEXT NOT NULL DEFAULT '', "
        'occurred_at INTEGER NOT NULL, '
        'attachment_path TEXT, '
        'created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL, '
        'deleted_at INTEGER)');
    raw.execute(
        "INSERT INTO accounts (name, icon_key, color_value, opening_balance_cents, sort_order, is_archived) "
        "VALUES ('现金', 'cash', 1, 0, 0, 0)");
    raw.execute(
        "INSERT INTO categories (name, icon_key, color_value, kind, parent_id, sort_order, is_built_in, is_archived) "
        "VALUES ('餐饮', 'food', 1, 'expense', NULL, 0, 1, 0)");
    raw.execute(
        "INSERT INTO categories (name, icon_key, color_value, kind, parent_id, sort_order, is_built_in, is_archived) "
        "VALUES ('交通', 'transport', 1, 'expense', NULL, 1, 1, 0)");
    raw.execute(
        "INSERT INTO ledger_entries (kind, amount_cents, category_id, account_id, to_account_id, note, occurred_at, attachment_path, created_at, updated_at, deleted_at) "
        "VALUES ('expense', 12345, 1, 1, NULL, '', 0, NULL, 0, 0, NULL)");
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    // 2. 用 AppDatabase 打开 → 触发 onUpgrade
    final db = AppDatabase.forTesting(NativeDatabase(file));

    // 旧数据保留
    final entries = await db.select(db.ledgerEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.amountCents, 12345);
    expect(entries.single.sourceType, BillSourceType.manual); // 新列默认值
    expect(entries.single.sourceId, null);

    // 新表可用 + 分类规则已按已有分类 seed
    final rules = await db.select(db.categoryRules).get();
    expect(rules.map((r) => r.keyword), contains('美团')); // food
    expect(rules.map((r) => r.keyword), contains('滴滴')); // transport

    // 待确认表可写
    final inserted = await db.into(db.pendingBills).insert(
          PendingBillsCompanion.insert(
            sourceType: BillSourceType.alipayCsv,
            sourceId: 'test-source',
            amountCents: 100,
            kind: EntryKind.expense,
            occurredAt: DateTime(2024, 1, 1),
            rawText: '',
          ),
        );
    expect(inserted, greaterThan(0));

    await db.close();
  });
}
