import 'package:flutter/material.dart';

/// 图标用字符串 key 存库，避免非常量 IconData 触发 tree-shaking 报错。
const Map<String, IconData> kIconMap = {
  // 支出
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_bus_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'home': Icons.home_outlined,
  'entertainment': Icons.sports_esports_outlined,
  'medical': Icons.local_hospital_outlined,
  'education': Icons.school_outlined,
  // 收入
  'salary': Icons.payments_outlined,
  'bonus': Icons.card_giftcard_outlined,
  'investment': Icons.trending_up,
  // 账户
  'cash': Icons.money_outlined,
  'bank': Icons.credit_card_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  // 兜底
  'other': Icons.more_horiz,
};

IconData iconFor(String? key) => kIconMap[key] ?? kIconMap['other']!;
