import '../../../core/units/measurement_units.dart';

part 'spoken_weight_lexicons.dart';

enum SpokenWeightUnit { kilograms, pounds }

final class SpokenWeightCandidate {
  const SpokenWeightCandidate({required this.value, required this.unit});

  final double value;
  final SpokenWeightUnit unit;

  double get kilograms => unit == SpokenWeightUnit.kilograms
      ? value
      : value / UnitConverter.poundsPerKilogram;
}

/// Converts an operating-system speech transcript into one unambiguous,
/// plausible weight.
///
/// Every BIL locale is supported when its recognizer returns digits. This
/// includes Arabic-Indic, Persian, Devanagari, Bengali, Thai and full-width
/// digits, as well as localized decimal separators. Number-word fallbacks
/// cover the most common recognizer behaviours, including Arabic/English,
/// additive European and Asian forms, and CJK ideographic numbers.
abstract final class SpokenWeightParser {
  static final RegExp _numericValue = RegExp(
    r'(?<!\d)\d{1,4}(?:[\.,]\d{1,3})?(?!\d)',
  );

  static const _kilogramAliases = <String>{
    'kg',
    'kgs',
    'kilo',
    'kilos',
    'quilo',
    'quilos',
    'kilogram',
    'kilograms',
    'kilogramme',
    'kilogrammes',
    'kilogramm',
    'kilogrammi',
    'كيلو',
    'كيلوجرام',
    'كيلوغرام',
    'كجم',
    'کیلو',
    'کیلوگرم',
    'کلو',
    'کلوگرام',
    'किलो',
    'किलोग्राम',
    'किग्रा',
    'কিলো',
    'কিলোগ্রাম',
    'কেজি',
    '公斤',
    '千克',
    'キロ',
    'キログラム',
    '킬로',
    '킬로그램',
    'кг',
    'килограмм',
    'килограмма',
    'килограммов',
    'кіло',
    'кілограм',
    'кілограми',
    'кілограмів',
    'กิโล',
    'กิโลกรัม',
    'ký',
    'kí',
    'kilô',
    'ki-lô',
  };

  static const _poundAliases = <String>{
    'lb',
    'lbs',
    'pound',
    'pounds',
    'libra',
    'libras',
    'libbre',
    'livre',
    'livres',
    'pfund',
    'pond',
    'pon',
    'paun',
    'funt',
    'رطل',
    'أرطال',
    'ارطال',
    'پوند',
    'پاؤنڈ',
    'पाउंड',
    'পাউন্ড',
    '磅',
    'ポンド',
    '파운드',
    'ปอนด์',
    'фунт',
    'фунта',
    'фунтов',
    'фунтів',
  };

  static const _negativeAliases = <String>{
    'minus',
    'negative',
    'moins',
    'menos',
    'meno',
    'eksi',
    'negatif',
    'negativo',
    'negatief',
    'ناقص',
    'سالب',
    'منفی',
    'माइनस',
    'ऋण',
    'マイナス',
    '마이너스',
    '负',
    '負',
    'минус',
    'мінус',
    'মাইনাস',
    'âm',
    'ลบ',
    'ujemny',
  };

  static SpokenWeightCandidate? parse(
    String raw, {
    required MeasurementSystem fallbackSystem,
    String? localeTag,
  }) => _parseSpokenWeight(
    raw,
    fallbackSystem: fallbackSystem,
    localeTag: localeTag,
  );

  static bool _containsNegativeMarker(String value) {
    if (RegExp(r'(^|[^\p{L}\d])[-−﹣－]\s*\d', unicode: true).hasMatch(value)) {
      return true;
    }
    return _containsAnyAlias(value, _negativeAliases);
  }

