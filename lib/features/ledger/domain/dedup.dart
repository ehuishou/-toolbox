import '../data/import/bill_source.dart';

/// 去重策略。三层，从严到宽。
///
/// 同一笔交易可能从多条路径进来：微信付款既有通知，月底导 CSV 又有一条。
/// 去重失败会让用户看到重复账目，直接失去对整个功能的信任。
class BillDeduplicator {
  /// 第二层跨来源模糊去重的时间窗口。
  ///
  /// 取 ±5 分钟：通知是即时的，CSV 里的时间是支付平台记录的，两者可能有几分钟差。
  /// 窗口太大会误杀（连续买两杯同价咖啡），太小会漏。5 分钟 + 金额相同是经验平衡点。
  static const Duration dedupWindow = Duration(minutes: 5);

  /// 第一层：来源内精确去重 —— 同 sourceType + sourceId 视为同一笔。
  /// 靠 PendingBills 表的唯一索引 (sourceType, sourceId) 兜底，不在这里做。

  /// 第二层：跨来源模糊去重 —— 金额相同 + 时间在窗口内，判为"疑似重复"。
  ///
  /// 命中后【不自动丢弃】，而是标记为疑似重复让用户判断 ——
  /// 误判两笔真实交易为重复，比多一条待确认更难被发现。
  static bool isLikelyDuplicate(RawBill a, RawBill b) {
    // 同一来源且 sourceId 相同 → 精确重复
    if (a.sourceType == b.sourceType && a.sourceId == b.sourceId) {
      return true;
    }

    // 跨来源：金额 + 时间窗口，但商户名不同则大概率不是重复
    if (a.amountCents == b.amountCents &&
        a.kind == b.kind &&
        a.occurredAt.difference(b.occurredAt).abs() <= dedupWindow) {
      // 如果商户名完全不同，大概率不是重复（连买两杯咖啡的情况）
      if (a.merchant != null &&
          b.merchant != null &&
          a.merchant != b.merchant) {
        return false;
      }
      return true; // 疑似重复，让用户判断
    }

    return false;
  }

  /// 第三层：与正式账本比对 —— 用户可能已经手动记过这笔账。
  /// 查 LedgerEntries 里同金额同时间窗的记录（见 LedgerDao.watchEntriesNear）。
}
