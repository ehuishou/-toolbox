import 'package:flutter/material.dart';

/// 键位。'C' 清空，'<' 退格。
const List<String> _keys = [
  '1', '2', '3', 'C',
  '4', '5', '6', '<',
  '7', '8', '9', '完成',
  '.', '0', '00', '',
];

/// 纯函数处理输入，便于单测
String applyKeypadInput(String current, String key) {
  switch (key) {
    case 'C':
      return '';
    case '<':
      return current.isEmpty ? '' : current.substring(0, current.length - 1);
    case '.':
      if (current.contains('.')) return current;
      return current.isEmpty ? '0.' : '$current.';
    default:
      // 小数位最多两位
      final dotIndex = current.indexOf('.');
      if (dotIndex >= 0 && current.length - dotIndex > 2) return current;
      if (current == '0' && key != '.') return key;
      return '$current$key';
  }
}

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey, required this.onDone});

  final ValueChanged<String> onKey;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.9,
        ),
        itemCount: _keys.length,
        itemBuilder: (context, index) {
          final key = _keys[index];
          if (key.isEmpty) return const SizedBox.shrink();

          final isDone = key == '完成';
          return InkWell(
            onTap: isDone ? onDone : () => onKey(key),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDone
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: key == '<'
                  ? const Icon(Icons.backspace_outlined, size: 20)
                  : Text(
                      key,
                      style: TextStyle(
                        fontSize: isDone ? 15 : 20,
                        color: isDone ? theme.colorScheme.onPrimary : null,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
