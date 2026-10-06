part of 'local_coach_command_parser.dart';

extension _LocalCoachCommandQuantity on LocalCoachCommandParser {
  static const _numberLiteral = r'[-+]?(?:\d{1,5}(?:\.\d{1,3})?|\.\d{1,3})';
  static const _kilogramUnits =
      r'kg|kgs|kilograms?|kilos?|كغ|كجم|كيلو|كيلوغرام|كيلوجرام';
  static const _poundUnits = r'lbs?|pounds?|رطل|ارطال|باوند|باوندات';
  static const _milliliterUnits = r'ml|millilit(?:er|re)s?|مل|مليلتر|ملليلتر';
  static const _literUnits = r'l|lit(?:er|re)s?|لتر|ليتر';

  /// Only grammar around the quantity is removed. An unknown unit, second
  /// number, food name, question or correction word remains unresolved.
  String? _quantityText(String value, List<String> statementWords) {
    if (value.contains('?') || value.contains('؟')) return null;
    var text = dateResolver.withoutExplicitDates(value);
    // A comma followed by three digits is locale-ambiguous. Do not turn a
    // possible thousands separator into a silently much smaller decimal.
    if (RegExp(r'\d,\d{3}(?!\d)').hasMatch(text)) return null;
    text = text.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '.');
    text = _eraseQuantityWords(text, [
      ...statementWords,
      ..._commandDateWords,
      'on',
      'at',
      'now',
      'بتاريخ',
      'في',
      'الان',
    ]);
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:;!،؛]+|[\s:;!،؛]+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .trim();
  }

  String _eraseQuantityWords(String value, Iterable<String> words) {
    final markers = words.map(_normalizeForMatching).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return value.replaceAll(
      RegExp(
        '(?<![\\p{L}])(?:${markers.map(RegExp.escape).join('|')})(?![\\p{L}])',
        unicode: true,
      ),
      ' ',
    );
  }

  static const _commandDateWords = [
    'today',
    'yesterday',
    'week ago',
    'اليوم',
    'النهارده',
    'النهاردة',
    'امس',
    'مبارح',
    'قبل اسبوع',
    'last monday',
    'الاثنين الماضي',
    'الاتنين اللي فات',
    'last tuesday',
    'الثلاثاء الماضي',
    'التلات اللي فات',
    'last wednesday',
    'الاربعاء الماضي',
    'الاربع اللي فات',
    'last thursday',
    'الخميس الماضي',
    'الخميس اللي فات',
    'last friday',
    'الجمعة الماضية',
    'الجمعه اللي فاتت',
    'last saturday',
    'السبت الماضي',
    'السبت اللي فات',
    'last sunday',
    'الاحد الماضي',
    'الاحد اللي فات',
    'يوم الحد',
    'عالاحد',
    'يوم الاحد',
    'حق يوم الاحد',
  ];

  bool _hasAmbiguousQuantityDate(String value, DateTime referenceLocal) {
    if (dateResolver.hasExplicitDate(value)) {
      return dateResolver.resolve(value, referenceLocal: referenceLocal) ==
          null;
    }
    final days = <DateTime>{
      for (final phrase in _commandDateWords)
        if (_containsWholeToken(value, [phrase]))
          if (dateResolver.resolve(phrase, referenceLocal: referenceLocal)
              case final DateTime day)
            day,
    };
    return days.length > 1;
  }

  bool _hasQuantityUnit(String value, String units) => RegExp(
    '(?:^|[^\\p{L}])(?:$units)(?:\$|[^\\p{L}])',
    unicode: true,
  ).hasMatch(value);

  bool _isBodyWeightStatement(String value) {
    // The word "weight" and the unit kg also describe food and lifting.
    // An ambiguous mixed request goes through review instead of writing the
    // first number into the body-weight log.
    if (_contains(value, const [
      'chicken',
      'rice',
      'food',
      'meal',
      'i ate',
      'weight of',
      'deadlift',
      'squat',
      'bench press',
      'workout',
      'دجاج',
      'لحم',
      'سمك',
      'طعام',
      'وجبة',
      'وجبه',
      'اكلت',
      'وزنها',
      'رفعت',
      'تمرين',
    ])) {
      return false;
    }
    if (_hasQuantityUnit(value, 'g|grams?|غ|غرام|جرام|جم')) return false;
    return _contains(value, const [
          'my weight',
          'body weight',
          'i weigh',
          'log weight',
          'record weight',
          'وزني',
          'وزنى',
          'سجل الوزن',
          'اضف الوزن',
          'وزن الجسم',
          'اوزان',
          'poids',
          'peso',
          'ağırlık',
          'kilom',
        ]) ||
        RegExp(
          r'(?:^|[^\p{L}])(?:weight|الوزن|وزن)\s*(?:is\s*)?[:=]?\s*[-+]?\d',
          unicode: true,
        ).hasMatch(value);
  }

  double? _bodyWeightKilograms(String value) {
    final text = _quantityText(value, const [
      'my',
      'body',
      'weight',
      'i',
      'weigh',
      'weighed',
      'log',
      'record',
      'add',
      'set',
      'change',
      'update',
      'new',
      'target',
      'goal',
      'to',
      'is',
      'وزني',
      'وزنى',
      'وزن',
      'الوزن',
      'الجسم',
      'سجل',
      'دخللي',
      'دخل لي',
      'حط',
      'اكتب',
      'دير',
      'اضف',
      'اجعل',
      'غير',
      'تغيير',
      'الهدف',
      'هدفي',
      'المستهدف',
      'الجديد',
      'الى',
      'اوزان',
      'poids',
      'mon',
      'modifier',
      'objectif',
      'peso',
      'mi',
      'cambiar',
      'objetivo',
      'ağırlık',
      'kilom',
      'hedefimi',
      'değiştir',
    ]);
    if (text == null) return null;
    final match = RegExp(
      '^($_numberLiteral)\\s*($_kilogramUnits|$_poundUnits)?\$',
      unicode: true,
    ).firstMatch(text);
    if (match == null) return null;
    final amount = double.tryParse(match[1]!);
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    final isPounds =
        match[2] != null &&
        RegExp('^(?:$_poundUnits)\$', unicode: true).hasMatch(match[2]!);
    return isPounds ? amount * 0.45359237 : amount;
  }

  int? _waterMilliliters(String value) {
    final text = _quantityText(value, const [
      'water',
      'eau',
      'agua',
      'su',
      'ماء',
      'الماء',
      'مياه',
      'المياه',
      'مويه',
      'المويه',
      'موية',
      'الموية',
      'ميه',
      'الميه',
      'log',
      'add',
      'record',
      'save',
      'i',
      'drank',
      'of',
      'a',
      'سجل',
      'اضف',
      'احفظ',
      'شربت',
      'من',
      'enregistrer',
      'ajouter',
      'boire',
      'bu',
      'registrar',
      'agregar',
      'bebi',
      'bebí',
      'de',
      'kaydet',
      'ekle',
      'içtim',
    ]);
    if (text == null) return null;
    final scalar = RegExp(
      '^($_numberLiteral)\\s*($_milliliterUnits|$_literUnits)?\$',
      unicode: true,
    ).firstMatch(text);
    double? milliliters;
    if (scalar != null) {
      final amount = double.tryParse(scalar[1]!);
      if (amount == null || !amount.isFinite || amount <= 0) return null;
      final isLiters =
          scalar[2] != null &&
          RegExp('^(?:$_literUnits)\$', unicode: true).hasMatch(scalar[2]!);
      milliliters = isLiters ? amount * 1000 : amount;
    } else if (RegExp(
      '^(?:half|نصف|نص)\\s+(?:$_literUnits)\$',
      unicode: true,
    ).hasMatch(text)) {
      milliliters = 500;
    } else if (RegExp(
      '^(?:quarter|ربع)\\s+(?:$_literUnits)\$',
      unicode: true,
    ).hasMatch(text)) {
      milliliters = 250;
    } else if (RegExp(r'^(?:لترين|لتران|ليترين|ليتران)$').hasMatch(text)) {
      milliliters = 2000;
    } else if (RegExp(
      '^(?:$_literUnits)\\s+(?:and|و)\\s*(?:half|نصف|نص)\$',
      unicode: true,
    ).hasMatch(text)) {
      milliliters = 1500;
    } else if (RegExp('^(?:$_literUnits)\$', unicode: true).hasMatch(text)) {
      milliliters = 1000;
    }
    if (milliliters == null ||
        !milliliters.isFinite ||
        milliliters != milliliters.roundToDouble() ||
        milliliters < 1 ||
        milliliters > 5000) {
      return null;
    }
    return milliliters.toInt();
  }
}
