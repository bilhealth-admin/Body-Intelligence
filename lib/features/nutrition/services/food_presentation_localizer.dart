import '../../../app/localization/bil_written_language_resolver.dart';

import 'food_search_assistance.dart';

part 'food_presentation_food_names.dart';
part 'food_presentation_core_names.dart';
part 'food_presentation_units_and_labels.dart';

/// Presentation-only localization for a small reviewed set of canonical foods
/// and serving units.
///
/// It never translates arbitrary catalog text. Branded, custom, and unknown
/// scientific names remain exactly as stored so the UI cannot invent identity.
abstract final class FoodPresentationLocalizer {
  static const supportedLocaleTags = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static String foodName({
    required String name,
    required String localeTag,
    String? arabicName,
    bool isCustom = false,
    String source = '',
  }) {
    final original = name.trim();
    if (original.isEmpty) return original;
    if (localeTag == 'en') return original;
    if (!isCustom && !_isBranded(source) && localeTag == 'ar') {
      // Translate only when the reviewed lexicon preserves most of the
      // authoritative food identity. Partial labels are deliberately rejected.
      final reviewedArabic = const FoodSearchAssistance().arabicNameFor(
        original,
      );
      if (reviewedArabic != null) return reviewedArabic;
      // A catalog can contain a stale or machine-generated Arabic field. Use
      // it only when the authoritative English identity has no reviewed
      // translation; this keeps Android search rows from showing malformed
      // labels such as a broken translation of a bread variant.
      if (arabicName?.trim().isNotEmpty == true) {
        return arabicName!.trim();
      }
    }
    if (isCustom || _isBranded(source)) return original;
    final normalized = _normalize(original);
    final concept = _reviewedFoodConcept(normalized);
    return _localizedFoodName(concept, localeTag) ?? original;
  }

  /// Food rows follow the language the user actually typed when it can be
  /// determined safely. The interface locale remains the fallback for short,
  /// numeric, branded, or otherwise ambiguous queries.
  static String resultLocaleForQuery({
    required String query,
    required String interfaceLocaleTag,
  }) {
    final fallback = _canonicalLocaleTag(interfaceLocaleTag);
    final probe = _normalizeLanguageProbe(query);
    if (probe.isEmpty) return fallback;

    // Exact/whole-name matches are stronger than script heuristics. This also
    // distinguishes names such as simplified/traditional Chinese reviewed by
    // BIL, and handles Latin-script queries such as "poulet" and "mela".
    final reviewedLocales = _reviewedLocalesForQuery(probe);
    if (reviewedLocales.length == 1) return reviewedLocales.single;
    if (reviewedLocales.contains(fallback)) return fallback;
    if (reviewedLocales.contains('en') && _isAsciiLettersAndSpaces(probe)) {
      return 'en';
    }
    // Multiple reviewed names can be identical across languages (for example
    // Teff in several Latin-script locales). Never pick the first catalog row
    // and present it as detected keyboard language.
    if (reviewedLocales.isNotEmpty) return fallback;

    return BilWrittenLanguageResolver.detectLocale(
          query,
          fallbackLocaleTag: fallback,
        ) ??
        fallback;
  }

  /// Whether an anonymous browse suggestion owns a native display name.
  /// Branded/user-entered names remain authoritative in explicit search, but
  /// must not leak as English fallbacks into Arabic "popular" suggestions.
  static bool hasLocalizedBrowseName({
    required String name,
    required String localeTag,
    String? arabicName,
    bool isCustom = false,
    String source = '',
  }) {
    if (localeTag == 'en') return true;
    final original = name.trim();
    if (original.isEmpty) return false;
    if (isCustom || _isBranded(source)) return true;
    if (localeTag == 'ar' && arabicName?.trim().isNotEmpty == true) return true;
    return _reviewedFoodConcept(_normalize(original)) != null;
  }

  static String servingUnit(String raw, String localeTag) {
    final original = raw.trim();
    final normalized = _normalize(original);
    if (const {'', 'undetermined', 'unknown', 'unit'}.contains(normalized)) {
      return _units['unavailable']?[localeTag] ??
          _units['unavailable']?['en'] ??
          'Serving unavailable';
    }
    final concept = switch (normalized) {
      'g' || 'gram' || 'grams' => 'g',
      'mg' || 'milligram' || 'milligrams' => 'mg',
      'ml' || 'milliliter' || 'milliliters' => 'ml',
      'kcal' || 'calorie' || 'calories' => 'kcal',
      'piece' || 'pieces' => 'piece',
      'serving' || 'servings' => 'serving',
      'oz' || 'ounce' || 'ounces' => 'oz',
      'kg' || 'kilogram' || 'kilograms' => 'kg',
      'lb' || 'pound' || 'pounds' => 'lb',
      _ => null,
    };
    if (concept == null) return original;
    return _units[concept]?[localeTag] ?? _units[concept]?['en'] ?? original;
  }

  static bool hasKnownServingUnit(String raw) =>
      !const {'', 'undetermined', 'unknown', 'unit'}.contains(_normalize(raw));

  static String servingText({
    required String amount,
    required String unit,
    required String localeTag,
  }) {
    if (!hasKnownServingUnit(unit)) return servingUnit(unit, localeTag);
    return '$amount ${servingUnit(unit, localeTag)}';
  }

