part of 'local_coach_command_parser.dart';

extension _LocalCoachCommandQuantity on LocalCoachCommandParser {
  List<RegExpMatch> _quantityNumbers(String value) {
    final quantityText = dateResolver
        .withoutExplicitDates(value)
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .replaceAll(',', '.');
    return RegExp(
      r'(?<![\d.])[-+]?\d{1,5}(?:\.\d{1,3})?(?![\d.])',
    ).allMatches(quantityText).toList(growable: false);
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
    final number = _firstNumber(value);
    if (number == null) return null;
    return _hasQuantityUnit(value, 'lbs?|pounds?|رطل|ارطال')
        ? number * 0.45359237
        : number;
  }

  int? _waterMilliliters(String value) {
    final numbers = _quantityNumbers(value);
    final amount =
        numbers.isEmpty &&
            _containsWholeToken(value, const ['half', 'نصف', 'نص'])
        ? 0.5
        : _firstNumber(value);
    if (amount == null || amount <= 0) return null;
    final hasMl = _hasQuantityUnit(value, 'ml|millilit(?:er|re)s?|مل');
    final hasLiters = _hasQuantityUnit(value, 'l|lit(?:er|re)s?|لتر|ليتر');
    if (hasMl && hasLiters) return null;
    if (!hasMl &&
        !hasLiters &&
        _hasQuantityUnit(
          value,
          'cups?|glasses?|bottles?|ounces?|oz|g|grams?|كوب|كاسات|كاس|اكواب|زجاجة|غ|غرام|جرام',
        )) {
      return null;
    }
    final ml = hasLiters ? amount * 1000 : amount;
    // Do not silently round an unknown serving into a fictitious ml count.
    if (!ml.isFinite || ml != ml.roundToDouble() || ml < 1 || ml > 5000) {
      return null;
    }
    return ml.toInt();
  }
}
