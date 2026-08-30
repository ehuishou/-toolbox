import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/util/money.dart';
import 'ledger_providers.dart';
import 'widgets/entry_list.dart';
import 'widgets/stats_view.dart';

class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const _MonthPicker(),
          bottom: const TabBar(
            tabs: [Tab(text: '流水'), Tab(text: '统计')],
          ),
        ),
        body: const Column(
          children: [
            _SummaryBar(),
            Expanded(
              child: TabBarView(
                children: [EntryList(), StatsView()],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/ledger/entry'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final label = DateFormat('yyyy年M月').format(month);

    void shift(int delta) {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(month.year, month.month + delta);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => shift(-1),
        ),
        Text(label, style: const TextStyle(fontSize: 17)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => shift(1),
        ),
      ],
    );
  }
}

class _SummaryBar extends ConsumerWidget {
  const _SummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: theme.colorScheme.surfaceContainerLow,
      child: summary.when(
        loading: () => const SizedBox(height: 44),
        error: (e, _) => Text('加载失败：$e'),
        data: (data) => Row(
          children: [
            _SummaryCell(label: '支出', cents: data.expenseCents),
            _SummaryCell(label: '收入', cents: data.incomeCents),
            _SummaryCell(label: '结余', cents: data.balanceCents),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            formatCents(cents),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
