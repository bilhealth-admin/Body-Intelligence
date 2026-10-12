import 'nutrient_daily_references.dart';

enum NutritionGoalStatus {
  unspecified,
  intentionalZero,
  custom,
  suggested,
  generalReference,
  legacyUnknown,
  reviewRequired,
  invalid,
  storageFailure,
}

enum NutritionGoalKind {
  energy,
  energyShare,
  allocation,
  reference,
  upperLimit,
}

/// Interpretation of a stored target, never a mutation of the original value.
/// FDA label limits here are not toxicological ULs or individual prescriptions.
final class NutritionGoalValue {
  const NutritionGoalValue({
    required this.key,
    required this.unit,
    required this.kind,
    required this.status,
    this.value,
    this.raw,
    this.suggestion,
    this.legacyRaw,
    this.warning,
    this.origin,
    this.reviewToken,
  });
  final String key, unit;
  final NutritionGoalKind kind;
  final NutritionGoalStatus status;
  final double? value, suggestion;
  final String? raw, legacyRaw, warning, origin, reviewToken;
  bool get needsReview =>
      status == NutritionGoalStatus.legacyUnknown ||
      status == NutritionGoalStatus.reviewRequired ||
      status == NutritionGoalStatus.invalid ||
      status == NutritionGoalStatus.storageFailure;
  bool get isManual =>
      status == NutritionGoalStatus.custom ||
      status == NutritionGoalStatus.intentionalZero;
  String get source => isManual
      ? origin ?? 'saved_override_unattributed'
      : switch (status) {
          NutritionGoalStatus.generalReference => 'fda_label_dv_2026_10_11',
          NutritionGoalStatus.suggested => 'profile_plan_4_4_9',
          _ => status.name,
        };
}

/// One atomic preference snapshot shared by every numeric target reader.
final class NutritionGoalSnapshot {
  NutritionGoalSnapshot._(this.goals, this.original);
  final Map<String, NutritionGoalValue> goals;
  final Map<String, String> original;
  static const units = <String, String>{
    'goal.calories': 'kcal',
    'goal.carbsPercent': '% energy',
    'goal.proteinPercent': '% energy',
    'goal.fatPercent': '% energy',
    'goal.carbsGrams': 'g',
    'goal.proteinGrams': 'g',
    'goal.fatGrams': 'g',
    'goal.saturatedFat': 'g',
    'goal.polyunsaturatedFat': 'g',
    'goal.monounsaturatedFat': 'g',
    'goal.transFat': 'g',
    'goal.cholesterol': 'mg',
    'goal.sodium': 'mg',
    'goal.potassium': 'mg',
    'goal.fiber': 'g',
    'goal.sugar': 'g',
    'goal.vitaminAMcg': 'mcg RAE',
    'goal.vitaminCMg': 'mg',
    'goal.calciumMg': 'mg',
    'goal.ironMg': 'mg',
    'goal.magnesium': 'mg',
    'goal.phosphorus': 'mg',
  };
  static const legacyKeys = <String, String>{
    'goal.vitaminAMcg': 'goal.vitaminA',
    'goal.vitaminCMg': 'goal.vitaminC',
    'goal.calciumMg': 'goal.calcium',
    'goal.ironMg': 'goal.iron',
  };
  static const macroKeys = <String>[
    'goal.calories',
    'goal.carbsPercent',
    'goal.proteinPercent',
    'goal.fatPercent',
    'goal.carbsGrams',
    'goal.proteinGrams',
    'goal.fatGrams',
  ];
  static final storageKeys = <String>{
    ...units.keys,
    ...legacyKeys.values,
    for (final key in units.keys) ...[
      'goal.origin.$key',
      'goal.legacyReviewed.$key',
      'goal.confirmed.$key',
    ],
    'goal.macroEditor.v2',
    'goal.macroLastEdited',
    for (final item in ['carbs', 'protein', 'fat']) ...[
      'goal.lock.$item',
      'goal.lockMode.$item',
    ],
  };

