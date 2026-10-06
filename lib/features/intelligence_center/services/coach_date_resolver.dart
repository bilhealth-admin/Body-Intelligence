class CoachDateResolver {
  const CoachDateResolver();

  DateTime? resolve(String input, {required DateTime referenceLocal}) {
    final value = _normalize(input);
    final explicit = _absoluteDates(value);
    if (explicit.isNotEmpty) {
      if (explicit.any((date) => date == null)) return null;
      final days = explicit.toSet();
      return days.length == 1 ? days.single : null;
    }
    final local = referenceLocal.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    if (_contains(value, const ['yesterday', 'أمس', 'امس', 'مبارح'])) {
      return DateTime(today.year, today.month, today.day - 1);
    }
    if (_contains(value, const ['week ago', 'قبل أسبوع', 'قبل اسبوع'])) {
      return DateTime(today.year, today.month, today.day - 7);
    }
    if (_contains(value, const ['today', 'اليوم', 'النهارده', 'النهاردة'])) {
      return today;
    }
    const weekdays = <int, List<String>>{
      DateTime.monday: ['last monday', 'الاثنين الماضي', 'الاتنين اللي فات'],
      DateTime.tuesday: ['last tuesday', 'الثلاثاء الماضي', 'التلات اللي فات'],
      DateTime.wednesday: [
        'last wednesday',
        'الأربعاء الماضي',
        'الاربع اللي فات',
      ],
      DateTime.thursday: ['last thursday', 'الخميس الماضي', 'الخميس اللي فات'],
      DateTime.friday: ['last friday', 'الجمعة الماضية', 'الجمعه اللي فاتت'],
      DateTime.saturday: ['last saturday', 'السبت الماضي', 'السبت اللي فات'],
      DateTime.sunday: [
        'last sunday',
        'الأحد الماضي',
        'الاحد الماضي',
        'الأحد اللي فات',
        'الاحد اللي فات',
        'يوم الحد',
        'عالأحد',
        'يوم الأحد',
      ],
    };
    for (final entry in weekdays.entries) {
      if (!_contains(value, entry.value)) continue;
      var daysBack = (today.weekday - entry.key) % 7;
      if (daysBack == 0) daysBack = 7;
      return DateTime(today.year, today.month, today.day - daysBack);
    }
    return null;
  }

  /// Invalid explicit dates remain explicit. Callers must not silently replace
  /// one with today's date when preparing a write.
  bool hasExplicitDate(String input) =>
      _absoluteDates(_normalize(input)).isNotEmpty;

  /// Date components cannot be mistaken for a food/body/water quantity.
  String withoutExplicitDates(String input) =>
      _normalize(input).replaceAll(_isoDate, ' ').replaceAll(_namedDate, ' ');

  static final _isoDate = RegExp(
    r'(?<!\d)(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?!\d)',
  );
  static const _months = <String, int>{
    'january': 1,
    'jan': 1,
    'يناير': 1,
    'february': 2,
    'feb': 2,
    'فبراير': 2,
    'march': 3,
    'mar': 3,
    'مارس': 3,
    'april': 4,
    'apr': 4,
    'ابريل': 4,
    'may': 5,
    'مايو': 5,
    'june': 6,
    'jun': 6,
    'يونيو': 6,
    'july': 7,
    'jul': 7,
    'يوليو': 7,
    'august': 8,
    'aug': 8,
    'اغسطس': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'سبتمبر': 9,
    'october': 10,
    'oct': 10,
    'اكتوبر': 10,
    'november': 11,
    'nov': 11,
    'نوفمبر': 11,
    'december': 12,
    'dec': 12,
    'ديسمبر': 12,
  };
  static final _namedDate = RegExp(
    '(?<![\\p{L}\\p{N}])(\\d{1,2})\\s*'
    '(${_months.keys.join('|')})\\s*,?\\s*(\\d{4})(?!\\d)',
    unicode: true,
  );

  List<DateTime?> _absoluteDates(String input) => [
    for (final match in _isoDate.allMatches(input))
      _calendarDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      ),
    for (final match in _namedDate.allMatches(input))
      _calendarDate(
        int.parse(match[3]!),
        _months[match[2]!]!,
        int.parse(match[1]!),
      ),
  ];

  DateTime? _calendarDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  String _normalize(String input) {
    var value = input.trim().toLowerCase();
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    for (var digit = 0; digit < 10; digit++) {
      value = value
          .replaceAll(arabic[digit], '$digit')
          .replaceAll(eastern[digit], '$digit');
    }
    return value
        .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا');
  }

  bool _contains(String value, List<String> variants) =>
      variants.any((variant) => value.contains(_normalize(variant)));
}
