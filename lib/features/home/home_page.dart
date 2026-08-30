import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tool/tool_descriptor.dart';
import '../../core/tool/tool_registry.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(toolRegistryProvider).grouped;

    return Scaffold(
      appBar: AppBar(title: const Text('工具箱')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Text(
                entry.key.label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, index) =>
                  _ToolTile(tool: entry.value[index]),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final ToolDescriptor tool;

  @override
  Widget build(BuildContext context) {
    final enabled = tool.isAvailable;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(tool.route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tool.icon, color: tool.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              tool.name,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