  static bool _containsSpokenNumberToken(String value, Set<String> languages) {
    if (RegExp(r'[零〇一二两兩三四五六七八九十百영공일이삼사오육칠팔구십백点點점]').hasMatch(value)) {
      return true;
    }
    for (final language in languages) {
      final lexicon = _lexicons[language];
      if (lexicon == null) continue;
      var prepared = value;
      for (final replacement in lexicon.phraseReplacements.entries) {
        prepared = prepared.replaceAll(replacement.key, replacement.value);
      }
      for (final raw
          in prepared
              .replaceAll('-', ' ')
              .replaceAll(RegExp(r"[^\p{L}'’]+", unicode: true), ' ')
              .trim()
              .split(RegExp(r'\s+'))) {
        final token = lexicon.normalizeToken(raw);
        if (lexicon.values.containsKey(token) ||
            lexicon.multipliers.containsKey(token) ||
            lexicon.decimalWords.contains(token)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _containsAnyAlias(String value, Set<String> aliases) {
    for (final alias in aliases) {
      if (_asciiWord.hasMatch(alias)) {
        final escaped = RegExp.escape(alias);
        if (RegExp('(^|[^a-z])$escaped([^a-z]|\$)').hasMatch(value)) {
          return true;
        }
      } else if (value.contains(alias)) {
        return true;
      }
    }
    return false;
  }

  static final RegExp _asciiWord = RegExp(r'^[a-z-]+$');

  static double? _parseNumberWords(
    String value,
    String language, {
    required bool allowSurroundingWords,
  }) {
    final lexicon = _lexicons[language];
    if (lexicon == null) return null;
    var prepared = value;
    for (final replacement in lexicon.phraseReplacements.entries) {
      prepared = prepared.replaceAll(replacement.key, replacement.value);
    }
    prepared = prepared.replaceAll('-', ' ');
    final rawTokens = prepared
        .replaceAll(RegExp(r"[^\p{L}'’]+", unicode: true), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (rawTokens.isEmpty) return null;

    final groups = <List<String>>[];
    var current = <String>[];
    var sawSurroundingWord = false;
    for (final raw in rawTokens) {
      final token = lexicon.normalizeToken(raw);
      final isNumberToken =
          lexicon.values.containsKey(token) ||
          lexicon.multipliers.containsKey(token) ||
          lexicon.decimalWords.contains(token);
      if (isNumberToken) {
        current.add(token);
        continue;
      }
      if (lexicon.ignoredWords.contains(token) && current.isNotEmpty) {
        current.add(token);
        continue;
      }
      if (current.isNotEmpty) {
        groups.add(current);
        current = <String>[];
      }
      if (token.isNotEmpty && !lexicon.ignoredWords.contains(token)) {
        sawSurroundingWord = true;
      }
    }
    if (current.isNotEmpty) groups.add(current);
    // More than one number-word run is ambiguous (for example, a spoken time
    // followed by a weight). Without an explicit unit, surrounding words can
    // turn a date or unrelated statement into a plausible-looking weight.
    if (groups.length != 1 || (!allowSurroundingWords && sawSurroundingWord)) {
      return null;
    }
    final tokens = groups.single;

    final decimalIndex = tokens.indexWhere(lexicon.decimalWords.contains);
    final wholeTokens = decimalIndex < 0
        ? tokens
        : tokens.take(decimalIndex).toList(growable: false);
    final whole = _parseAdditiveInteger(wholeTokens, lexicon);
    if (whole == null) return null;
    if (decimalIndex < 0) return whole.toDouble();

    final fraction = StringBuffer();
    for (final raw in tokens.skip(decimalIndex + 1)) {
      final token = lexicon.normalizeToken(raw);
      final digit = lexicon.values[token];
      if (digit == null || digit < 0 || digit > 9) continue;
      fraction.write(digit);
      if (fraction.length >= 2) break;
    }
    return fraction.isEmpty
        ? whole.toDouble()
        : double.parse('$whole.${fraction.toString()}');
  }

  static int? _parseAdditiveInteger(
    Iterable<String> tokens,
    _NumberLexicon lexicon,
  ) {
    var total = 0;
    var current = 0;
    var sawNumber = false;
    for (final raw in tokens) {
      final token = lexicon.normalizeToken(raw);
      if (token.isEmpty || lexicon.ignoredWords.contains(token)) continue;
      final multiplier = lexicon.multipliers[token];
      if (multiplier != null) {
        current = (current == 0 ? 1 : current) * multiplier;
        if (multiplier >= 1000) {
          total += current;
          current = 0;
        }
        sawNumber = true;
        continue;
      }
      final part = lexicon.values[token];
      if (part == null) continue;
      current += part;
      sawNumber = true;
    }
    return sawNumber ? total + current : null;
  }

  static double? _parseCjkNumber(
    String value, {
    required bool allowSurroundingWords,
  }) {
    const digits = <String, int>{
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '兩': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '영': 0,
      '공': 0,
      '일': 1,
      '이': 2,
      '삼': 3,
      '사': 4,
      '오': 5,
      '육': 6,
      '칠': 7,
      '팔': 8,
      '구': 9,
    };
    const multipliers = <String, int>{'十': 10, '百': 100, '십': 10, '백': 100};
    final matches = RegExp(
      r'[零〇一二两兩三四五六七八九十百영공일이삼사오육칠팔구십백点點점]+',
    ).allMatches(value).toList(growable: false);
    if (matches.length != 1) return null;
    final source = matches.single.group(0)!;
    if (!allowSurroundingWords) {
      final surrounding = value.replaceRange(
        matches.single.start,
        matches.single.end,
        '',
      );
      if (RegExp(r'\p{L}', unicode: true).hasMatch(surrounding)) return null;
    }
    final decimalIndex = source.indexOf(RegExp(r'[点點점]'));
    final wholeSource = decimalIndex < 0
        ? source
        : source.substring(0, decimalIndex);
    var total = 0;
    var current = 0;
    var saw = false;
    for (final rune in wholeSource.runes) {
      final token = String.fromCharCode(rune);
      final digit = digits[token];
      if (digit != null) {
        current = digit;
        saw = true;
        continue;
      }
      final multiplier = multipliers[token];
      if (multiplier != null) {
        total += (current == 0 ? 1 : current) * multiplier;
        current = 0;
        saw = true;
      }
    }
    if (!saw) return null;
    final whole = total + current;
    if (decimalIndex < 0) return whole.toDouble();
    final fraction = StringBuffer();
    for (final rune in source.substring(decimalIndex + 1).runes) {
      final digit = digits[String.fromCharCode(rune)];
      if (digit == null) continue;
      fraction.write(digit);
      if (fraction.length >= 2) break;
    }
    return fraction.isEmpty
        ? whole.toDouble()
        : double.parse('$whole.${fraction.toString()}');
  }

  static String _languageOf(String? localeTag) =>
      (localeTag ?? '').toLowerCase().split(RegExp('[-_]')).first;

  static String _normalize(String value) {
    const digitSets = <String>[
      '٠١٢٣٤٥٦٧٨٩',
      '۰۱۲۳۴۵۶۷۸۹',
      '०१२३४५६७८९',
      '০১২৩৪৫৬৭৮৯',
      '๐๑๒๓๔๕๖๗๘๙',
      '０１２３４５６７８９',
    ];
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      var replacement = character;
      for (final digits in digitSets) {
        final index = digits.indexOf(character);
        if (index >= 0) {
          replacement = index.toString();
          break;
        }
      }
      buffer.write(replacement);
    }
    return buffer
        .toString()
        .replaceAll('\u066B', '.')
        .replaceAll('\u066C', '')
        .replaceAll('．', '.')
        .replaceAll('，', ',')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
  }

  static const _lexicons = <String, _NumberLexicon>{
    ..._additionalSpokenWeightLexicons,
    'en': _NumberLexicon(
      values: {
        'zero': 0,
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
        'five': 5,
        'six': 6,
        'seven': 7,
        'eight': 8,
        'nine': 9,
        'ten': 10,
        'eleven': 11,
        'twelve': 12,
        'thirteen': 13,
        'fourteen': 14,
        'fifteen': 15,
        'sixteen': 16,
        'seventeen': 17,
        'eighteen': 18,
        'nineteen': 19,
        'twenty': 20,
        'thirty': 30,
        'forty': 40,
        'fifty': 50,
        'sixty': 60,
        'seventy': 70,
        'eighty': 80,
        'ninety': 90,
      },
      multipliers: {'hundred': 100, 'thousand': 1000},
      decimalWords: {'point', 'dot', 'decimal'},
      ignoredWords: {'and'},
    ),
    'ar': _NumberLexicon(
      values: {
        'صفر': 0,
        'واحد': 1,
        'واحدة': 1,
        'احد': 1,
        'اثنان': 2,
        'اثنين': 2,
        'اثنتان': 2,
        'اثنتين': 2,
        'اتنين': 2,
        'ثلاثة': 3,
        'ثلاث': 3,
        'اربعة': 4,
        'اربع': 4,
        'خمسة': 5,
        'خمس': 5,
        'ستة': 6,
        'ست': 6,
        'سبعة': 7,
        'سبع': 7,
        'ثمانية': 8,
        'ثمان': 8,
        'تمانية': 8,
        'تسعة': 9,
        'تسع': 9,
        'عشرة': 10,
        'عشر': 10,
        'عشرين': 20,
        'ثلاثين': 30,
        'اربعين': 40,
        'خمسين': 50,
        'ستين': 60,
        'سبعين': 70,
        'ثمانين': 80,
        'تمانين': 80,
        'تسعين': 90,
        'مئة': 100,
        'مائة': 100,
        'ميه': 100,
        'مئتان': 200,
        'مائتان': 200,
      },
      decimalWords: {'فاصلة', 'نقطة'},
      stripLeadingConjunction: true,
    ),
    'es': _NumberLexicon(
      values: {
        'cero': 0,
        'uno': 1,
        'una': 1,
        'dos': 2,
        'tres': 3,
        'cuatro': 4,
        'cinco': 5,
        'seis': 6,
        'siete': 7,
        'ocho': 8,
        'nueve': 9,
        'diez': 10,
        'veinte': 20,
        'treinta': 30,
        'cuarenta': 40,
        'cincuenta': 50,
        'sesenta': 60,
        'setenta': 70,
        'ochenta': 80,
        'noventa': 90,
        'cien': 100,
      },
      decimalWords: {'coma', 'punto'},
      ignoredWords: {'y'},
    ),
    'fr': _NumberLexicon(
      values: {
        'zero': 0,
        'zéro': 0,
        'un': 1,
        'une': 1,
        'deux': 2,
        'trois': 3,
        'quatre': 4,
        'cinq': 5,
        'six': 6,
        'sept': 7,
        'huit': 8,
        'neuf': 9,
        'dix': 10,
        'vingt': 20,
        'trente': 30,
        'quarante': 40,
        'cinquante': 50,
        'soixante': 60,
        'quatrevingts': 80,
        'quatrevingt': 80,
        'cent': 100,
      },
      decimalWords: {'virgule', 'point'},
      ignoredWords: {'et'},
      phraseReplacements: {
        'quatre-vingts': 'quatrevingts',
        'quatre-vingt': 'quatrevingt',
        'quatre vingts': 'quatrevingts',
        'quatre vingt': 'quatrevingt',
      },
    ),
    'tr': _NumberLexicon(
      values: {
        'sıfır': 0,
        'bir': 1,
        'iki': 2,
        'üç': 3,
        'dört': 4,
        'beş': 5,
        'altı': 6,
        'yedi': 7,
        'sekiz': 8,
        'dokuz': 9,
        'on': 10,
        'yirmi': 20,
        'otuz': 30,
        'kırk': 40,
        'elli': 50,
        'altmış': 60,
        'yetmiş': 70,
        'seksen': 80,
        'doksan': 90,
        'yüz': 100,
      },
      decimalWords: {'virgül', 'nokta'},
    ),
    'pt': _NumberLexicon(
      values: {
        'zero': 0,
        'um': 1,
        'uma': 1,
        'dois': 2,
        'duas': 2,
        'três': 3,
        'quatro': 4,
        'cinco': 5,
        'seis': 6,
        'sete': 7,
        'oito': 8,
        'nove': 9,
        'dez': 10,
        'vinte': 20,
        'trinta': 30,
        'quarenta': 40,
        'cinquenta': 50,
        'sessenta': 60,
        'setenta': 70,
        'oitenta': 80,
        'noventa': 90,
        'cem': 100,
      },
      decimalWords: {'vírgula', 'virgula', 'ponto'},
      ignoredWords: {'e'},
    ),
    'fa': _NumberLexicon(
      values: {
        'صفر': 0,
        'یک': 1,
        'دو': 2,
        'سه': 3,
        'چهار': 4,
        'پنج': 5,
        'شش': 6,
        'هفت': 7,
        'هشت': 8,
        'نه': 9,
        'ده': 10,
        'بیست': 20,
        'سی': 30,
        'چهل': 40,
        'پنجاه': 50,
        'شصت': 60,
        'هفتاد': 70,
        'هشتاد': 80,
        'نود': 90,
        'صد': 100,
      },
      decimalWords: {'ممیز'},
      ignoredWords: {'و'},
    ),
    'id': _NumberLexicon(
      values: {
        'nol': 0,
        'satu': 1,
        'dua': 2,
        'tiga': 3,
        'empat': 4,
        'lima': 5,
        'enam': 6,
        'tujuh': 7,
        'delapan': 8,
        'sembilan': 9,
        'sepuluh': 10,
        'dua puluh': 20,
        'tiga puluh': 30,
      },
      multipliers: {'puluh': 10, 'ratus': 100},
      decimalWords: {'koma', 'titik'},
    ),
    'ms': _NumberLexicon(
      values: {
        'kosong': 0,
        'sifar': 0,
        'satu': 1,
        'dua': 2,
        'tiga': 3,
        'empat': 4,
        'lima': 5,
        'enam': 6,
        'tujuh': 7,
        'lapan': 8,
        'sembilan': 9,
        'sepuluh': 10,
      },
      multipliers: {'puluh': 10, 'ratus': 100},
      decimalWords: {'perpuluhan', 'koma', 'titik'},
    ),
  };
}
