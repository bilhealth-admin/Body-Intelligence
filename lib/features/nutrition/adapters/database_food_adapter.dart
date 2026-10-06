import '../../../data/database/app_database.dart';
import '../../../data/database/food_basis_evidence.dart';
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
    final evidence = FoodBasisEvidence.read(food);
    final snapshot = evidence.snapshot;
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
        grams: evidence.isModern
            ? evidence.basisGrams ?? 0
            : _servingGrams(food.servingSize, food.servingUnit),
      ),
      nutrients: <FoodNutrient, NutrientAmount>{
        for (final nutrient in FoodNutrient.values)
          nutrient: switch (evidence.value(nutrient)) {
            final double value => NutrientAmount.known(value),
            null => const NutrientAmount.missing(),
          },
      },
      // The legacy source enum cannot grant a modern snapshot foundation or
      // verified status. Its exact provenance stays in the validated envelope.
      source: evidence.isModern ? FoodDataSource.unknown : sourceFor(food),
      sourceLabel: evidence.isModern
          ? snapshot == null
                ? 'unknown'
                : FoodBasisEvidence.sourceLabel(snapshot)
          : food.source,
      verified: !evidence.isModern && food.verified,
      isCustom: food.isCustom,
      updatedAt: food.updatedAt,
    );
  }

  double _servingGrams(double amount, String unit) {
    if (!amount.isFinite || amount <= 0) return 0;
    switch (unit.trim().toLowerCase()) {
      case 'g':
      case 'gm':
      case 'gms':
      case 'gram':
      case 'grams':
      case 'غ':
      case 'غرام':
      case 'جرام':
      case 'جم':
        return amount;
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
        // FoodServing has no nullable gram field. Its established zero basis
        // is unavailable and rejected by calculation/serving engines. Volume
        // or count needs a supported density/portion, never an implicit 1 g.
        return 0;
    }
  }
}