  static bool technicallyValid(String key, double? value) {
    if (!units.containsKey(key) ||
        value == null ||
        !value.isFinite ||
        value < 0) {
      return false;
    }
    if (key == 'goal.calories') return value > 0 && value <= 10000;
    if (key.endsWith('Percent')) return value <= 100;
    if (key.endsWith('Grams')) return value <= 2500;
    // Serialization/math guard only, deliberately NOT a nutritional safety limit.
    return value <= 1000000;
  }

  /// Decimal comma is accepted only when unambiguous: 1,000 / 1.000 are
  /// ambiguous thousands/decimal input. Arabic decimal U+066B is explicit.
  static double? parse(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
    var input = text.trim().replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (m) {
      final digit = m[0]!;
      return '${arabic.contains(digit) ? arabic.indexOf(digit) : persian.indexOf(digit)}';
    });
    if (input.contains('٬') || input.contains(' ') || input.contains('\n')) {
      return null;
    }
    final explicitDecimal = input.contains('٫');
    input = input.replaceAll('٫', '.');
    if (input.contains(',') && input.contains('.')) return null;
    if (!explicitDecimal && RegExp(r'^[1-9]\d*[,.]\d{3}$').hasMatch(input)) {
      return null;
    }
    input = input.replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(input)) return null;
    final parsed = double.tryParse(input);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  factory NutritionGoalSnapshot.resolve(
    Map<String, String> stored,
    Map<String, double> suggestions, {
    bool storageFailed = false,
  }) {
    final result = <String, NutritionGoalValue>{};
    double? parentTarget(String key) {
      final raw = stored[key];
      if (raw != null) {
        final value = double.tryParse(raw);
        return technicallyValid(key, value) ? value : null;
      }
      if (suggestions[key] != null) return suggestions[key];
      final macro = key == 'goal.carbsGrams' ? 'carbs' : 'fat';
      final energy =
          double.tryParse(stored['goal.calories'] ?? '') ??
          suggestions['goal.calories'];
      final percent =
          double.tryParse(stored['goal.${macro}Percent'] ?? '') ??
          suggestions['goal.${macro}Percent'];
      return energy == null || percent == null
          ? null
          : energy * percent / (macro == 'fat' ? 900 : 400);
    }

    for (final entry in units.entries) {
      final key = entry.key,
          raw = stored[key],
          legacy = stored[legacyKeys[key]];
      // Persisted canonical values use Dart's exact double encoding. Do not
      // reinterpret a historical comma or legacy % as a mass value.
      final parsed = raw == null ? null : double.tryParse(raw);
      final valid = technicallyValid(key, parsed);
      final suggestion = technicallyValid(key, suggestions[key])
          ? suggestions[key]
          : null;
      var status = storageFailed
          ? NutritionGoalStatus.storageFailure
          : raw != null
          ? (!valid
                ? NutritionGoalStatus.invalid
                : parsed == 0
                ? NutritionGoalStatus.intentionalZero
                : NutritionGoalStatus.custom)
          : legacy != null && stored['goal.legacyReviewed.$key'] != 'true'
          ? NutritionGoalStatus.legacyUnknown
          : suggestion == null
          ? NutritionGoalStatus.unspecified
          : NutrientDailyReferences.values.containsKey(key)
          ? NutritionGoalStatus.generalReference
          : NutritionGoalStatus.suggested;
      var value =
          storageFailed ||
              status == NutritionGoalStatus.invalid ||
              status == NutritionGoalStatus.legacyUnknown
          ? null
          : raw != null
          ? parsed
          : suggestion;
      final kind = key == 'goal.calories'
          ? NutritionGoalKind.energy
          : key.endsWith('Percent')
          ? NutritionGoalKind.energyShare
          : key.endsWith('Grams')
          ? NutritionGoalKind.allocation
          : NutrientDailyReferences.upperBoundReferences.contains(key) ||
                key == 'goal.transFat' ||
                key == 'goal.sugar'
          ? NutritionGoalKind.upperLimit
          : NutritionGoalKind.reference;
      String? warning;
      // Input-scale review is not a medical cap: a user may explicitly keep an
      // unusual customization. Never present an unacknowledged 10x label value
      // as a trusted suggestion while profile targets are still loading.
      if (valid && suggestion != null && parsed! > suggestion * 10) {
        warning = 'review_input_scale';
      }
      if (valid &&
          suggestion != null &&
          parsed! > suggestion &&
          NutrientDailyReferences.upperBoundReferences.contains(key)) {
        warning = 'above_label_reference';
      }
      if (valid &&
          key == 'goal.fiber' &&
          parsed! > (parentTarget('goal.carbsGrams') ?? double.infinity)) {
        warning = 'review_carbohydrate_definition';
      }
      final parent = key == 'goal.sugar'
          ? 'goal.carbsGrams'
          : const {
              'goal.saturatedFat',
              'goal.polyunsaturatedFat',
              'goal.monounsaturatedFat',
              'goal.transFat',
            }.contains(key)
          ? 'goal.fatGrams'
          : null;
      final parentValue = parent == null ? null : parentTarget(parent);
      if (valid &&
          parsed! > 0 &&
          ((parent != null && parentValue == null) ||
              (key == 'goal.fiber' &&
                  parentTarget('goal.carbsGrams') == null))) {
        warning = 'target_context_unavailable';
      }
      if (valid && parentValue != null && parsed! > parentValue) {
        warning = 'exceeds_total_target';
      }
      String? reviewToken;
      if (valid && warning != null) {
        final compared = key == 'goal.fiber'
            ? parentTarget('goal.carbsGrams')
            : parentValue;
        reviewToken =
            'v1|$key|$raw|${entry.value}|$warning|$compared|$suggestion';
        if (stored['goal.confirmed.$key'] != reviewToken) {
          status = NutritionGoalStatus.reviewRequired;
          value = null;
        }
      }
      result[key] = NutritionGoalValue(
        key: key,
        unit: entry.value,
        kind: kind,
        status: status,
        value: value,
        raw: raw,
        suggestion: suggestion,
        legacyRaw: legacy,
        warning: warning,
        reviewToken: reviewToken,
        origin: stored['goal.origin.$key'],
      );
    }
    // All seven macro readers see the SAME unavailable group on corrupt or
    // contradictory legacy data. Preserve original values; never normalize
    // one reader silently while another uses a different allocation.
    final macros = macroKeys.map((key) => result[key]!).toList();
    final energy = result['goal.calories']!.value;
    final percentages = [
      'carbs',
      'protein',
      'fat',
    ].map((key) => result['goal.${key}Percent']!.value).toList();
    var invalidGroup = macros.any((goal) => goal.needsReview);
    if (percentages.every((value) => value != null) &&
        (percentages.fold<double>(0, (sum, value) => sum + value!) - 100)
                .abs() >
            .001) {
      invalidGroup = true;
    }
    if (energy != null && percentages.every((value) => value != null)) {
      for (var i = 0; i < 3; i++) {
        final key = ['carbs', 'protein', 'fat'][i];
        final gram = result['goal.${key}Grams']!;
        final derived = energy * percentages[i]! / (key == 'fat' ? 900 : 400);
        if (gram.raw != null &&
            gram.value != null &&
            (gram.value! - derived).abs() > .011) {
          invalidGroup = true;
        }
        if (gram.raw == null) {
          result[gram.key] = NutritionGoalValue(
            key: gram.key,
            unit: gram.unit,
            kind: gram.kind,
            status: result['goal.${key}Percent']!.isManual
                ? NutritionGoalStatus.custom
                : NutritionGoalStatus.suggested,
            value: derived,
            suggestion: gram.suggestion,
          );
        }
      }
    }
    if (invalidGroup) {
      for (final key in macroKeys) {
        final previous = result[key]!;
        result[key] = NutritionGoalValue(
          key: key,
          unit: previous.unit,
          kind: previous.kind,
          status: storageFailed
              ? NutritionGoalStatus.storageFailure
              : NutritionGoalStatus.invalid,
          raw: previous.raw,
          suggestion: previous.suggestion,
          warning: 'review_macro_snapshot',
        );
      }
    }
    return NutritionGoalSnapshot._(
      Map.unmodifiable(result),
      Map.unmodifiable(stored),
    );
  }
}
