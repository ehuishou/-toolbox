import 'package:flutter_test/flutter_test.dart';

import 'package:toolbox/core/util/money.dart';
import 'package:toolbox/features/ledger/presentation/widgets/amount_keypad.dart';

void main() {
  group('applyKeypadInput（金额键盘输入）', () {
    test('追加数字', () {
      expect(applyKeypadInput('', '1'), '1');
      expect(applyKeypadInput('1', '2'), '12');
    });

    test('首位 0 被替换', () {
      expect(applyKeypadInput('0', '5'), '5');
      expect(applyKeypadInput('0', '0'), '0');
    });

    test('小数点只能有一个', () {
      expect(applyKeypadInput('', '.'), '0.');
      expect(applyKeypadInput('12', '.'), '12.');
      expect(applyKeypadInput('12.5', '.'), '12.5');
    });

    test('小数最多两位', () {
      expect(applyKeypadInput('12.3', '4'), '12.34');
      expect(applyKeypadInput('12.34', '5'), '12.34');
    });

    test('退格', () {
      expect(applyKeypadInput('123', '<'), '12');
      expect(applyKeypadInput('', '<'), '');
    });

    test('清空', () {
      expect(applyKeypadInput('123', 'C'), '');
    });

    test('双零键', () {
      expect(applyKeypadInput('1', '00'), '100');
    });
  });

  group('formatCents（分转元格式化）', () {
    test('基本转换与千分位', () {
      expect(formatCents(0), '0.00');
      expect(formatCents(12345), '123.45');
      expect(formatCents(100000000), '1,000,000.00');
    });

    test('负数取绝对值', () {
      expect(formatCents(-12345), '123.45');
    });
  });
}
