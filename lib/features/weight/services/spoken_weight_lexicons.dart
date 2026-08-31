part of 'spoken_weight_parser.dart';

SpokenWeightCandidate? _parseSpokenWeight(
  String raw, {
  required MeasurementSystem fallbackSystem,
  String? localeTag,
}) {
  final transcript = raw.trim();
  if (transcript.isEmpty || transcript.length > 160) return null;
  final normalized = SpokenWeightParser._normalize(transcript).toLowerCase();
  if (SpokenWeightParser._containsNegativeMarker(normalized)) return null;

  final mentionsKilograms = SpokenWeightParser._containsAnyAlias(
    normalized,
    SpokenWeightParser._kilogramAliases,
  );
  final mentionsPounds = SpokenWeightParser._containsAnyAlias(
    normalized,
    SpokenWeightParser._poundAliases,
  );
  // Conflicting units are not safe to resolve automatically.
  if (mentionsKilograms && mentionsPounds) return null;
  final unit =
      (mentionsPounds
          ? SpokenWeightUnit.pounds
          : mentionsKilograms
          ? SpokenWeightUnit.kilograms
          : null) ??
      (fallbackSystem == MeasurementSystem.metric
          ? SpokenWeightUnit.kilograms
          : SpokenWeightUnit.pounds);

  final allNumeric = _spokenWeightNumericCandidates(
    normalized,
  ).toList(growable: false);
  // Dates, times and side comments often contain one plausible-looking
  // value plus other numbers. Never discard those other numbers and guess.
  if (allNumeric.length > 1) return null;
  final language = SpokenWeightParser._languageOf(localeTag);
  if (allNumeric.isNotEmpty &&
      SpokenWeightParser._containsSpokenNumberToken(normalized, <String>{
        language,
        'en',
        'ar',
      })) {
    // Mixed digit/number-word output (for example "82 point five") must
    // not be silently truncated to the digit portion.
    return null;
  }
  final numeric = allNumeric
      .where((value) => _isPlausibleSpokenWeight(value, unit))
      .toList(growable: false);

  final hasExplicitUnit = mentionsKilograms || mentionsPounds;
  final value =
      (numeric.isEmpty ? null : numeric.single) ??
      SpokenWeightParser._parseCjkNumber(
        normalized,
        allowSurroundingWords: hasExplicitUnit,
      ) ??
      SpokenWeightParser._parseNumberWords(
        normalized,
        language,
        allowSurroundingWords: hasExplicitUnit,
      ) ??
      SpokenWeightParser._parseNumberWords(
        normalized,
        'en',
        allowSurroundingWords: hasExplicitUnit,
      ) ??
      SpokenWeightParser._parseNumberWords(
        normalized,
        'ar',
        allowSurroundingWords: hasExplicitUnit,
      );
  if (value == null ||
      !value.isFinite ||
      !_isPlausibleSpokenWeight(value, unit)) {
    return null;
  }
  return SpokenWeightCandidate(value: value, unit: unit);
}

Iterable<double> _spokenWeightNumericCandidates(String value) sync* {
  for (final match in SpokenWeightParser._numericValue.allMatches(value)) {
    final token = match.group(0);
    if (token == null) continue;
    final parsed = _parseLocalizedSpokenWeightToken(token);
    if (parsed != null) yield parsed;
  }
}

double? _parseLocalizedSpokenWeightToken(String token) {
  final comma = token.lastIndexOf(',');
  final period = token.lastIndexOf('.');
  final separator = comma > period ? comma : period;
  if (separator < 0) return double.tryParse(token);
  final fractionDigits = token.length - separator - 1;
  if (fractionDigits == 3) {
    // Recognizers sometimes format a four-digit pound value as 1,000.
    return double.tryParse(token.replaceAll(RegExp(r'[\.,]'), ''));
  }
  final whole = token.substring(0, separator).replaceAll(RegExp(r'[\.,]'), '');
  final fraction = token.substring(separator + 1);
  return double.tryParse('$whole.$fraction');
}

