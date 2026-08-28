import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference settings are persisted and routed', () {
    final pages = [
      'lib/features/settings/reference_preferences_pages.dart',
      'lib/features/settings/reference_preferences_controls.dart',
      'lib/features/settings/reference_preferences_numeric.dart',
      'lib/features/settings/reference_preferences_macros.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final settings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();
    final sharingPrivacy = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();

    for (final route in const [
      '/settings/diary',
      '/settings/email',
      '/settings/units',
      '/settings/appearance',
      '/settings/nutrition-goals',
    ]) {
      expect(router, contains(route), reason: route);
    }
    for (final key in const [
      'diary.showAllMeals',
      'diary.defaultSearchTab',
      'diary.sharing',
      'units.weight',
      'units.height',
      'units.distance',
      'units.energy',
      'units.water',
      'goal.calories',
      'goal.proteinPercent',
      'goal.sodium',
      'goal.fiber',
    ]) {
      expect(pages, contains(key), reason: key);
    }
    expect(pages, contains('preferencesRepositoryProvider'));
    expect(
      pages,
      contains('Email delivery is not configured yet.'),
      reason: 'email controls must not imply an inactive server delivery path',
    );
    expect(pages, isNot(contains("'email.weeklyDigest'")));
    expect(pages, isNot(contains("'email.friendRequest'")));
    expect(settings, contains("'/settings/diary'"));
    expect(settings, contains("'/settings/appearance'"));
    expect(settings, contains("'/settings/sharing-privacy'"));
    expect(settings, contains("'/settings/nutrition-goals'"));
    expect(sharingPrivacy, contains("context.push('/settings/diary/sharing')"));
    expect(sharingPrivacy, contains("context.push('/settings/email')"));
    expect(sharingPrivacy, contains("context.push('/community/profile')"));
    expect(sharingPrivacy, contains("context.push('/community/connections')"));
    expect(sharingPrivacy, isNot(contains('_UnavailableCloudPrivacyTile')));
    expect(sharingPrivacy, isNot(contains("'privacy.profile'")));
    expect(sharingPrivacy, isNot(contains("'privacy.search'")));
    expect(sharingPrivacy, isNot(contains("'privacy.community'")));
  });
}
