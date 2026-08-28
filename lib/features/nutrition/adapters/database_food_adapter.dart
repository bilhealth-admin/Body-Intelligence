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
        FoodNutrient.calories: _core(
          food,
          FoodNutrient.calories,
          food.calories,
        ),
        FoodNutrient.protein: _core(food, FoodNutrient.protein, food.protein),
        FoodNutrient.carbohydrates: _core(
          food,
          FoodNutrient.carbohydrates,
          food.carbs,
        ),
        FoodNutrient.fat: _core(food, FoodNutrient.fat, food.fats),
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
        FoodNutrient.phosphorus: _optional(
          food,
          FoodNutrient.phosphorus,
          food.phosphorus,
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

  NutrientAmount _core(Food food, FoodNutrient nutrient, double value) {
    // Quick Add records carry an explicit per-field evidence mask so an empty
    // field remains unknown while a user-entered zero remains known.
    if (food.source == 'quick_add' || food.source.startsWith('BIL community')) {
      return UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient)
          ? NutrientAmount.known(value)
          : const NutrientAmount.missing();
    }
    // Older bundled and user-created rows predate core evidence bits. Their
    // required macro columns are authoritative. Downloaded catalog rows must
    // prove each value instead of turning missing data into a numeric zero.
    if (food.source != 'bil-mobile-catalog' ||
        UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient) ||
        value != 0) {
      return NutrientAmount.known(value);
    }
    return const NutrientAmount.missing();
  }

  double _servingGrams(double amount, String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'kg':
      case 'kgs':
      case 'kilogram':
      case 'kilograms':
        return amount * 1000;
      case 'oz':
      case 'ozs':
      case 'ounce':
      case 'ounces':
        return amount * 28.349523125;
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return amount * 453.59237;
      case 'mg':
      case 'mgs':
      case 'milligram':
      case 'milligrams':
        return amount / 1000;
      default:
        return amount;
    }
  }
}
