import '../../../data/database/app_database.dart';
import '../domain/meal_template.dart';

class MealTemplateEngine {
  const MealTemplateEngine();

  MealTemplate fromHistoricalMeal({
    required Meal meal,
    required List<MealItem> items,
    required String templateId,
    required String templateName,
    DateTime? createdAt,
  }) {
    final id = templateId.trim();
    final name = templateName.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(templateId, 'templateId', 'Must not be blank');
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        templateName,
        'templateName',
        'Must not be blank',
      );
    }
    if (items.isEmpty) {
      throw StateError('A meal template requires at least one item');
    }

    final ordered = List<MealItem>.from(items)
      ..sort((left, right) {
        final positionOrder = left.position.compareTo(right.position);
        return positionOrder != 0 ? positionOrder : left.id.compareTo(right.id);
      });

    return MealTemplate(
      id: id,
      name: name,
      mealType: meal.type,
      sourceMealUuid: meal.uuid,
      createdAt: createdAt ?? DateTime.now(),
      items: List<MealTemplateItem>.unmodifiable(
        ordered.asMap().entries.map((entry) {
          final item = entry.value;
          return MealTemplateItem(
            foodId: item.foodId,
            quantityGrams: item.quantity,
            position: entry.key + 1,
            calories: item.calories,
            protein: item.protein,
            carbohydrates: item.carbs,
            fat: item.fats,
            fiber: item.fiber,
            sodium: item.sodium,
            potassium: item.potassium,
            calcium: item.calcium,
            magnesium: item.magnesium,
            sugar: item.sugar,
            nutrientEvidenceMask: item.nutrientEvidenceMask,
          );
        }),
      ),
    );
  }

  void validateForInstantiation(MealTemplate template) {
    if (template.id.trim().isEmpty || template.name.trim().isEmpty) {
      throw StateError('Meal template identity is invalid');
    }
    if (!const {
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    }.contains(template.mealType)) {
      throw StateError('Unsupported meal template type: ${template.mealType}');
    }
    if (template.items.isEmpty) {
      throw StateError('Meal template has no items');
    }

    final positions = <int>{};
    for (final item in template.items) {
      if (!item.quantityGrams.isFinite || item.quantityGrams <= 0) {
        throw StateError('Meal template contains an invalid quantity');
      }
      if (item.position <= 0 || !positions.add(item.position)) {
        throw StateError(
          'Meal template item positions must be unique and positive',
        );
      }
      final nutrients = <double>[
        item.calories,
        item.protein,
        item.carbohydrates,
        item.fat,
        item.fiber,
        item.sodium,
        item.potassium,
        item.calcium,
        item.magnesium,
        item.sugar,
      ];
      if (nutrients.any((value) => !value.isFinite || value < 0)) {
        throw StateError('Meal template contains invalid nutrition snapshots');
      }
    }
  }
}
