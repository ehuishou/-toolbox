import 'package:drift/drift.dart';

enum EntryKind { expense, income, transfer }

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();
  IntColumn get colorValue => integer()();

  /// 初始余额，当前余额 = 初始余额 + 流水汇总
  IntColumn get openingBalanceCents => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  TextColumn get kind => textEnum<EntryKind>()();

  /// 预留二级分类
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// 表名不叫 Transactions，避免和 Drift 自带的 Transaction 类冲突。
@DataClassName('LedgerEntry')
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<EntryKind>()();

  /// 正数存储，方向由 kind 决定
  IntColumn get amountCents => integer()();

  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// 转账的目标账户
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();

  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();

  /// 小票图片路径，留给后续 OCR 自动填单
  TextColumn get attachmentPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 软删除，为将来的多端同步留位
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [];
}
