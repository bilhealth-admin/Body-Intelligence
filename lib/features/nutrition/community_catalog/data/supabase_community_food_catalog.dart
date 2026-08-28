import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../community/domain/community_text_policy.dart';
import '../../domain/unified_food.dart';

abstract interface class CommunityFoodCloudGateway {
  Future<void> upsert(Map<String, dynamic> payload);
  Future<void> withdraw(String localFoodUuid);
  Future<List<UnifiedFood>> search(String query, {int limit = 10});
}

class SupabaseCommunityFoodCatalog implements CommunityFoodCloudGateway {
  const SupabaseCommunityFoodCatalog(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    final localizedNames =
        (payload['localized_names'] as Map?)?.values ?? const <Object?>[];
    final aliases = payload['aliases'] as Iterable? ?? const <Object?>[];
    CommunityTextPolicy.enforceAll({
      CommunityTextSurface.foodName: payload['canonical_name']?.toString(),
      CommunityTextSurface.foodLocalizedName: localizedNames.join(' '),
      CommunityTextSurface.foodAlias: aliases.join(' '),
    });
    await _client
        .rpc(
          'bil_upsert_community_food_contribution',
          params: <String, dynamic>{'p_payload': payload},
        )
        .timeout(const Duration(seconds: 10));
  }

  @override
  Future<void> withdraw(String localFoodUuid) async {
    await _client
        .rpc(
          'bil_withdraw_community_food_contribution',
          params: <String, dynamic>{'p_client_food_id': localFoodUuid},
        )
        .timeout(const Duration(seconds: 10));
  }

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    final response = await _client
        .rpc(
          'bil_search_community_foods',
          params: <String, dynamic>{'p_query': query, 'p_limit': limit},
        )
        .timeout(const Duration(seconds: 4));
    final rows = (response as List?) ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => _toUnified(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  UnifiedFood _toUnified(Map<String, dynamic> row) {
    final localized = Map<String, dynamic>.from(
      (row['localized_names'] as Map?) ?? const <String, dynamic>{},
    );
    final aliases = ((row['aliases'] as List?) ?? const <dynamic>[])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final servingAmount = _number(row['serving_amount']) ?? 100;
    final servingUnit = row['serving_unit']?.toString().trim() ?? 'g';
    final verified = row['verified'] == true;

    NutrientAmount nutrient(String key) {
      final value = _number(row[key]);
      return value == null
          ? const NutrientAmount.missing()
          : NutrientAmount.known(value);
    }

    return UnifiedFood(
      id: 'community:${row['id']}',
      name: row['canonical_name']?.toString().trim() ?? 'Community food',
      arabicName: _optional(localized['ar']),
      category: 'community',
      keywords: <String>[
        ...aliases,
        ...localized.values.map((value) => value.toString()),
      ],
      barcode: _optional(row['barcode']),
      serving: FoodServing(
        amount: servingAmount,
        unit: servingUnit,
        grams: _servingGrams(servingAmount, servingUnit),
      ),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: nutrient('calories_kcal'),
        FoodNutrient.protein: nutrient('protein_g'),
        FoodNutrient.carbohydrates: nutrient('carbohydrate_g'),
        FoodNutrient.fat: nutrient('fat_g'),
        FoodNutrient.fiber: nutrient('fiber_g'),
        FoodNutrient.sugar: nutrient('sugar_g'),
        FoodNutrient.sodium: nutrient('sodium_mg'),
        FoodNutrient.potassium: nutrient('potassium_mg'),
        FoodNutrient.calcium: nutrient('calcium_mg'),
        FoodNutrient.magnesium: nutrient('magnesium_mg'),
        FoodNutrient.phosphorus: nutrient('phosphorus_mg'),
        FoodNutrient.iron: nutrient('iron_mg'),
        FoodNutrient.vitaminC: nutrient('vitamin_c_mg'),
      },
      source: FoodDataSource.custom,
      sourceLabel: verified
          ? 'BIL community — reviewed'
          : 'BIL community — unreviewed',
      verified: verified,
      isCustom: false,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _servingGrams(double amount, String unit) {
    return switch (unit.trim().toLowerCase()) {
      'kg' => amount * 1000,
      'mg' => amount / 1000,
      'oz' => amount * 28.349523125,
      'lb' => amount * 453.59237,
      _ => amount,
    };
  }
}
