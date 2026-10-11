import 'package:flutter_test/flutter_test.dart';

import 'package:toolbox/features/ledger/data/import/bill_source.dart';
import 'package:toolbox/features/ledger/data/ledger_tables.dart';
import 'package:toolbox/features/ledger/domain/dedup.dart';

var _billCounter = 0;

RawBill _bill({
  required int amount,
  required EntryKind kind,
  required DateTime time,
}) {
  return RawBill(
    sourceType: BillSourceType.alipayCsv,
    sourceId: 'id-${_billCounter++}', // 确保每个账单有唯一 ID
    amountCents: amount,
    kind: kind,
    occurredAt: time,
    rawText: '',
  );
}

void main() {
  final base = DateTime(2024, 1, 5, 12, 30);

  test('正向：金额相同 + 同向 + 时间在窗口内 → 疑似重复', () {
    final a = _bill(amount: 3550, kind: EntryKind.expense, time: base);
    final b = _bill(
        amount: 3550,
        kind: EntryKind.expense,
        time: base.add(const Duration(minutes: 4)));
    expect(BillDeduplicator.isLikelyDuplicate(a, b), isTrue);
  });

  test('反向：同金额同向但时间超窗 → 不判重', () {
    final a = _bill(amount: 3550, kind: EntryKind.expense, time: base);
    final b = _bill(
        amount: 3550,
        kind: EntryKind.expense,
        time: base.add(const Duration(minutes: 6)));
    expect(BillDeduplicator.isLikelyDuplicate(a, b), isFalse);
  });

  test('反向：同金额同时间但方向不同 → 不判重', () {
    final a = _bill(amount: 3550, kind: EntryKind.expense, time: base);
    final b = _bill(amount: 3550, kind: EntryKind.income, time: base);
    expect(BillDeduplicator.isLikelyDuplicate(a, b), isFalse);
  });

  test('反向：同方向同时间但金额不同 → 不判重', () {
    final a = _bill(amount: 3550, kind: EntryKind.expense, time: base);
    final b = _bill(amount: 3500, kind: EntryKind.expense, time: base);
    expect(BillDeduplicator.isLikelyDuplicate(a, b), isFalse);
  });
}
