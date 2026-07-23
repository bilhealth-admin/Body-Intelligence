import 'unified_food.dart';

class FoodAccessRecord {
  final UnifiedFood food;
  final bool favorite;
  final int useCount;
  final DateTime? lastUsedAt;

  const FoodAccessRecord({
    required this.food,
    required this.favorite,
    required this.useCount,
    required this.lastUsedAt,
  });
}

class FoodAccessCandidate {
  final UnifiedFood food;
  final bool favorite;
  final int useCount;
  final DateTime? lastUsedAt;
  final double score;
  final List<String> reasons;

  const FoodAccessCandidate({
    required this.food,
    required this.favorite,
    required this.useCount,
    required this.lastUsedAt,
    required this.score,
    required this.reasons,
  });
}
