import '../../../data/database/app_database.dart';
import '../domain/unified_food.dart';

abstract interface class DatabaseFoodAdapter {
  bool supports(Food food);
  UnifiedFood adapt(Food food);
}

abstract class BaseDatabaseFoodAdapter implements DatabaseFoodAdapter {
  const BaseDatabaseFoodAdapter();

  FoodDataSource sourceFor(Food food);

  @override
  UnifiedFood adapt(Food food) {
    final source = sourceFor(food);
    return UnifiedFood(
      id: food.uuid,
      localId: food.id,
      name: food.name,
      arabicName: food.arabicName,
      category: food.category,
      keywords: food.keywords
          .split(RegExp(r'[,;|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      barcode: food.barcode,
      serving: FoodServing(
        amount: food.servingSize,
        unit: food.servingUnit,
        grams: _servingGrams(food.servingSize, food.servingUnit),
      ),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: NutrientAmount.known(food.calories),
        FoodNutrient.protein: NutrientAmount.known(food.protein),
        FoodNutrient.carbohydrates: NutrientAmount.known(food.carbs),
        FoodNutrient.fat: NutrientAmount.known(food.fats),
        FoodNutrient.fiber: _optional(food, FoodNutrient.fiber, food.fiber),
        FoodNutrient.sugar: _optional(food, FoodNutrient.sugar, food.sugar),
        FoodNutrient.sodium: _optional(food, FoodNutrient.sodium, food.sodium),
        FoodNutrient.potassium: _optional(
          food,
          FoodNutrient.potassium,
          food.potassium,
        ),
        FoodNutrient.calcium: _optional(
          food,
          FoodNutrient.calcium,
          food.calcium,
        ),
        FoodNutrient.magnesium: _optional(
          food,
          FoodNutrient.magnesium,
          food.magnesium,
        ),
        FoodNutrient.iron: NutrientAmount.known(food.iron),
        FoodNutrient.vitaminC: NutrientAmount.known(food.vitaminC),
      },
      source: source,
      sourceLabel: food.source,
      verified: food.verified,
      isCustom: food.isCustom,
      updatedAt: food.updatedAt,
    );
  }

  NutrientAmount _optional(Food food, FoodNutrient nutrient, double value) {
    return UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient)
        ? NutrientAmount.known(value)
        : const NutrientAmount.missing();
  }

  double _servingGrams(double amount, String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'kg':
      case 'kilogram':
        return amount * 1000;
      case 'oz':
      case 'ounce':
        return amount * 28.349523125;
      case 'lb':
      case 'pound':
        return amount * 453.59237;
      default:
        return amount;
    }
  }
}
