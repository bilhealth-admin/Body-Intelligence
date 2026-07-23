class MealTemplate {
  final String id;
  final String name;
  final String mealType;
  final List<MealTemplateItem> items;
  final DateTime createdAt;
  final String? sourceMealUuid;

  const MealTemplate({
    required this.id,
    required this.name,
    required this.mealType,
    required this.items,
    required this.createdAt,
    this.sourceMealUuid,
  });

  double get totalCalories =>
      items.fold(0, (total, item) => total + item.calories);

  bool get isEmpty => items.isEmpty;
}

class MealTemplateItem {
  final int foodId;
  final double quantityGrams;
  final int position;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double potassium;
  final double calcium;
  final double magnesium;
  final double sugar;
  final int nutrientEvidenceMask;

  const MealTemplateItem({
    required this.foodId,
    required this.quantityGrams,
    required this.position,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.calcium,
    required this.magnesium,
    required this.sugar,
    required this.nutrientEvidenceMask,
  });
}
