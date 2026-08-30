import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/tool/tool_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('zh_CN');

  // 工具模块预热（未来 OCR 模型加载、FFmpeg 初始化在此接入）
  await const ToolRegistry(toolModules).warmUp();

  runApp(const ProviderScope(child: ToolboxApp()));
}
