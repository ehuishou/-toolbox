import '../ledger_tables.dart';

/// 一条从外部捞到的原始交易，还没入账。
class RawBill {
  const RawBill({
    required this.sourceType,
    required this.sourceId,
    required this.amountCents,
    required this.kind,
    required this.occurredAt,
    required this.rawText,
    this.merchant,
    this.counterparty,
  });

  /// 来源类型，用于去重和让用户知道这笔账哪来的
  final BillSourceType sourceType;

  /// 来源内的唯一标识。CSV 用订单号，通知用 (包名+时间戳+金额) 的哈希。
  /// 去重的主键，必须稳定 —— 同一笔交易重复导入时必须算出同一个值。
  final String sourceId;

  final int amountCents; // 正数，方向由 kind 决定，与现有 LedgerEntries 一致
  final EntryKind kind;
  final DateTime occurredAt;

  /// 原始文本，出错时用于排查，也给用户看"这笔账是从哪句话解析出来的"
  final String rawText;

  final String? merchant; // 商户名，分类推断的主要依据
  final String? counterparty; // 交易对方
}

/// 所有数据源实现这个接口
abstract class BillSource {
  BillSourceType get type;

  /// 解析原始输入，产出待确认交易。
  /// 解析失败的行不抛异常，而是跳过并记录 —— 一行格式变了不能让整个导入失败。
  Future<BillParseResult> parse(dynamic input);
}

class BillParseResult {
  const BillParseResult({required this.bills, required this.failures});

  final List<RawBill> bills;

  /// 解析失败的原始行，展示给用户："3 行无法识别，是否查看"
  /// 这个字段很重要 —— 支付平台改格式时，这里是唯一的预警信号。
  final List<String> failures;
}
