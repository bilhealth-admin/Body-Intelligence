part of 'reference_goals_page.dart';

@visibleForTesting
({String? weeklyGoal, double? startingWeight, String? startingDate})
validateStoredGoalPreferences({
  required String? weeklyGoal,
  required String? startingWeight,
  required String? startingDate,
  required DateTime now,
}) {
  final parsedWeight = double.tryParse(startingWeight ?? '');
  final dateMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(startingDate ?? '');
  final year = int.tryParse(dateMatch?.group(1) ?? '');
  final month = int.tryParse(dateMatch?.group(2) ?? '');
  final day = int.tryParse(dateMatch?.group(3) ?? '');
  final parsedDate = year == null || month == null || day == null
      ? null
      : DateTime(year, month, day);
  final canonicalDate =
      parsedDate != null &&
      parsedDate.year == year &&
      parsedDate.month == month &&
      parsedDate.day == day;
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final validDate = canonicalDate && !parsedDate.isAfter(endOfToday)
      ? '${parsedDate.year.toString().padLeft(4, '0')}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}'
      : null;
  return (
    weeklyGoal: _weeklyOptions.contains(weeklyGoal) ? weeklyGoal : null,
    startingWeight:
        parsedWeight != null &&
            parsedWeight.isFinite &&
            parsedWeight >= 20 &&
            parsedWeight <= 500
        ? parsedWeight
        : null,
    startingDate: validDate,
  );
}
