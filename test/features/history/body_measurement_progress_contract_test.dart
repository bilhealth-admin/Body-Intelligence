import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress consumes durable six-measurement history in five locales', () {
    final progress = [
      'lib/features/history/progress_page.dart',
      'lib/features/history/progress_page_components.dart',
      'lib/features/history/progress_page_copy.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final profile = File(
      'lib/features/profile/profile_settings_page.dart',
    ).readAsStringSync();
    final database = File(
      'lib/data/database/app_database.dart',
    ).readAsStringSync();
    for (final metric in const [
      'neck',
      'waist',
      'hips',
      'chest',
      'arm',
      'thigh',
    ]) {
      expect(progress, contains("ProgressMetric.$metric"));
      expect(progress, contains("'$metric':"));
    }
    expect(progress, contains('bodyMeasurementHistoryProvider'));
    expect(profile, contains('bodyMeasurementRepositoryProvider'));
    expect(profile, contains('.saveForDay('));
    expect(database, contains('int get schemaVersion => 21'));
    expect(database, contains('migrator.createTable(bodyMeasurementEntries)'));
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(progress, contains("'$locale':"));
    }
  });
}
