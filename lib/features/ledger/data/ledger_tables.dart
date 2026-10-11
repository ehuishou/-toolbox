import 'package:drift/drift.dart';

enum EntryKind { expense, income, transfer }

/// 账单来源类型。手动记账为 manual。
/// 注意：支付宝/微信的 CSV、通知、短信产出的都是"待确认交易"，
/// 但来源不同，去重和展示时都要区分。
enum BillSourceType { alipayCsv, wechatCsv, notification, sms, manual }

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

  /// 这笔账的来源，手动记账为 manual
  TextColumn get sourceType =>
      textEnum<BillSourceType>().withDefault(const Constant('manual'))();

  /// 来源标识，配合 sourceType 做跨表去重
  TextColumn get sourceId => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [];
}

/// 待确认队列。解析出来但用户还没确认的交易暂存在这里。
/// 不直接写 LedgerEntries —— 自动解析会出错，不能污染正式账本。
@DataClassName('PendingBill')
class PendingBills extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceType => textEnum<BillSourceType>()();

  /// 去重键，唯一索引见下方 uniqueKeys
  TextColumn get sourceId => text()();

  IntColumn get amountCents => integer()();
  TextColumn get kind => textEnum<EntryKind>()();
  DateTimeColumn get occurredAt => dateTime()();

  TextColumn get merchant => text().nullable()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get rawText => text()();

  /// 推断出的分类，用户可改。null 表示推断不出来
  IntColumn get suggestedCategoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get suggestedAccountId =>
      integer().nullable().references(Accounts, #id)();

  /// 推断置信度 0-100，低于阈值的排在队列前面优先让用户确认
  IntColumn get confidence => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 用户确认后指向生成的正式流水；被忽略的记 ignoredAt
  IntColumn get resolvedEntryId =>
      integer().nullable().references(LedgerEntries, #id)();
  DateTimeColumn get ignoredAt => dateTime().nullable()();

  /// 同一来源的同一笔交易只能有一条 —— 这是去重的最后一道防线，
  /// 数据库层面兜住，避免应用层逻辑漏了导致重复记账。
  @override
  List<Set<Column>> get uniqueKeys => [{sourceType, sourceId}];
}

/// 商户名 → 分类的映射规则。内置一批，用户的修正也存这里。
@DataClassName('CategoryRule')
class CategoryRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 匹配关键词，如"美团"、"滴滴"
  TextColumn get keyword => text()();

  IntColumn get categoryId => integer().references(Categories, #id)();

  /// 命中次数，越高越优先。用户每次确认就 +1，实现"越用越准"
  IntColumn get hitCount => integer().withDefault(const Constant(0))();

  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [{keyword}];
}
