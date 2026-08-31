import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _profileSource() {
  return <String>[
    'lib/features/profile/profile_settings_page.dart',
    'lib/features/profile/profile_settings_actions.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

void main() {
  test(
    'profile supports exercise frequency type and named nutrition style',
    () {
      final source = _profileSource();

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
    final source = _profileSource();

    expect(source, contains("context.go('/settings')"));
    expect(source, contains('Save and return to settings'));
  });
}
