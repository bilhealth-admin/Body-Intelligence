import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R2 diary keeps food detail focused and persists exercise', () {
    final mealEntry = [
      'lib/features/daily_log/daily_log_meal_entry.dart',
      'lib/features/daily_log/daily_log_meal_search.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final inputSections = File(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    ).readAsStringSync();
    final actions = [
      'lib/features/daily_log/daily_log_page_actions.dart',
      'lib/features/daily_log/daily_log_mutation_actions.dart',
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(mealEntry, contains("Key('daily-log-meal-type-field')"));
    expect(mealEntry, isNot(contains("Key('daily-log-serving-choices')")));
    expect(
      mealEntry,
      isNot(contains('selectedFood!.servingSize * multiplier')),
    );
    expect(mealEntry, contains('quantity.text = amount.toStringAsFixed'));
    expect(inputSections, contains("Key('daily-log-note-field')"));
    expect(inputSections, contains("Key('daily-log-exercise-section')"));
    expect(actions, contains('exerciseNotes: exerciseNotes.text.trim()'));
    expect(
      actions.indexOf('final quantityValue = _parsePositiveQuantity'),
      lessThan(actions.indexOf('addReviewedMealItemsAtomically')),
    );
  });
}
