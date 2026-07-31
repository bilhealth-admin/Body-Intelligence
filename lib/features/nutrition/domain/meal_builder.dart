class MealBuilderDraft {
  final String name;
  final String mealType;
  final List<MealBuilderItemDraft> items;

  const MealBuilderDraft({
    required this.name,
    required this.mealType,
    required this.items,
  });

  bool get isEmpty => items.isEmpty;
}

class MealBuilderItemDraft {
  final int foodId;
  final double quantityGrams;
  final int position;

  const MealBuilderItemDraft({
    required this.foodId,
    required this.quantityGrams,
    required this.position,
  });
}
