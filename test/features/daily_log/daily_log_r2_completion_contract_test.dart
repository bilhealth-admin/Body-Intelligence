import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R2 diary exposes serving choices, notes, and persisted exercise', () {
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final inputSections = File(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

    expect(mealEntry, contains("Key('daily-log-serving-choices')"));
    expect(mealEntry, contains('selectedFood!.servingSize * multiplier'));
    expect(mealEntry, contains('quantity.text = serving.toStringAsFixed'));
    expect(inputSections, contains("Key('daily-log-note-field')"));
    expect(inputSections, contains("Key('daily-log-exercise-section')"));
    expect(actions, contains('exerciseNotes: exerciseNotes.text.trim()'));
    expect(
      actions.indexOf('final quantityValue = _parsePositiveQuantity'),
      lessThan(
        actions.indexOf('final mealId = await mealRepository.createMeal'),
      ),
    );
  });
}
