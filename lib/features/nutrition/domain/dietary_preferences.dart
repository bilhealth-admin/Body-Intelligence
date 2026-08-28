import 'dart:convert';

/// Food-selection preferences. These values never diagnose an allergy and do
/// not change energy or nutrient requirements; they only constrain food and
/// recipe suggestions.
enum DietaryPattern { omnivore, pescatarian, vegetarian, vegan }

enum DietaryRequirement { halal, kosher, glutenFree, lactoseFree }

enum DietaryAllergen {
  milk,
  egg,
  fish,
  shellfish,
  peanut,
  treeNut,
  wheat,
  soy,
  sesame,
}

final class DietaryPreferences {
  const DietaryPreferences({
    this.pattern = DietaryPattern.omnivore,
    this.approach = 'balanced',
    this.requirements = const <DietaryRequirement>{},
    this.allergens = const <DietaryAllergen>{},
    this.excludedIngredients = const <String>{},
  });

  static const storageKey = 'nutrition.dietaryPreferences.v1';
  static const supportedApproaches = <String>{
    'balanced',
    'high_protein',
    'low_carb',
    'keto',
    'mediterranean',
    'plant_forward',
  };

  final DietaryPattern pattern;
  final String approach;
  final Set<DietaryRequirement> requirements;
  final Set<DietaryAllergen> allergens;
  final Set<String> excludedIngredients;

  bool get hasFoodSelectionConstraints =>
      pattern != DietaryPattern.omnivore ||
      requirements.isNotEmpty ||
      allergens.isNotEmpty ||
      excludedIngredients.isNotEmpty;

  DietaryPreferences copyWith({
    DietaryPattern? pattern,
    String? approach,
    Set<DietaryRequirement>? requirements,
    Set<DietaryAllergen>? allergens,
    Set<String>? excludedIngredients,
  }) => DietaryPreferences(
    pattern: pattern ?? this.pattern,
    approach: _approach(approach ?? this.approach),
    requirements: Set.unmodifiable(requirements ?? this.requirements),
    allergens: Set.unmodifiable(allergens ?? this.allergens),
    excludedIngredients: Set.unmodifiable(
      (excludedIngredients ?? this.excludedIngredients)
          .map(normalizeDietaryTag)
          .where((value) => value.isNotEmpty),
    ),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'pattern': pattern.name,
    'approach': _approach(approach),
    'requirements': requirements.map((value) => value.name).toList()..sort(),
    'allergens': allergens.map((value) => value.name).toList()..sort(),
    'excludedIngredients': excludedIngredients.toList()..sort(),
  };

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toCoachContext() => <String, Object?>{
    'pattern': pattern.name,
    'approach': _approach(approach),
    'requirements': requirements.map((value) => value.name).toList()..sort(),
    'allergens': allergens.map((value) => value.name).toList()..sort(),
    'excludedIngredients': excludedIngredients.toList()..sort(),
    'foodSelectionOnly': true,
  };

  static DietaryPreferences decode(String? source, {String? legacyApproach}) {
    final fallback = DietaryPreferences(
      approach: _approach(legacyApproach ?? 'balanced'),
    );
    if (source == null || source.trim().isEmpty) return fallback;
    try {
      final value = jsonDecode(source);
      if (value is! Map || value['version'] != 1) return fallback;
      T enumValue<T extends Enum>(
        Iterable<T> values,
        Object? raw,
        T fallback,
      ) => values.where((value) => value.name == raw).firstOrNull ?? fallback;
      Set<T> enumSet<T extends Enum>(Iterable<T> values, Object? raw) {
        if (raw is! List) return <T>{};
        final names = raw.map((value) => '$value').toSet();
        return Set<T>.unmodifiable(
          values.where((value) => names.contains(value.name)),
        );
      }

      final exclusions = value['excludedIngredients'] is List
          ? (value['excludedIngredients'] as List)
                .map((item) => normalizeDietaryTag('$item'))
                .where((item) => item.isNotEmpty)
                .take(30)
                .toSet()
          : const <String>{};
      return DietaryPreferences(
        pattern: enumValue(
          DietaryPattern.values,
          value['pattern'],
          DietaryPattern.omnivore,
        ),
        approach: _approach('${value['approach'] ?? legacyApproach ?? ''}'),
        requirements: enumSet(DietaryRequirement.values, value['requirements']),
        allergens: enumSet(DietaryAllergen.values, value['allergens']),
        excludedIngredients: Set.unmodifiable(exclusions),
      );
    } on FormatException {
      return fallback;
    } on TypeError {
      return fallback;
    }
  }

  static String _approach(String value) {
    final normalized = normalizeDietaryTag(value);
    return supportedApproaches.contains(normalized) ? normalized : 'balanced';
  }
}

String normalizeDietaryTag(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

abstract final class DietaryCompatibility {
  static bool allows({
    required DietaryPreferences preferences,
    Iterable<String> dietTags = const <String>[],
    Iterable<String> allergens = const <String>[],
    Iterable<String> ingredients = const <String>[],
  }) {
    final tags = dietTags.map(normalizeDietaryTag).toSet();
    final recipeAllergens = allergens.map(_normalizeAllergen).toSet();
    final ingredientText = ingredients.map(normalizeDietaryTag).join(' ');
    if (preferences.allergens.any(
      (value) => recipeAllergens.contains(value.name),
    )) {
      return false;
    }
    if (preferences.excludedIngredients.any(
      (value) => ingredientText.contains(normalizeDietaryTag(value)),
    )) {
      return false;
    }
    if (preferences.requirements.contains(DietaryRequirement.glutenFree) &&
        !tags.contains('gluten_free')) {
      return false;
    }
    if (preferences.requirements.contains(DietaryRequirement.lactoseFree) &&
        !tags.contains('lactose_free') &&
        (recipeAllergens.contains(DietaryAllergen.milk.name) ||
            ingredientText.contains('milk') ||
            ingredientText.contains('yogurt'))) {
      return false;
    }
    if (preferences.requirements.contains(DietaryRequirement.halal) &&
        !tags.contains('halal')) {
      return false;
    }
    if (preferences.requirements.contains(DietaryRequirement.kosher) &&
        !tags.contains('kosher')) {
      return false;
    }
    return switch (preferences.pattern) {
      DietaryPattern.omnivore => true,
      DietaryPattern.pescatarian =>
        tags.contains('pescatarian') ||
            tags.contains('vegetarian') ||
            tags.contains('vegan'),
      DietaryPattern.vegetarian =>
        tags.contains('vegetarian') || tags.contains('vegan'),
      DietaryPattern.vegan => tags.contains('vegan'),
    };
  }

  static String _normalizeAllergen(String value) {
    final normalized = normalizeDietaryTag(value);
    return switch (normalized) {
      'dairy' || 'lactose' => DietaryAllergen.milk.name,
      'eggs' => DietaryAllergen.egg.name,
      'peanuts' => DietaryAllergen.peanut.name,
      'tree_nuts' || 'nuts' => DietaryAllergen.treeNut.name,
      'shellfish_crustacean' ||
      'crustacean_shellfish' => DietaryAllergen.shellfish.name,
      _ => normalized,
    };
  }
}
