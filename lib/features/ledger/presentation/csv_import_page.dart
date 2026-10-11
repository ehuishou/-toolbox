import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/import/csv_importer.dart';
import 'ledger_providers.dart';
import 'pending_review_page.dart';

/// CSV 账单导入页面。用户选择支付宝或微信的账单文件，解析后跳转到待确认页面。
class CsvImportPage extends ConsumerStatefulWidget {
  const CsvImportPage({super.key});

  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入账单'),
      ),
      body: Center(
        child: _isImporting
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在解析账单...'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.upload_file,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '选择账单文件',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '支持支付宝和微信导出的 CSV 账单',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _pickAndImport(isAlipay: true),
                        icon: const Icon(Icons.file_upload),
                        label: const Text('支付宝账单 (GBK)'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _pickAndImport(isAlipay: false),
                        icon: const Icon(Icons.file_upload),
                        label: const Text('微信账单 (UTF-8)'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildHelpCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '如何导出账单？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '支付宝：\n我的 → 账单 → 右上角 → 开具交易流水证明 → 用于个人对账',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              '微信：\n我 → 服务 → 钱包 → 账单 → 常见问题 → 下载账单',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImport({required bool isAlipay}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() => _isImporting = true);

    try {
      final importer = ref.read(csvImporterProvider);
      final importResult = isAlipay
          ? await importer.importAlipay(file)
          : await importer.importWechat(file);

      if (!mounted) return;
      setState(() => _isImporting = false);

      // 显示导入结果
      await _showImportResult(importResult);

      // 如果有成功导入的账单，跳转到待确认页面
      if (importResult.imported > 0 && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PendingReviewPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showError('导入失败：$e');
    }
  }

  Future<void> _showImportResult(ImportResult result) async {
    final hasWarnings = result.skipped > 0 || result.hasFailures;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasWarnings ? Icons.warning : Icons.check_circle,
              color: hasWarnings ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('导入结果'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ 成功导入：${result.imported} 笔'),
            if (result.skipped > 0) ...[
              const SizedBox(height: 4),
              Text('⏭️  跳过重复：${result.skipped} 笔'),
            ],
            if (result.hasFailures) ...[
              const SizedBox(height: 4),
              Text('❌ 解析失败：${result.failures.length} 行'),
              const SizedBox(height: 8),
              const Text(
                '失败原因：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...result.failures.take(3).map(
                    (f) => Text(
                      '• $f',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
              if (result.failures.length > 3)
                Text(
                  '... 还有 ${result.failures.length - 3} 条',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
