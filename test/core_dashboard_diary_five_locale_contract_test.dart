import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard profile and camera flows have five-locale copy', () {
    final source = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale': {"), reason: locale);
    }
    expect(source, isNot(contains('widget.arabic ?')));
    expect(source, contains("_dashboardText(widget.locale, 'cameraFailed')"));
  });

  test('Today AI coach entry has authored copy for five locales', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_header.dart',
    ).readAsStringSync();
    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale': {"), reason: locale);
    }
    expect(source, isNot(contains('final bool arabic')));
    expect(source, isNot(contains('arabic ?')));
  });

  test('daily log visible actions use five-locale lookup', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

    for (final key in const [
      'Copy yesterday’s meals?',
      'Edit quantity',
      'Submit for review',
      'Image analysis unavailable',
      'Review image suggestions',
    ]) {
      expect(page, contains("'$key': {"), reason: key);
    }
    expect(actions, isNot(contains('_arabic ?')));
    expect(actions, isNot(contains('arabic ?')));
    expect(
      actions,
      contains('requestedLocale: Localizations.localeOf(context).languageCode'),
    );
  });

  test('diary input summary and meal widgets own five-locale contracts', () {
    final input = File(
      'lib/features/daily_log/presentation/daily_log_input_sections.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/daily_log/presentation/daily_log_summary_widgets.dart',
    ).readAsStringSync();
    final meals = File(
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
    ).readAsStringSync();

    expect(input, contains("'Browse workouts': {"));
    expect(input, isNot(contains('=> arabic ? ar : en')));
    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(summary, contains("'$locale': {"), reason: locale);
      expect(meals, contains("'$locale': {"), reason: locale);
    }
    expect(summary, isNot(contains('arabic ?')));
    expect(meals, isNot(contains('arabic ?')));
  });

  test('reference dashboard primary copy resolves beyond ar and en', () {
    final phone = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final components = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
    ).readAsStringSync();

    expect(phone, isNot(contains('=> arabic ? ar : en')));
    expect(phone, isNot(contains('arabic ?')));
    expect(phone, contains("'Calories': {"));
    expect(phone, contains("'Body Twin': {"));
    expect(components, contains("_referenceText('left', 'متبقية')"));
  });
}
