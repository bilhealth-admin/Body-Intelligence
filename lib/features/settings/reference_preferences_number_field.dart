part of 'reference_preferences_pages.dart';

/// Shared numeric goal field and its existing input-unit validation contract.
class _StoredNumber extends ConsumerStatefulWidget {
  const _StoredNumber(this.keyName, this.label, this.defaultValue, this.suffix);
  final String keyName;
  final String label;
  final String? defaultValue;
  final String suffix;
  @override
  ConsumerState<_StoredNumber> createState() => _StoredNumberState();
}

@visibleForTesting
bool validStoredNutritionGoal(String key, String suffix, String input) {
  final expectedUnit = NutritionGoalSnapshot.units[key];
  if (expectedUnit == null ||
      (key == 'goal.calories'
          ? suffix != '' && suffix != 'kcal'
          : key.endsWith('Percent')
          ? suffix != '%'
          : suffix != expectedUnit)) {
    return false;
  }
  final number = NutritionGoalSnapshot.parse(input);
  if (number == null || !number.isFinite || number < 0) return false;
  return validDashboardNutrientGoal(key, number);
}
