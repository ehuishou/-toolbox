import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_icons.dart';
import '../../../../core/util/money.dart';
import '../../data/ledger_tables.dart';
import '../ledger_providers.dart';

class StatsView extends ConsumerWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(statsKindProvider);
    final totals = ref.watch(categoryTotalsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<EntryKind>(
            segments: const [
              ButtonSegment(value: EntryKind.expense, label: Text('支出')),
              ButtonSegment(value: EntryKind.income, label: Text('收入')),
            ],
            selected: {kind},
            onSelectionChanged: (s) =>
                ref.read(statsKindProvider.notifier).state = s.first,
          ),
        ),
        Expanded(
          child: totals.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('暂无数据'));
              }
              final sum = list.fold(0, (s, e) => s + e.totalCents);

              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 56,
                        sections: [
                          for (final item in list)
                            PieChartSectionData(
                              value: item.totalCents.toDouble(),
                              color: Color(item.colorValue),
                              radius: 32,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final item in list)
                    _CategoryRow(
                      name: item.name,
                      iconKey: item.iconKey,
                      color: Color(item.colorValue),
                      cents: item.totalCents,
                      ratio: sum == 0 ? 0 : item.totalCents / sum,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.iconKey,
    required this.color,
    required this.cents,
    required this.ratio,
  });

  final String name;
  final String iconKey;
  final Color color;
  final int cents;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(iconFor(iconKey), color: color, size: 20),
      ),
      title: Row(
        children: [
          Text(name),
          const SizedBox(width: 8),
          Text(
            '${(ratio * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 4,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      trailing: Text(
        formatCents(cents),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
