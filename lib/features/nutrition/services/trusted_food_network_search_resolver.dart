import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/unified_food.dart';
import 'food_presentation_localizer.dart';
import 'food_search_assistance.dart';

/// Trusted server-side enrichment used only after BIL's local, installed and
/// community search sources have no match.
///
/// The USDA key stays in the Edge Function environment. A successful row is
/// materialized by [FoodRuntimeSearchAuthority], so the same food remains
/// available through the normal local/offline path afterwards.
class TrustedFoodNetworkSearchResolver {
  const TrustedFoodNetworkSearchResolver();

  static const _assistance = FoodSearchAssistance();

  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2 || limit <= 0) {
      return const <UnifiedFood>[];
    }

    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      // Supabase initialization and the auth store restore run in parallel
      // during the startup handoff. Do not turn that short window into a
      // permanent empty search result on a freshly opened Daily Log.
      if (session == null) {
        try {
          await client.auth.onAuthStateChange
              .firstWhere(
                (state) =>
                    state.event == AuthChangeEvent.initialSession ||
                    state.session != null,
              )
              .timeout(const Duration(seconds: 2));
        } on Object {
          // Offline/no-session startup is still a valid local-only state.
        }
        session = client.auth.currentSession;
      }
      if (session == null) return const <UnifiedFood>[];
      // A restored OAuth/Apple session can still be present locally after its
      // access token expires. Refresh before invoking the protected Edge
      // Function so a stale token cannot turn a valid cloud search into a
      // silent empty result.
      if (session.isExpired) {
        final refreshed = await client.auth.refreshSession();
        if (refreshed.session == null) return const <UnifiedFood>[];
      }
      final interfaceLocale = AppLocalizations.activeLocale.toLanguageTag();
      final queryLocale = FoodPresentationLocalizer.resultLocaleForQuery(
        query: normalizedQuery,
        interfaceLocaleTag: interfaceLocale,
      );
      final searchHint = _englishSearchHint(normalizedQuery);
      final response = await client.functions
          .invoke(
            'food-search',
            body: <String, Object?>{
              'query': normalizedQuery,
              'limit': limit.clamp(1, 20),
              'locale': queryLocale,
              ...?(searchHint == null
                  ? null
                  : <String, Object?>{'search_hint': searchHint}),
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.status != 200 || response.data is! Map) {
        return const <UnifiedFood>[];
      }
      final root = Map<String, dynamic>.from(response.data as Map);
      final rows = root['foods'];
      if (root['status'] != 'found' || rows is! List) {
        return const <UnifiedFood>[];
      }
      return rows
          .whereType<Map>()
          .map((row) => _toFood(Map<String, dynamic>.from(row)))
          .whereType<UnifiedFood>()
          .take(limit)
          .toList(growable: false);
    } on Object {
      return const <UnifiedFood>[];
    }
  }

  String? _englishSearchHint(String query) {
    final normalized = query.trim();
    for (final candidate in _assistance.expand(normalized)) {
      final hint = candidate.trim();
      if (hint.isEmpty || hint == normalized) continue;
      if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ,&()/-]{1,119}$').hasMatch(hint)) {
        return hint;
      }
    }
    return null;
  }

  UnifiedFood? _toFood(Map<String, dynamic> row) {
    final id = _text(row['fdc_id']);
    final name = _text(row['name']);
    if (id.isEmpty || name.isEmpty) return null;
    final nutrientRows = row['nutrients'] is List
        ? row['nutrients'] as List
        : const <Object?>[];

    double? nutrient(String expected) {
      for (final raw in nutrientRows) {
        if (raw is! Map) continue;
        final nutrient = Map<String, dynamic>.from(raw);
        if (_text(nutrient['name']).toLowerCase() != expected.toLowerCase()) {
          continue;
        }
        return _number(nutrient['amount']);
      }
      return null;
    }

    final calories = nutrient('Energy');
    if (calories == null) return null;
    final brand = _text(row['brand']);

    return UnifiedFood(
      id: 'usda:$id',
      name: name,
      category: _text(row['data_type']).isEmpty
          ? 'USDA food'
          : _text(row['data_type']),
      keywords: <String>[if (brand.isNotEmpty) brand],
      barcode: _optionalText(row['gtin']),
      // FoodData Central standardizes these nutrient amounts to a 100 g
      // basis. `serving_size` is label metadata and must not be used as the
      // nutrient basis without scaling every nutrient first.
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: _amount(calories),
        FoodNutrient.protein: _amount(nutrient('Protein')),
        FoodNutrient.carbohydrates: _amount(
          nutrient('Carbohydrate, by difference'),
        ),
        FoodNutrient.fat: _amount(nutrient('Total lipid (fat)')),
        FoodNutrient.fiber: _amount(nutrient('Fiber, total dietary')),
        FoodNutrient.sugar: _amount(nutrient('Sugars, total')),
        FoodNutrient.sodium: _amount(nutrient('Sodium, Na')),
        FoodNutrient.potassium: _amount(nutrient('Potassium, K')),
        FoodNutrient.calcium: _amount(nutrient('Calcium, Ca')),
        FoodNutrient.magnesium: _amount(nutrient('Magnesium, Mg')),
        FoodNutrient.phosphorus: _amount(nutrient('Phosphorus, P')),
        FoodNutrient.iron: _amount(nutrient('Iron, Fe')),
        FoodNutrient.vitaminC: _amount(nutrient('Vitamin C')),
      },
      source: FoodDataSource.foundation,
      sourceLabel: 'USDA FoodData Central — verified',
      verified: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    );
  }

  NutrientAmount _amount(double? value) => value == null
      ? const NutrientAmount.missing()
      : NutrientAmount.known(value);

  String _text(Object? value) => value?.toString().trim() ?? '';

  String? _optionalText(Object? value) {
    final valueText = _text(value);
    return valueText.isEmpty ? null : valueText;
  }

  double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };

  /// Exposes deterministic server-row decoding to focused contract tests.
  UnifiedFood? decodeServerFoodForTesting(Map<String, dynamic> row) =>
      _toFood(row);

  /// Exposes the reviewed multilingual hint contract to focused tests.
  String? searchHintForTesting(String query) => _englishSearchHint(query);
}
