import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/ledger_dao.dart';
import '../data/ledger_tables.dart';

final ledgerDaoProvider = Provider<LedgerDao>(
  (ref) => ref.watch(appDatabaseProvider).ledgerDao,
);

/// 当前查看的月份，统一驱动流水列表和统计
final selectedMonthProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

({DateTime start, DateTime end}) _monthRange(DateTime month) => (
      start: DateTime(month.year, month.month),
      end: DateTime(month.year, month.month + 1),
    );

final monthEntriesProvider = StreamProvider<List<EntryDetail>>((ref) {
  final range = _monthRange(ref.watch(selectedMonthProvider));
  return ref
      .watch(ledgerDaoProvider)
      .watchEntries(start: range.start, end: range.end);
});

final monthSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  final range = _monthRange(ref.watch(selectedMonthProvider));
  return ref
      .watch(ledgerDaoProvider)
      .watchSummary(start: range.start, end: range.end);
});

/// 统计页当前查看的类型（支出/收入）
final statsKindProvider = StateProvider<EntryKind>((_) => EntryKind.expense);

final categoryTotalsProvider = StreamProvider<List<CategoryTotal>>((ref) {
  final range = _monthRange(ref.watch(selectedMonthProvider));
  return ref.watch(ledgerDaoProvider).watchCategoryTotals(
        start: range.start,
        end: range.end,
        kind: ref.watch(statsKindProvider),
      );
});

final categoriesProvider =
    StreamProvider.family<List<Category>, EntryKind>((ref, kind) {
  return ref.watch(ledgerDaoProvider).watchCategories(kind);
});

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(ledgerDaoProvider).watchAccounts(),
);
