import '../../../core/database/app_database.dart';

class CategoryMatch {
  const CategoryMatch({required this.categoryId, required this.confidence});

  final int categoryId;
  final int confidence;
}

/// 分类推断。不用模型，规则表（CategoryRules）足够。
class CategoryMatcher {
  /// 按 hitCount 降序遍历规则，第一个被 merchant 包含的关键词即命中。
  /// 命中返回 (categoryId, confidence)，confidence 随 hitCount 递增。
  /// 未命中返回 null，让用户自己选；选完由 DAO 把 (关键词 → 分类) 写回规则表。
  static CategoryMatch? match(String? merchant, List<CategoryRule> rules) {
    if (merchant == null || merchant.isEmpty) return null;
    final sorted = [...rules]..sort((a, b) => b.hitCount.compareTo(a.hitCount));
    for (final rule in sorted) {
      if (merchant.contains(rule.keyword)) {
        // 基础 60，每命中一次 +10，上限 95
        final confidence = (60 + rule.hitCount * 10).clamp(0, 95);
        return CategoryMatch(
          categoryId: rule.categoryId,
          confidence: confidence,
        );
      }
    }
    return null;
  }
}