bool _isPlausibleSpokenWeight(double value, SpokenWeightUnit unit) {
  final kilograms = unit == SpokenWeightUnit.kilograms
      ? value
      : value / UnitConverter.poundsPerKilogram;
  // Match the app's reviewed weight-entry controls and reject unsafe guesses.
  return kilograms.isFinite && kilograms >= 20 && kilograms <= 500;
}

const _additionalSpokenWeightLexicons = <String, _NumberLexicon>{
  'ru': _NumberLexicon(
    values: {
      'ноль': 0,
      'один': 1,
      'одна': 1,
      'два': 2,
      'три': 3,
      'четыре': 4,
      'пять': 5,
      'шесть': 6,
      'семь': 7,
      'восемь': 8,
      'девять': 9,
      'десять': 10,
      'двадцать': 20,
      'тридцать': 30,
      'сорок': 40,
      'пятьдесят': 50,
      'шестьдесят': 60,
      'семьдесят': 70,
      'восемьдесят': 80,
      'девяносто': 90,
      'сто': 100,
    },
    decimalWords: {'запятая', 'точка', 'целых'},
    ignoredWords: {'и'},
  ),
  'vi': _NumberLexicon(
    values: {
      'không': 0,
      'một': 1,
      'mốt': 1,
      'hai': 2,
      'ba': 3,
      'bốn': 4,
      'tư': 4,
      'năm': 5,
      'lăm': 5,
      'sáu': 6,
      'bảy': 7,
      'tám': 8,
      'chín': 9,
      'mười': 10,
    },
    multipliers: {'mươi': 10, 'trăm': 100},
    decimalWords: {'phẩy', 'chấm'},
  ),
  'pl': _NumberLexicon(
    values: {
      'zero': 0,
      'jeden': 1,
      'jedna': 1,
      'dwa': 2,
      'trzy': 3,
      'cztery': 4,
      'pięć': 5,
      'sześć': 6,
      'siedem': 7,
      'osiem': 8,
      'dziewięć': 9,
      'dziesięć': 10,
      'dwadzieścia': 20,
      'trzydzieści': 30,
      'czterdzieści': 40,
      'pięćdziesiąt': 50,
      'sześćdziesiąt': 60,
      'siedemdziesiąt': 70,
      'osiemdziesiąt': 80,
      'dziewięćdziesiąt': 90,
      'sto': 100,
    },
    decimalWords: {'przecinek', 'kropka'},
    ignoredWords: {'i'},
  ),
  'uk': _NumberLexicon(
    values: {
      'нуль': 0,
      'один': 1,
      'одна': 1,
      'два': 2,
      'три': 3,
      'чотири': 4,
      'пʼять': 5,
      "п'ять": 5,
      'шість': 6,
      'сім': 7,
      'вісім': 8,
      'девʼять': 9,
      "дев'ять": 9,
      'десять': 10,
      'двадцять': 20,
      'тридцять': 30,
      'сорок': 40,
      'пʼятдесят': 50,
      "п'ятдесят": 50,
      'шістдесят': 60,
      'сімдесят': 70,
      'вісімдесят': 80,
      'девʼяносто': 90,
      "дев'яносто": 90,
      'сто': 100,
    },
    decimalWords: {'кома', 'крапка', 'цілих'},
    ignoredWords: {'і'},
  ),
};

final class _NumberLexicon {
  const _NumberLexicon({
    required this.values,
    this.multipliers = const {},
    this.decimalWords = const {},
    this.ignoredWords = const {},
    this.stripLeadingConjunction = false,
    this.phraseReplacements = const {},
  });

  final Map<String, int> values;
  final Map<String, int> multipliers;
  final Set<String> decimalWords;
  final Set<String> ignoredWords;
  final bool stripLeadingConjunction;
  final Map<String, String> phraseReplacements;

  String normalizeToken(String raw) {
    var token = raw.toLowerCase();
    if (stripLeadingConjunction && token.length > 1 && token.startsWith('و')) {
      token = token.substring(1);
    }
    return token;
  }
}
