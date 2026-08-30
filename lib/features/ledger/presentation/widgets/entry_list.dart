import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_icons.dart';
import '../../../../core/util/money.dart';
import '../../data/ledger_dao.dart';
import '../../data/ledger_tables.dart';
import '../ledger_providers.dart';

class EntryList extends ConsumerWidget {
  const EntryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(monthEntriesProvider);

    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState();
        }

        // 按天分组
        final byDay = groupBy(list, (EntryDetail d) {
          final t = d.entry.occurredAt;
          return DateTime(t.year, t.month, t.day);
        });
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final items = byDay[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayHeader(day: day, items: items),
                ...items.map((e) => _EntryTile(detail: e)),
              ],
            );
          },
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});

  final DateTime day;
  final List<EntryDetail> items;

  @override
  Widget build(BuildContext context) {
    final expense = items
        .where((e) => e.entry.kind == EntryKind.expense)
        .fold(0, (sum, e) => sum + e.entry.amountCents);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            DateFormat('M月d日 EEEE', 'zh_CN').format(day),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          if (expense > 0)
            Text(
              '支出 ${formatCents(expense)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.detail});

  final EntryDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = detail.entry;
    final isIncome = entry.kind == EntryKind.income;
    final color = Color(detail.category?.colorValue ?? 0xFF64748B);

    final subtitleParts = [
      if (detail.account != null) detail.account!.name,
      if (entry.note.isNotEmpty) entry.note,
    ];

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除这条记录？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) =>
          ref.read(ledgerDaoProvider).softDeleteEntry(entry.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconFor(detail.category?.iconKey), color: color, size: 20),
        ),
        title: Text(detail.category?.name ?? '未分类'),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(subtitleParts.join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${isIncome ? '+' : '-'}${formatCents(entry.amountCents)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isIncome ? const Color(0xFF10B981) : null,
          ),
        ),
        onTap: () => context.push('/ledger/entry', extra: detail),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          const Text('这个月还没有记录'),
        ],
      ),
    );
  }
}
