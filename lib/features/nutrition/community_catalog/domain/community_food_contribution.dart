import '../../../../data/database/app_database.dart';
import '../../../../data/database/nutrient_evidence.dart';
import '../../../community/domain/community_text_policy.dart';

class CommunityFoodContribution {
  const CommunityFoodContribution({
    required this.localFoodUuid,
    required this.payload,
  });

  final String localFoodUuid;
  final Map<String, dynamic> payload;

  factory CommunityFoodContribution.fromFood(
    Food food, {
    required String localeCode,
  }) {
    final language = localeCode
        .trim()
        .split(RegExp('[-_]'))
        .first
        .toLowerCase();
    final localizedNames = <String, String>{};
    if (language.isNotEmpty) localizedNames[language] = food.name.trim();
    final arabicName = food.arabicName?.trim();
    if (arabicName != null && arabicName.isNotEmpty) {
      localizedNames['ar'] = arabicName;
    }

    final aliases = <String>{
      ...food.keywords
          .split(RegExp(r'[,;|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
      if (arabicName != null && arabicName.isNotEmpty) arabicName,
    }.toList(growable: false);

    CommunityTextPolicy.enforceAll({
      CommunityTextSurface.foodName: food.name,
      CommunityTextSurface.foodLocalizedName: localizedNames.values.join(' '),
      CommunityTextSurface.foodAlias: aliases.join(' '),
    });

    double? known(TrackedNutrient nutrient, double value) {
      return NutrientEvidenceMask.contains(food.nutrientEvidenceMask, nutrient)
          ? value
          : null;
    }

    return CommunityFoodContribution(
      localFoodUuid: food.uuid,
      payload: <String, dynamic>{
        'client_food_id': food.uuid,
        'canonical_name': food.name.trim(),
        'localized_names': localizedNames,
        'aliases': aliases,
        'barcode': food.barcode,
        'serving_amount': food.servingSize,
        'serving_unit': food.servingUnit.trim().toLowerCase(),
        'calories_kcal': food.calories,
        'protein_g': food.protein,
        'carbohydrate_g': food.carbs,
        'fat_g': food.fats,
        'fiber_g': known(TrackedNutrient.fiber, food.fiber),
        'sugar_g': known(TrackedNutrient.sugar, food.sugar),
        'sodium_mg': known(TrackedNutrient.sodium, food.sodium),
        'potassium_mg': known(TrackedNutrient.potassium, food.potassium),
        'calcium_mg': known(TrackedNutrient.calcium, food.calcium),
        'magnesium_mg': known(TrackedNutrient.magnesium, food.magnesium),
        'phosphorus_mg': known(TrackedNutrient.phosphorus, food.phosphorus),
        'iron_mg': food.iron == 0 ? null : food.iron,
        'vitamin_c_mg': food.vitaminC == 0 ? null : food.vitaminC,
        'nutrient_evidence_mask': food.nutrientEvidenceMask,
      },
    );
  }
}
