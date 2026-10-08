import '../services/coach_date_resolver.dart';
import 'coach_food_catalog_adapter.dart';

enum CoachFoodTurnKind {
  none,
  log,
  correction,
  likeYesterday,
  approveFixed,
  approveRecipe,
}

enum CoachFoodCorrectionKind { absolute, half, doubleAmount, replace }

final class CoachFoodParsedItem {
  const CoachFoodParsedItem({required this.concept, this.amount, this.unit});

  final String concept;
  final double? amount;
  final String? unit;
}

final class CoachFoodFixedApproval {
  const CoachFoodFixedApproval({
    required this.alias,
    required this.inputUnit,
    required this.gramsPerUnit,
  });

  final String alias;
  final String inputUnit;
  final double gramsPerUnit;
}

final class CoachFoodRecipeApproval {
  const CoachFoodRecipeApproval({
    required this.alias,
    required this.servingGrams,
  });

  final String alias;
  final double servingGrams;
}

final class CoachFoodParsedTurn {
  const CoachFoodParsedTurn({
    required this.kind,
    required this.normalized,
    this.items = const [],
    this.mealType,
    this.date,
    this.invalidExplicitDate = false,
    this.correctionKind,
    this.targetConcept,
    this.fixedApproval,
    this.recipeApproval,
  });

  final CoachFoodTurnKind kind;
  final String normalized;
  final List<CoachFoodParsedItem> items;
  final String? mealType;
  final DateTime? date;
  final bool invalidExplicitDate;
  final CoachFoodCorrectionKind? correctionKind;
  final String? targetConcept;
  final CoachFoodFixedApproval? fixedApproval;
  final CoachFoodRecipeApproval? recipeApproval;
}

/// Deterministic food-command parser. It only identifies user-declared facts;
/// nutrition identity/source resolution happens later against saved data.
final class CoachFoodTurnParser {
  const CoachFoodTurnParser();

