import 'package:go_router/go_router.dart';

import 'tool_descriptor.dart';

/// 每个工具实现这个契约。新增工具只需实现它并注册到 toolModules。
abstract class ToolModule {
  const ToolModule();

  ToolDescriptor get descriptor;

  /// 该工具的全部路由，会被挂载到根路由下。
  List<RouteBase> get routes;

  /// 需要预热的资源（模型下载、FFmpeg 初始化等）在这里做。
  Future<void> onAppStart() async {}
}
