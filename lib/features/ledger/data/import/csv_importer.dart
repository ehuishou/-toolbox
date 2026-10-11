import 'dart:convert';
import 'dart:io';

import 'package:charset_converter/charset_converter.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/category_matcher.dart';
import '../ledger_dao.dart';
import '../ledger_tables.dart';
import 'bill_source.dart';
import 'parsers/alipay_parser.dart';
import 'parsers/wechat_parser.dart';

/// 把账单文件字节解码成 UTF-8 字符串。
///
/// 编码坑（见升级方案）：
/// - 支付宝导出的 CSV 是 GBK 编码，直接按 UTF-8 读会乱码；
/// - 微信的是 UTF-8 带 BOM，要先去 BOM，否则第一个字段名会带 ﻿ 匹配不到。
Future<String> decodeBillCsv(Uint8List bytes, {required bool isGbk}) async {
  if (isGbk) {
    return CharsetConverter.decode('gbk', bytes);
  }
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return text;
}

/// CSV 账单导入器。处理编码、解析、分类推断、去重、入库全流程。
class CsvImporter {
  const CsvImporter({
    required this.dao,
  });

  final LedgerDao dao;

  /// 导入支付宝 CSV。支付宝导出的 CSV 是 GBK 编码。
  Future<ImportResult> importAlipay(File file) async {
    final bytes = await file.readAsBytes();
    final content = await decodeBillCsv(bytes, isGbk: true);
    return _import(const AlipayCsvParser(), content);
  }

  /// 导入微信 CSV。微信导出的 CSV 是 UTF-8 编码带 BOM。
  Future<ImportResult> importWechat(File file) async {
    final bytes = await file.readAsBytes();
    final content = await decodeBillCsv(bytes, isGbk: false);
    return _import(const WechatCsvParser(), content);
  }

  Future<ImportResult> _import(BillSource parser, String content) async {
    // 1. 解析 CSV
    final parseResult = await parser.parse(content);
    if (parseResult.bills.isEmpty && parseResult.failures.isEmpty) {
      return ImportResult(
        imported: 0,
        skipped: 0,
        failures: const ['文件内容为空或格式不支持'],
      );
    }

    // 2. 分类推断
    final rules = await dao.watchCategoryRules().first;
    final billsWithCategory = parseResult.bills.map((bill) {
      final match = CategoryMatcher.match(bill.merchant, rules);
      return _BillWithCategory(
        bill: bill,
        suggestedCategoryId: match?.categoryId,
        confidence: match?.confidence ?? 0,
      );
    }).toList();

    // 3. 批量插入待确认队列（数据库唯一索引自动去重）
    var imported = 0;
    var skipped = 0;
    for (final item in billsWithCategory) {
      final id = await dao.insertPendingBill(
        PendingBillsCompanion.insert(
          sourceType: item.bill.sourceType,
          sourceId: item.bill.sourceId,
          amountCents: item.bill.amountCents,
          kind: item.bill.kind,
          occurredAt: item.bill.occurredAt,
          merchant: Value(item.bill.merchant),
          counterparty: Value(item.bill.counterparty),
          rawText: item.bill.rawText,
          suggestedCategoryId: Value(item.suggestedCategoryId),
          confidence: Value(item.confidence),
        ),
      );
      if (id > 0) {
        imported++;
      } else {
        skipped++; // 被唯一索引拒绝（重复导入）
      }
    }

    return ImportResult(
      imported: imported,
      skipped: skipped,
      failures: parseResult.failures,
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.failures,
  });

  final int imported;
  final int skipped; // 被去重跳过的数量
  final List<String> failures; // 解析失败的行

  bool get hasFailures => failures.isNotEmpty;
  int get total => imported + skipped;
}

class _BillWithCategory {
  const _BillWithCategory({
    required this.bill,
    this.suggestedCategoryId,
    required this.confidence,
  });

  final RawBill bill;
  final int? suggestedCategoryId;
  final int confidence;
}
