import 'package:intl/intl.dart';

final NumberFormat _format = NumberFormat('#,##0.00');

/// 分转成显示字符串
String formatCents(int cents) => _format.format(cents.abs() / 100);

String formatCentsSigned(int cents) =>
    '${cents < 0 ? '-' : ''}${formatCents(cents)}';
