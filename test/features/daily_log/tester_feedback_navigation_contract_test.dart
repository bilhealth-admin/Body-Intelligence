import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diary permits future planning and keeps both date directions', () {
    final source = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();

    expect(source, contains('today.year + 1'));
    expect(source, contains('date.subtract('));
    expect(source, contains('date.add('));
    expect(source, contains('lastDate: latestPlannableDate'));
  });

  test(
    'meal logging opens a focused meal page without duplicate capture UI',
    () {
      final page = File(
        'lib/features/daily_log/daily_log_page.dart',
      ).readAsStringSync();
      final entry = File(
        'lib/features/daily_log/daily_log_meal_entry.dart',
      ).readAsStringSync();

      expect(page, contains("Key('daily-log-focused-meal-page')"));
      expect(page, contains("Key('daily-meal-detail-title')"));
      expect(entry, contains('SearchAnchor('));
      expect(entry, isNot(contains("Key('daily-search-barcode')")));
      expect(entry, isNot(contains("Key('daily-search-voice')")));
      expect(entry, isNot(contains("Key('daily-search-meal-selector')")));
    },
  );

  test('dashboard Android back exits instead of revealing auth history', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('canPop: !isDashboard'));
    expect(shell, contains('defaultTargetPlatform == TargetPlatform.android'));
    expect(shell, contains('SystemNavigator.pop()'));
  });

  test('weight context uses one selected icon and local condition labels', () {
    final checkIn = File(
      'lib/features/daily_check_in/daily_check_in_page.dart',
    ).readAsStringSync();

    expect(
      checkIn,
      contains("('morning', 'Morning', Icons.wb_sunny_outlined)"),
    );
    expect(checkIn, contains("'After eating',"));
    expect(checkIn, contains('Icons.restaurant_outlined'));
    expect(checkIn, contains("'Different time',"));
    expect(checkIn, contains('Icons.schedule_rounded'));
    expect(checkIn, contains('showCheckmark: false'));
  });
}
