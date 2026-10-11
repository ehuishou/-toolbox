import 'package:csv/csv.dart';

import '../../../../../core/database/app_database.dart';
import '../bill_source.dart';

/// 微信账单 CSV 解析器。
///
/// 输入是【已解码的 UTF-8 字符串】（UTF-8 BOM 去除在 CsvImporter 里做）。
/// 微信 CSV 结构会变，所以字段名抽成映射表，改字段只改映射表。
class WechatCsvParser implements BillSource {
  const WechatCsvParser();

  @override
  BillSourceType get type => BillSourceType.wechatCsv;

  /// 逻辑字段 → 微信表头候选名。
  /// 微信改字段名时，把新名字加进对应列表即可，不动解析逻辑。
  static const Map<String, List<String>> _fieldNames = {
    'time': ['交易时间'],
    'amount': ['金额(元)', '金额（元）', '金额'],
    'direction': ['收/支', '收支'],
    'merchant': ['交易对方', '商品', '商户'],
    'status': ['当前状态', '交易状态'],
    'orderId': ['交易单号', '商户单号'],
    'paymentMethod': ['支付方式'],
  };

  @override
  Future<BillParseResult> parse(dynamic input) async {
    final content = input as String;
    final rows = _toRows(content);
    if (rows.isEmpty) {
      return const BillParseResult(bills: [], failures: []);
    }

    final headerIndex = _findHeaderIndex(rows);
    if (headerIndex == null) {
      return const BillParseResult(bills: [], failures: ['未找到表头行']);
    }
    final header = rows[headerIndex].map((c) => c.trim()).toList();
    final cols = _buildColumnMap(header);
    if (cols['time'] == null || cols['amount'] == null) {
      return const BillParseResult(
          bills: [], failures: ['缺少必要字段：交易时间 / 金额']);
    }

    final bills = <RawBill>[];
    final failures = <String>[];
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i].map((c) => c.trim()).toList();
      if (row.every((c) => c.isEmpty)) continue; // 空行跳过
      switch (_parseRow(row, cols)) {
        case _RowBill(:final bill):
          bills.add(bill);
        case _RowSkip():
          break;
        case _RowError(:final reason):
          failures.add('第 ${i + 1} 行：$reason');
      }
    }

    return BillParseResult(bills: bills, failures: failures);
  }

  List<List<String>> _toRows(String content) {
    final normalized =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(normalized).map((r) => r.map((c) => c.toString()).toList()).toList();
  }

  /// 找到表头行：第一个同时包含"时间"和"金额"候选名的行。
  int? _findHeaderIndex(List<List<String>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final cells = rows[i].map((c) => c.trim()).toSet();
      final hasTime = _fieldNames['time']!.any(cells.contains);
      final hasAmount = _fieldNames['amount']!.any(cells.contains);
      if (hasTime && hasAmount) return i;
    }
    return null;
  }

  /// 逻辑字段 → 列下标。
  Map<String, int> _buildColumnMap(List<String> header) {
    final map = <String, int>{};
    for (final entry in _fieldNames.entries) {
      for (var i = 0; i < header.length; i++) {
        if (entry.value.contains(header[i])) {
          map[entry.key] = i;
          break;
        }
      }
    }
    return map;
  }

  String? _cell(List<String> row, Map<String, int> cols, String field) {
    final idx = cols[field];
    if (idx == null || idx >= row.length) return null;
    final v = row[idx];
    return v.isEmpty ? null : v;
  }

  _RowOutcome _parseRow(List<String> row, Map<String, int> cols) {
    // 状态：关闭/退款/失败 的行跳过，别把退款记成支出
    final status = _cell(row, cols, 'status');
    if (status != null &&
        (status.contains('已关闭') ||
            status.contains('已退款') ||
            status.contains('已全额退款') ||
            status.contains('对方已退还') ||
            status.contains('已失败') ||
            status.contains('已取消'))) {
      return const _RowSkip();
    }

    // 收支方向
    final direction = _cell(row, cols, 'direction');
    // 微信的"/"（转账等）不计收支，跳过
    if (direction != null && direction == '/') {
      return const _RowSkip();
    }
    final kind = _directionToKind(direction);
    if (kind == null) {
      return _RowError(
          direction == null ? '缺少收/支字段' : '无法识别收支方向：$direction');
    }

    // 时间
    final timeRaw = _cell(row, cols, 'time');
    final time = timeRaw == null ? null : _parseTime(timeRaw);
    if (time == null) {
      return _RowError('无法解析时间：${timeRaw ?? ''}');
    }

    // 金额（元 → 分，字符串解析避免浮点误差）
    final amountRaw = _cell(row, cols, 'amount');
    final cents = amountRaw == null ? null : _yuanToCents(amountRaw);
    if (cents == null || cents <= 0) {
      return _RowError('无法解析金额：${amountRaw ?? ''}');
    }

    final merchant = _cell(row, cols, 'merchant');
    final counterparty = merchant; // 微信的"交易对方"既是商户也是对方
    final orderId = _cell(row, cols, 'orderId');

    return _RowBill(RawBill(
      sourceType: type,
      sourceId: orderId ?? '${time.toIso8601String()}-$cents',
      amountCents: cents,
      kind: kind,
      occurredAt: time,
      rawText: row.join(' | '),
      merchant: merchant,
      counterparty: counterparty,
    ));
  }

  /// 收支方向 → EntryKind。无法识别返回 null（由调用方决定报错或跳过）。
  EntryKind? _directionToKind(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('收入')) return EntryKind.income;
    if (raw.contains('支出')) return EntryKind.expense;
    return null;
  }

  DateTime? _parseTime(String raw) {
    // 微信时间格式示例："2024-01-01 12:30:00"
    final s = raw.trim();
    return DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  /// 元字符串转分，纯字符串运算，避免 double 精度问题。
  int? _yuanToCents(String raw) {
    var s = raw
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    if (s.isEmpty) return null;
    if (s.startsWith('+')) s = s.substring(1);
    final negative = s.startsWith('-');
    if (negative) s = s.substring(1);

    final dot = s.indexOf('.');
    final yuanPart = dot < 0 ? s : s.substring(0, dot);
    final centPart = dot < 0 ? '' : s.substring(dot + 1);
    final yuan = int.tryParse(yuanPart);
    if (yuan == null) return null;

    var cents = yuan * 100;
    if (centPart.isNotEmpty) {
      cents += int.tryParse(centPart.padRight(2, '0').substring(0, 2)) ?? 0;
    }
    return negative ? -cents : cents;
  }
}

sealed class _RowOutcome {
  const _RowOutcome();
}

final class _RowBill extends _RowOutcome {
  _RowBill(this.bill);
  final RawBill bill;
}

final class _RowSkip extends _RowOutcome {
  const _RowSkip();
}

final class _RowError extends _RowOutcome {
  _RowError(this.reason);
  final String reason;
}
