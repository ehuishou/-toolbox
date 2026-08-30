import 'package:flutter/material.dart';

/// 工具的开发状态。未完成的工具也注册进来，首页会显示占位卡片。
enum ToolStatus { available, comingSoon }

enum ToolCategory {
  life('生活'),
  text('文字识别'),
  media('音视频'),
  document('文档');

  const ToolCategory(this.label);
  final String label;
}

/// 工具在首页的展示信息。纯数据，不含逻辑。
@immutable
class ToolDescriptor {
  const ToolDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    required this.category,
    this.status = ToolStatus.available,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
  final ToolCategory category;
  final ToolStatus status;

  bool get isAvailable => status == ToolStatus.available;
}
