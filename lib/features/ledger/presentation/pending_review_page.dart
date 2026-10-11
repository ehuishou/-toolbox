import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/utils/money.dart';
import '../data/ledger_tables.dart';
import '../data/import/csv_importer.dart';
import 'ledger_providers.dart';

/// 待确认账单列表页面。解析出来的账单在这里展示，用户可以确认/修正/忽略。
class PendingReviewPage extends ConsumerStatefulWidget {
  const PendingReviewPage({super.key});

  @override
  ConsumerState<PendingReviewPage> createState() => _PendingReviewPageState();
}

class _PendingReviewPageState extends ConsumerState<PendingReviewPage> {
  final _selectedIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(pendingBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待确认账单'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _batchConfirm,
              child: Text('确认选中 (${_selectedIds.length})'),
            ),
        ],
      ),
      body: billsAsync.when(
        data: (bills) {
          if (bills.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('没有待确认的账单', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final isSelected = _selectedIds.contains(bill.id);
              return _BillCard(
                bill: bill,
                isSelected: isSelected,
                onToggleSelect: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(bill.id);
                    } else {
                      _selectedIds.add(bill.id);
                    }
                  });
                },
                onConfirm: () => _confirmBill(bill),
                onIgnore: () => _ignoreBill(bill),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败：$err')),
      ),
    );
  }

  Future<void> _confirmBill(PendingBill bill) async {
    // TODO: 打开编辑器让用户修正分类和账户
    final dao = ref.read(ledgerDaoProvider);
    final accounts = await ref.read(accountsProvider.future);
    final defaultAccount = accounts.firstOrNull;

    if (defaultAccount == null) {
      _showError('请先创建至少一个账户');
      return;
    }

    // 简化版：直接使用推断的分类和默认账户确认
    await dao.confirmPendingBill(
      pendingBillId: bill.id,
      accountId: defaultAccount.id,
      categoryId: bill.suggestedCategoryId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已确认')),
      );
    }
  }

  Future<void> _ignoreBill(PendingBill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('忽略这笔账单？'),
        content: const Text('忽略后不会再显示，但可以在设置中恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('忽略'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(ledgerDaoProvider).ignorePendingBill(bill.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已忽略')),
      );
    }
  }

  Future<void> _batchConfirm() async {
    final dao = ref.read(ledgerDaoProvider);
    final accounts = await ref.read(accountsProvider.future);
    final bills = await ref.read(pendingBillsProvider.future);
    final defaultAccount = accounts.firstOrNull;

    if (defaultAccount == null) {
      _showError('请先创建至少一个账户');
      return;
    }

    var count = 0;
    for (final id in _selectedIds) {
      final bill = bills.firstWhere((b) => b.id == id);
      await dao.confirmPendingBill(
        pendingBillId: bill.id,
        accountId: defaultAccount.id,
        categoryId: bill.suggestedCategoryId,
      );
      count++;
    }

    setState(() => _selectedIds.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已确认 $count 笔账单')),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({
    required this.bill,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onConfirm,
    required this.onIgnore,
  });

  final PendingBill bill;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onConfirm;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider(bill.kind));
    final categoryName = categoriesAsync.whenData((cats) {
      if (bill.suggestedCategoryId == null) return null;
      return cats
          .where((c) => c.id == bill.suggestedCategoryId)
          .firstOrNull
          ?.name;
    }).value;

    final theme = Theme.of(context);
    final isExpense = bill.kind == EntryKind.expense;
    final amountColor = isExpense ? Colors.red[700] : Colors.green[700];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onToggleSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.merchant ?? '未知商户',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(bill.occurredAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'}${formatMoney(bill.amountCents)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (categoryName != null) ...[
                    Chip(
                      label: Text(categoryName),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (bill.confidence > 0)
                    Chip(
                      label: Text('置信度 ${bill.confidence}%'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _confidenceColor(bill.confidence),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onIgnore,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('忽略'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('确认'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _confidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green[100]!;
    if (confidence >= 60) return Colors.orange[100]!;
    return Colors.red[100]!;
  }
}
