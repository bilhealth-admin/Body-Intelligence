import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile supports exercise frequency type and named nutrition style',
    () {
      final source = File(
        'lib/features/profile/profile_settings_page.dart',
      ).readAsStringSync();

      expect(source, contains('weeklyExerciseSessions'));
      expect(source, contains('exerciseType'));
      expect(source, contains('dietApproach'));
      expect(source, contains("'keto'"));
      expect(source, contains("'mediterranean'"));
      expect(source, contains("'walking'"));
      expect(source, contains("'strength'"));
    },
  );

  test('saving profile returns to settings', () {
    final source = File(
      'lib/features/profile/profile_settings_page.dart',
    ).readAsStringSync();

    expect(source, contains("context.go('/settings')"));
    expect(source, contains('Save and return to settings'));
  });
}