  /// Compact browse rows omit unknown portion metadata entirely. Showing a
  /// translated "unavailable" sentence beside calories creates visual noise
  /// and looks like a real serving value.
  static String? browseServingText({
    required String amount,
    required String unit,
    required String localeTag,
  }) => hasKnownServingUnit(unit)
      ? servingText(amount: amount, unit: unit, localeTag: localeTag)
      : null;

  static String label(String key, String localeTag) =>
      _labels[key]?[localeTag] ?? _labels[key]?['en'] ?? key;

  static bool _isBranded(String source) {
    final normalized = source.toLowerCase();
    return normalized.contains('brand') ||
        normalized.contains('barcode') ||
        normalized.contains('product');
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String _canonicalLocaleTag(String raw) {
    final normalized = raw.trim().replaceAll('_', '-');
    if (supportedLocaleTags.contains(normalized)) return normalized;
    final lower = normalized.toLowerCase();
    if (lower.startsWith('zh-hant') || lower == 'zh-tw' || lower == 'zh-hk') {
      return 'zh-Hant';
    }
    if (lower.startsWith('zh')) return 'zh-Hans';
    if (lower == 'pt-br') return 'pt-BR';
    if (lower.startsWith('pt')) return 'pt-PT';
    final language = lower.split('-').first;
    for (final locale in supportedLocaleTags) {
      if (locale.toLowerCase() == language) return locale;
    }
    return 'en';
  }

  static String _normalizeLanguageProbe(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_,.;:!?/\\()\[\]{}]+'), ' ')
      .trim();

  static bool _isAsciiLettersAndSpaces(String value) =>
      RegExp(r'^[a-z ]+$').hasMatch(value);

  static List<String> _reviewedLocalesForQuery(String query) {
    final exact = <String>{};
    final wholePhrase = <String>{};

    void consider(String locale, String rawName) {
      final name = _normalizeLanguageProbe(rawName);
      if (name.isEmpty) return;
      if (query == name) {
        exact.add(locale);
        return;
      }
      if (query.startsWith('$name ') ||
          query.endsWith(' $name') ||
          query.contains(' $name ')) {
        wholePhrase.add(locale);
      }
    }

    for (final translations in _foods.values) {
      for (final entry in translations.entries) {
        consider(entry.key, entry.value);
      }
    }
    for (final translations in _coreFoodNames.values) {
      for (var index = 0; index < translations.length; index++) {
        if (index >= _foodLocaleOrder.length) break;
        consider(_foodLocaleOrder[index], translations[index]);
      }
    }
    final matches = exact.isNotEmpty ? exact : wholePhrase;
    return <String>[
      for (final locale in _foodLocaleOrder)
        if (matches.contains(locale)) locale,
    ];
  }

  static bool _isReviewedWholeEggName(String normalized) {
    if (normalized == 'egg' || normalized == 'eggs') return true;
    if (normalized.startsWith('egg ') || normalized.startsWith('eggs ')) {
      return !normalized.startsWith('eggplant') &&
          !normalized.contains(' egg roll');
    }
    return normalized.startsWith('chicken egg ') ||
        normalized.startsWith('chicken eggs ');
  }

  static String? _reviewedFoodConcept(String normalized) {
    bool has(String word) => RegExp(
      '(^| )${RegExp.escape(word)}'
      r'( |$)',
    ).hasMatch(normalized);
    if (normalized.contains('chicken breast')) return 'chickenBreast';
    if (_isReviewedWholeEggName(normalized) &&
        (normalized.contains('boiled') || normalized.contains('hard cooked'))) {
      return 'boiledEggs';
    }
    if (_isReviewedWholeEggName(normalized)) return 'eggs';
    for (final entry in const <(String, String)>[
      ('apple', 'apple'),
      ('banana', 'banana'),
      ('orange', 'orange'),
      ('chicken', 'chicken'),
      ('beef', 'beef'),
      ('fish', 'fish'),
      ('rice', 'rice'),
      ('bread', 'bread'),
      ('milk', 'milk'),
      ('yogurt', 'yogurt'),
      ('yoghurt', 'yogurt'),
      ('cheese', 'cheese'),
      ('potato', 'potato'),
      ('tomato', 'tomato'),
      ('cucumber', 'cucumber'),
      ('oat', 'oats'),
      ('oats', 'oats'),
      ('salmon', 'salmon'),
      ('tuna', 'tuna'),
      ('lentil', 'lentils'),
      ('lentils', 'lentils'),
      ('bean', 'beans'),
      ('beans', 'beans'),
      ('water', 'water'),
      ('coffee', 'coffee'),
      ('tea', 'tea'),
      ('teff', 'teff'),
    ]) {
      if (has(entry.$1)) return entry.$2;
    }
    if (normalized.contains('cloud ear mushroom') ||
        normalized.contains('wood ear mushroom')) {
      return 'woodEarMushroom';
    }
    return null;
  }

  static String? _localizedFoodName(String? concept, String localeTag) {
    if (concept == null) return null;
    final direct = _foods[concept]?[localeTag];
    if (direct != null) return direct;
    final index = _foodLocaleOrder.indexOf(localeTag);
    final values = _coreFoodNames[concept];
    return index < 0 || values == null ? null : values[index];
  }
}
