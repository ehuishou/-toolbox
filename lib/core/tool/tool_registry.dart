import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/coming_soon_page.dart';
import '../../features/ledger/ledger_module.dart';
import 'tool_descriptor.dart';
import 'tool_module.dart';

/// 唯一需要修改的注册点。
///
/// 新工具做好后：实现 ToolModule，加到这个 list，首页和路由自动生效。
const List<ToolModule> toolModules = <ToolModule>[
  LedgerModule(),

  // 第二期：把下面的占位换成真实模块即可
  _PlannedTool(
    id: 'ocr',
    name: '图片转文字',
    description: '拍照或选图，提取文字',
    icon: Icons.document_scanner_outlined,
    color: Color(0xFF3B82F6),
    category: ToolCategory.text,
  ),
  _PlannedTool(
    id: 'asr',
    name: '语音转文字',
    description: '录音实时转写',
    icon: Icons.mic_none_outlined,
    color: Color(0xFF8B5CF6),
    category: ToolCategory.media,
  ),
  _PlannedTool(
    id: 'video',
    name: '视频剪辑',
    description: '裁剪、压缩、提取音频',
    icon: Icons.movie_creation_outlined,
    color: Color(0xFFEC4899),
    category: ToolCategory.media,
  ),
  _PlannedTool(
    id: 'convert',
    name: '格式转换',
    description: 'PDF、图片、音视频互转',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF14B8A6),
    category: ToolCategory.document,
  ),
];

/// 未开发工具的通用占位模块，点进去是"开发中"页面。
class _PlannedTool extends ToolModule {
  const _PlannedTool({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final ToolCategory category;

  @override
  ToolDescriptor get descriptor => ToolDescriptor(
        id: id,
        name: name,
        description: description,
        icon: icon,
        color: color,
        route: '/$id',
        category: category,
        status: ToolStatus.comingSoon,
      );

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/$id',
          builder: (_, __) => ComingSoonPage(title: name),
        ),
      ];
}

class ToolRegistry {
  const ToolRegistry(this.modules);

  final List<ToolModule> modules;

  List<ToolDescriptor> get descriptors =>
      modules.map((m) => m.descriptor).toList();

  /// 按分类分组，首页据此渲染分区。
  Map<ToolCategory, List<ToolDescriptor>> get grouped =>
      groupBy(descriptors, (ToolDescriptor d) => d.category);

  List<RouteBase> get routes => modules.expand((m) => m.routes).toList();

  Future<void> warmUp() async {
    for (final module in modules) {
      await module.onAppStart();
    }
  }
}

final toolRegistryProvider = Provider<ToolRegistry>(
  (_) => const ToolRegistry(toolModules),
);
