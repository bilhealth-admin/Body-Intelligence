import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Log renders meal entry, water, then structured body context', () {
    final source = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();

    final meal = source.indexOf('key: mealEntryKey');
    final search = source.indexOf('SearchAnchor(', meal);
    final meals = source.indexOf('meals.when(', search);
    final water = source.indexOf('_waterSection(waterEntries)', meals);
    final bodyContext = source.indexOf('_bodyContextSection()', water);

    expect(meal, greaterThan(0));
    expect(search, greaterThan(meal));
    expect(meals, greaterThan(search));
    expect(water, greaterThan(meals));
    expect(bodyContext, greaterThan(water));
    expect(source, isNot(contains('Anything that may explain today')));
    expect(source, isNot(contains('lines: 4')));
  });
}
