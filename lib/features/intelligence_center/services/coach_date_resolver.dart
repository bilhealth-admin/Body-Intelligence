class CoachDateResolver {
  const CoachDateResolver();

  DateTime? resolve(String input, {required DateTime referenceLocal}) {
    final value = input.trim().toLowerCase();
    final today = DateTime(
      referenceLocal.year,
      referenceLocal.month,
      referenceLocal.day,
    );
    if (_contains(value, const ['yesterday', 'أمس', 'امس', 'مبارح'])) {
      return today.subtract(const Duration(days: 1));
    }
    if (_contains(value, const ['week ago', 'قبل أسبوع', 'قبل اسبوع'])) {
      return today.subtract(const Duration(days: 7));
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
      return today.subtract(Duration(days: daysBack));
    }
    return null;
  }

  bool _contains(String value, List<String> variants) =>
      variants.any(value.contains);
}
