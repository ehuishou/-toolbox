import 'package:flutter_test/flutter_test.dart';

import 'package:toolbox/core/database/app_database.dart';
import 'package:toolbox/features/ledger/domain/category_matcher.dart';

void main() {
  const rules = [
    CategoryRule(id: 1, keyword: '美团', categoryId: 1, hitCount: 0, isBuiltIn: true),
    CategoryRule(id: 2, keyword: '滴滴', categoryId: 2, hitCount: 3, isBuiltIn: true),
    CategoryRule(id: 3, keyword: '星巴克', categoryId: 1, hitCount: 5, isBuiltIn: true),
  ];

  test('关键词命中', () {
    final m = CategoryMatcher.match('美团外卖', rules);
    expect(m, isNotNull);
    expect(m!.categoryId, 1);
  });

  test('未命中返回 null', () {
    expect(CategoryMatcher.match('无名商户', rules), isNull);
    expect(CategoryMatcher.match(null, rules), isNull);
  });

  test('hitCount 高的规则优先，且 confidence 随 hitCount 递增', () {
    // "星巴克美团" 同时命中"美团"(0) 和"星巴克"(5)，应取 hitCount 更高的"星巴克"
    final m = CategoryMatcher.match('星巴克美团', rules);
    expect(m!.categoryId, 1);
    expect(m.confidence, 95); // 60 + 5*10 = 110，clamp 到 95
  });
}
