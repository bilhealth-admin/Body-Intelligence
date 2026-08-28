import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily search uses correction and complete nutrition cards', () {
    final daily = [
      'lib/features/daily_log/daily_log_page.dart',
      'lib/features/daily_log/daily_log_meal_entry.dart',
      'lib/features/daily_log/daily_log_meal_entry_components.dart',
      'lib/features/daily_log/daily_log_meal_search.dart',
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      'lib/app/localization/app_localizations_arabic_runtime.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(daily, contains('FoodSearchAssistance'));
    expect(daily, contains('هل تقصد'));
    for (final label in const [
      'Sodium',
      'Potassium',
      'Fiber',
      'Magnesium',
      'Calcium',
      'Sugar',
      'الصوديوم',
      'البوتاسيوم',
      'الألياف',
      'المغنيسيوم',
      'الكالسيوم',
      'السكر',
    ]) {
      expect(daily, contains(label), reason: 'Missing nutrition label: $label');
    }
  });
}
