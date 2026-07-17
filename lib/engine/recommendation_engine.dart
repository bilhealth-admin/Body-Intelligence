class RecommendationEngine {
  static List<String> recommendations({
    required int remainingProtein,
    required int remainingPotassium,
    required int remainingWater,
  }) {
    final list = <String>[];

    if (remainingProtein > 30) {
      list.add("Eat 180 g chicken breast.");
    }

    if (remainingPotassium > 600) {
      list.add("Add one banana or potato.");
    }

    if (remainingWater > 500) {
      list.add("Drink more water.");
    }

    return list;
  }
}