  CoachFoodParsedTurn parse(String input, {required DateTime referenceLocal}) {
    final normalized = _normalize(input);
    if (normalized.isEmpty || _looksLikeBodyWeight(normalized)) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.none,
        normalized: normalized,
      );
    }
    final dateResolver = const CoachDateResolver();
    final hasExplicit = dateResolver.hasExplicitDate(input);
    final date = dateResolver.resolve(input, referenceLocal: referenceLocal);
    final invalidExplicit = hasExplicit && date == null;
    final mealType = _mealType(normalized);

    final recipeApproval = _recipeApproval(normalized);
    if (recipeApproval != null) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.approveRecipe,
        normalized: normalized,
        date: date,
        mealType: mealType,
        invalidExplicitDate: invalidExplicit,
        recipeApproval: recipeApproval,
      );
    }

    final fixed = _fixedApproval(normalized);
    if (fixed != null) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.approveFixed,
        normalized: normalized,
        date: date,
        mealType: mealType,
        invalidExplicitDate: invalidExplicit,
        fixedApproval: fixed,
      );
    }

    if (_hasAny(normalized, const [
      'مثل امس',
      'نفس امس',
      'زي امس',
      'كرر امس',
      'same as yesterday',
      'like yesterday',
      'repeat yesterday',
    ])) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.likeYesterday,
        normalized: normalized,
        date: date,
        mealType: mealType,
        invalidExplicitDate: invalidExplicit,
      );
    }

    final correction = _correctionKind(normalized);
    if (correction != null) {
      final correctionBody = _stripCorrectionWords(normalized);
      final amountOnly = RegExp(
        r'^(\d+(?:[\.,]\d+)?)\s*(g|غ|جرام|غرام|ml|مل|ملي|item|items|piece|pieces|حبه|حبة|حبات|scoop|scoops|سكوب|serving|servings|حصة|حصه)$',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(correctionBody.trim());
      final parsed = amountOnly == null
          ? _items(correctionBody)
          : <CoachFoodParsedItem>[
              CoachFoodParsedItem(
                concept: '',
                amount: _number(amountOnly.group(1)!),
                unit: normalizeFoodUnit(amountOnly.group(2)!),
              ),
            ];
      final target = _correctionTarget(normalized, parsed);
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.correction,
        normalized: normalized,
        items: parsed,
        date: date,
        mealType: mealType,
        invalidExplicitDate: invalidExplicit,
        correctionKind: correction,
        targetConcept: target,
      );
    }

    if (!_loggingIntent(normalized)) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.none,
        normalized: normalized,
      );
    }
    final body = _stripIntentAndContext(normalized);
    final parsed = _items(body);
    if (parsed.isEmpty) {
      return CoachFoodParsedTurn(
        kind: CoachFoodTurnKind.none,
        normalized: normalized,
      );
    }
    return CoachFoodParsedTurn(
      kind: CoachFoodTurnKind.log,
      normalized: normalized,
      items: parsed,
      mealType: mealType,
      date: date,
      invalidExplicitDate: invalidExplicit,
    );
  }

  static bool _loggingIntent(String value) => _hasAny(value, const [
    'اكلت',
    'سجل',
    'سجّل',
    'ضيف',
    'اضف',
    'أضف',
    'فطرت',
    'اتغديت',
    'تعشيت',
    'i ate',
    'i had',
    'log ',
    'add ',
    'record ',
  ]);

  static CoachFoodCorrectionKind? _correctionKind(String value) {
    if (_hasAny(value, const [
      'نصها',
      'نصفها',
      'نصه',
      'نصفه',
      'half it',
      'halve it',
    ])) {
      return CoachFoodCorrectionKind.half;
    }
    if (_hasAny(value, const ['ضعفها', 'ضعفه', 'دبلها', 'دبله', 'double it'])) {
      return CoachFoodCorrectionKind.doubleAmount;
    }
    if (_hasAny(value, const ['بدل ', 'استبدل ', 'replace ', 'instead of'])) {
      return CoachFoodCorrectionKind.replace;
    }
    if (_hasAny(value, const [
          'لا قصدي',
          'قصدي',
          'لا، قصدي',
          'actually',
          'i meant',
          'صحح',
        ]) ||
        // 'Correction' may simply be the subject of a conversation.
        // Route an explicit directive to Food, not a sentence asking to
        // *review* a correction that another native tool has prepared.
        RegExp(r'^(?:correction|تصحيح)(?=\s|:|$)').hasMatch(value)) {
      return CoachFoodCorrectionKind.absolute;
    }
    return null;
  }

  static String _correctionTarget(
    String normalized,
    List<CoachFoodParsedItem> parsed,
  ) {
    final replacement = RegExp(
      r'(?:بدل|استبدل|replace)\s+(.+?)\s+(?:ب|بـ|with)\s+',
      unicode: true,
    ).firstMatch(normalized);
    if (replacement != null) return replacement.group(1)!.trim();
    if (parsed.length == 1 && parsed.single.concept.trim().isNotEmpty) {
      return parsed.single.concept;
    }
    return '';
  }

  static CoachFoodRecipeApproval? _recipeApproval(String value) {
    if (!_hasAny(value, const [
      'اعتمد وصفه',
      'ثبت وصفه',
      'ثبّت وصفه',
      'approve recipe',
      'save recipe as fixed',
    ])) {
      return null;
    }
    final patterns = <RegExp>[
      RegExp(
        r'(?:اعتمد|ثبت|ثبّت)\s+وصفه\s+(.+?)\s+(?:الحصه|حصة|حصه)\s+(\d+(?:[\.,]\d+)?)\s*(?:g|غ|جرام|غرام)$',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:اعتمد|ثبت|ثبّت)\s+وصفه\s+(.+?)\s+(\d+(?:[\.,]\d+)?)\s*(?:g|غ|جرام|غرام)\s+(?:للحصة|لحصه|للحِصة)$',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:approve recipe|save recipe as fixed)\s+(.+?)\s+(?:serving\s+)?(\d+(?:[\.,]\d+)?)\s*g$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match == null) continue;
      final grams = _number(match.group(2)!);
      if (grams > 0) {
        return CoachFoodRecipeApproval(
          alias: match.group(1)!.trim(),
          servingGrams: grams,
        );
      }
    }
    return null;
  }

  static CoachFoodFixedApproval? _fixedApproval(String value) {
    if (!_hasAny(value, const [
      'اعتمد',
      'ثبت',
      'ثبّت',
      'خليها ثابته',
      'خليها ثابتة',
      'remember as fixed',
      'save as fixed',
      'use as fixed',
      'approve',
    ])) {
      return null;
    }
    // Volume/count conversion explicitly stated as "200 ml = 206 g".
    final conversion = RegExp(
      r'(?:اعتمد|ثبت|ثبّت|remember as fixed|save as fixed|use as fixed|approve)\s+(.+?)\s+(\d+(?:[\.,]\d+)?)\s*(ml|مل|item|piece|حبه|حبة|scoop|سكوب|serving|حصة)\s+(?:(?:يعادل|يساوي)\s+)?(\d+(?:[\.,]\d+)?)\s*(?:g|غ|جرام|غرام)$',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(value);
    if (conversion != null) {
      final amount = _number(conversion.group(2)!);
      final grams = _number(conversion.group(4)!);
      if (amount > 0 && grams > 0) {
        return CoachFoodFixedApproval(
          alias: conversion.group(1)!.trim(),
          inputUnit: normalizeFoodUnit(conversion.group(3)!),
          gramsPerUnit: grams / amount,
        );
      }
    }
    // Common Personal BIL shorthand: "اعتمد البيضة 50غ" / "fix scoop 30g".
    final count = RegExp(
      r'(?:اعتمد|ثبت|ثبّت|remember as fixed|save as fixed|use as fixed|approve)\s+(.+?)\s+(\d+(?:[\.,]\d+)?)\s*(?:g|غ|جرام|غرام)$',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(value);
    if (count != null) {
      final grams = _number(count.group(2)!);
      if (grams > 0) {
        return CoachFoodFixedApproval(
          alias: count.group(1)!.trim(),
          inputUnit: 'item',
          gramsPerUnit: grams,
        );
      }
    }
    return null;
  }

  static List<CoachFoodParsedItem> _items(String body) {
    var value = body.trim();
    if (value.isEmpty) return const [];
    value = value
        .replaceAll(
          RegExp(r'\s+(?:و|and)\s+(?=\d)', caseSensitive: false, unicode: true),
          ' | ',
        )
        .replaceAll(RegExp(r'\s*(?:،|,|;|\+)\s*'), ' | ');
    final chunks = value
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    final result = <CoachFoodParsedItem>[];
    for (var chunk in chunks) {
      chunk = _stripContextWords(chunk);
      if (chunk.isEmpty) continue;
      final leading = RegExp(
        r'^(\d+(?:[\.,]\d+)?)\s*(g|غ|جرام|غرام|ml|مل|ملي|item|items|piece|pieces|حبه|حبة|حبات|scoop|scoops|سكوب|serving|servings|حصة|حصه)?\s+(.+)$',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(chunk);
      if (leading != null) {
        result.add(
          CoachFoodParsedItem(
            concept: _cleanConcept(leading.group(3)!),
            amount: _number(leading.group(1)!),
            unit: leading.group(2) == null
                ? null
                : normalizeFoodUnit(leading.group(2)!),
          ),
        );
        continue;
      }
      final trailing = RegExp(
        r'^(.+?)\s+(\d+(?:[\.,]\d+)?)\s*(g|غ|جرام|غرام|ml|مل|ملي|item|items|piece|pieces|حبه|حبة|حبات|scoop|scoops|سكوب|serving|servings|حصة|حصه)$',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(chunk);
      if (trailing != null) {
        result.add(
          CoachFoodParsedItem(
            concept: _cleanConcept(trailing.group(1)!),
            amount: _number(trailing.group(2)!),
            unit: normalizeFoodUnit(trailing.group(3)!),
          ),
        );
        continue;
      }
      final concept = _cleanConcept(chunk);
      if (concept.isNotEmpty && !_onlyContext(concept)) {
        result.add(CoachFoodParsedItem(concept: concept));
      }
    }
    return result
        .where((item) => item.concept.isNotEmpty)
        .toList(growable: false);
  }

  static String _stripIntentAndContext(String value) {
    var result = value;
    for (final token in const [
      'اكلت',
      'سجل',
      'سجّل',
      'ضيف',
      'اضف',
      'أضف',
      'فطرت',
      'اتغديت',
      'تعشيت',
      'i ate',
      'i had',
      'log',
      'add',
      'record',
    ]) {
      result = result.replaceFirst(
        RegExp('^${RegExp.escape(_normalize(token))}\\s*', unicode: true),
        '',
      );
    }
    return _stripContextWords(result);
  }

  static String _stripCorrectionWords(String value) {
    var result = value;
    for (final token in const [
      'لا قصدي',
      'قصدي',
      'actually',
      'i meant',
      'correction',
      'صحح',
      'نصها',
      'نصفها',
      'نصه',
      'نصفه',
      'half it',
      'halve it',
      'ضعفها',
      'ضعفه',
      'دبلها',
      'دبله',
      'double it',
    ]) {
      result = result.replaceAll(_normalize(token), ' ');
    }
    final replacement = RegExp(
      r'^(?:بدل|استبدل|replace)\s+.+?\s+(?:ب|بـ|with)\s+',
      unicode: true,
    ).firstMatch(result.trim());
    if (replacement != null) result = result.trim().substring(replacement.end);
    return _stripContextWords(result);
  }

  static String _stripContextWords(String value) {
    var result = value;
    for (final token in const [
      'اليوم',
      'امس',
      'أمس',
      'مبارح',
      'today',
      'yesterday',
      'فطور',
      'فطورى',
      'افطار',
      'الإفطار',
      'الغداء',
      'غداء',
      'العشاء',
      'عشاء',
      'سناك',
      'وجبه خفيفه',
      'وجبة خفيفة',
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    ]) {
      result = result.replaceAll(
        RegExp(
          '(?<![\\p{L}\\p{N}])${RegExp.escape(_normalize(token))}(?![\\p{L}\\p{N}])',
          unicode: true,
        ),
        ' ',
      );
    }
    // Date numerals must never become a food quantity. Normalization may
    // already have replaced '-'/'/' with spaces, so remove both forms.
    result = const CoachDateResolver().withoutExplicitDates(result);
    result = result.replaceAll(
      RegExp(r'(?<!\d)\d{4}\s+\d{1,2}\s+\d{1,2}(?!\d)'),
      ' ',
    );
    result = result.replaceAll(
      RegExp(
        r'(?<!\d)\d{1,2}\s+(?:jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december|يناير|فبراير|مارس|ابريل|مايو|يونيو|يوليو|اغسطس|سبتمبر|اكتوبر|نوفمبر|ديسمبر)\s+\d{4}(?!\d)',
        caseSensitive: false,
        unicode: true,
      ),
      ' ',
    );
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _mealType(String value) {
    if (_hasAny(value, const ['فطور', 'افطار', 'breakfast'])) {
      return 'breakfast';
    }
    if (_hasAny(value, const ['غداء', 'الغداء', 'lunch'])) return 'lunch';
    if (_hasAny(value, const ['عشاء', 'العشاء', 'dinner'])) return 'dinner';
    if (_hasAny(value, const ['سناك', 'وجبه خفيفه', 'وجبة خفيفة', 'snack'])) {
      return 'snack';
    }
    return null;
  }

  static String inferMealType(DateTime local) {
    final hour = local.hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 22) return 'dinner';
    return 'snack';
  }

  static bool _looksLikeBodyWeight(String value) {
    // A read-only weight-history request includes the word "سجل" (record).
    // That is not food logging, even for the plural "أوزاني" spelling.
    // Match the complete navigation intent; do not swallow actual food logs.
    if (RegExp(
      r'^(?:(?:استعرض|اعرض|افتح) سجل (?:الوزن|وزني|اوزاني)|تاريخ (?:وزني|اوزاني))$',
      unicode: true,
    ).hasMatch(value)) {
      return true;
    }
    return _hasAny(value, const [
          'وزني',
          'وزن الجسم',
          'body weight',
          'my weight',
          'weigh ',
        ]) &&
        !_loggingIntent(value);
  }

  static bool _onlyContext(String value) => const {
    'اليوم',
    'امس',
    'مبارح',
    'today',
    'yesterday',
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  }.contains(value);

  static bool _hasAny(String value, List<String> tokens) =>
      tokens.any((token) => value.contains(_normalize(token)));

  static String _cleanConcept(String value) => value
      .replaceAll(
        RegExp(r'^(?:من|of)\s+', caseSensitive: false, unicode: true),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _number(String value) =>
      double.parse(value.replaceAll(',', '.'));

  static String _normalize(String input) => normalizeFoodConcept(input);
}
