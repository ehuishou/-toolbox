import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_page.dart';
import '../tool/tool_registry.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final registry = ref.watch(toolRegistryProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomePage()),
      // 所有工具路由由注册表提供
      ...registry.routes,
    ],
  );
});
