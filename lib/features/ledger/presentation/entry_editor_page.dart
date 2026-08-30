import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/ui/app_icons.dart';
import '../data/ledger_dao.dart';
import '../data/ledger_tables.dart';
import 'ledger_providers.dart';
import 'widgets/amount_keypad.dart';

class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({super.key, this.initial});

  /// 传入表示编辑已有记录
  final EntryDetail? initial;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  late EntryKind _kind;
  late String _amountText;
  late DateTime _occurredAt;
  late TextEditingController _noteController;
  int? _categoryId;
  int? _accountId;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.initial?.entry;
    _kind = entry?.kind ?? EntryKind.expense;
    _amountText = entry == null ? '' : (entry.amountCents / 100).toString();
    _occurredAt = entry?.occurredAt ?? DateTime.now();
    _categoryId = entry?.categoryId;
    _accountId = entry?.accountId;
    _noteController = TextEditingController(text: entry?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final value = double.tryParse(_amountText);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    final cents = _amountCents;
    if (cents == null) {
      _toast('请输入金额');
      return;
    }
    if (_categoryId == null) {
      _toast('请选择分类');
      return;
    }
    if (_accountId == null) {
      _toast('请选择账户');
      return;
    }

    final dao = ref.read(ledgerDaoProvider);

    if (_isEditing) {
      await dao.updateEntry(
        widget.initial!.entry.copyWith(
          kind: _kind,
          amountCents: cents,
          categoryId: Value(_categoryId),
          accountId: _accountId!,
          note: _noteController.text.trim(),
          occurredAt: _occurredAt,
        ),
      );
    } else {
      await dao.insertEntry(
        LedgerEntriesCompanion.insert(
          kind: _kind,
          amountCents: cents,
          categoryId: Value(_categoryId),
          accountId: _accountId!,
          note: Value(_noteController.text.trim()),
          occurredAt: _occurredAt,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(_kind));
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '记一笔'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<EntryKind>(
              segments: const [
                ButtonSegment(value: EntryKind.expense, label: Text('支出')),
                ButtonSegment(value: EntryKind.income, label: Text('收入')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _categoryId = null; // 分类不跨类型复用
              }),
            ),
          ),
          _AmountDisplay(text: _amountText, kind: _kind),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                categories.when(
                  loading: () => const SizedBox(height: 100),
                  error: (e, _) => Text('$e'),
                  data: (list) => _CategoryGrid(
                    categories: list,
                    selectedId: _categoryId,
                    onSelect: (id) => setState(() => _categoryId = id),
                  ),
                ),
                const Divider(),
                accounts.when(
                  loading: () => const SizedBox(height: 60),
                  error: (e, _) => Text('$e'),
                  data: (list) => _AccountRow(
                    accounts: list,
                    selectedId: _accountId ??= list.firstOrNull?.id,
                    onSelect: (id) => setState(() => _accountId = id),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(DateFormat('yyyy-MM-dd').format(_occurredAt)),
                  onTap: _pickDate,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AmountKeypad(
            onKey: (key) => setState(() {
              _amountText = applyKeypadInput(_amountText, key);
            }),
            onDone: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _occurredAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _occurredAt.hour,
            _occurredAt.minute,
          ));
    }
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.text, required this.kind});

  final String text;
  final EntryKind kind;

  @override
  Widget build(BuildContext context) {
    final isIncome = kind == EntryKind.income;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(isIncome ? '+' : '-', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 4),
          const Text('¥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text.isEmpty ? '0.00' : text,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: isIncome ? const Color(0xFF10B981) : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = category.id == selectedId;
        final color = Color(category.colorValue);

        return InkWell(
          onTap: () => onSelect(category.id),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconFor(category.iconKey),
                  size: 22,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.name,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Account> accounts;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(account.name),
                avatar: Icon(iconFor(account.iconKey), size: 16),
                selected: account.id == selectedId,
                onSelected: (_) => onSelect(account.id),
              ),
            ),
        ],
      ),
    );
  }
}
