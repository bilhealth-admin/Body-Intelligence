import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile route uses the advanced premium profile experience', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final source = [
      'lib/features/profile/premium_profile_page.dart',
      'lib/features/profile/premium_profile_components.dart',
      'lib/features/profile/premium_profile_actions.dart',
      'lib/features/profile/premium_profile_editors.dart',
      'lib/features/profile/dietary_system_labels.dart',
      'lib/features/profile/goal_timeline_card.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(
      router,
      contains("import '../../features/profile/premium_profile_page.dart'"),
    );
    expect(router, contains('const PremiumProfilePage()'));
    expect(source, contains("Key('premium-profile-list')"));
    expect(source, contains("Key('profile-settings-save')"));
    expect(source, contains('profilePhotoProvider'));
    expect(source, contains('userProfileRepositoryProvider'));
    expect(source, contains('goalRepositoryProvider'));
    expect(source, contains("context.push('/plan?origin=profile')"));
    expect(source, contains("Key('advanced-body-measurements-action')"));
    expect(source, contains("context.push('/advanced-body-measurements')"));
    expect(router, contains("path: '/advanced-body-measurements'"));
    for (final row in const [
      'profile-display-name-row',
      'profile-photo-row',
      'profile-height-row',
      'profile-sex-row',
      'profile-date-of-birth-row',
      'profile-location-row',
      'profile-timezone-row',
      'profile-email-row',
      'profile-units-row',
      'profile-goals-row',
      'profile-dietary-system-row',
    ]) {
      expect(source, contains("Key('$row')"));
    }
    expect(source, contains("context.push(route)"));
    expect(source, contains("'/settings/account-email'"));
    expect(source, contains("'/settings/units'"));
    expect(source, contains("'/location-settings'"));
    expect(source, contains("'/goals'"));
    expect(source, contains("Key('profile-height-editor')"));
    expect(source, contains("repo.get('profileDateOfBirth')"));
    expect(source, contains('setManyInCurrentTransaction({'));
    expect(source, contains("'profileDateOfBirth':"));
  });

  test('advanced profile exposes identity body location units and goals', () {
    final source = [
      'lib/features/profile/premium_profile_page.dart',
      'lib/features/profile/premium_profile_components.dart',
      'lib/features/profile/premium_profile_actions.dart',
      'lib/features/profile/premium_profile_editors.dart',
      'lib/features/profile/dietary_system_labels.dart',
      'lib/features/profile/goal_timeline_card.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    for (final contract in <String>[
      'Personal details',
      'Profile photo',
      'Date of birth',
      'Body details',
      'Location & preferences',
      'Time zone',
      'Health goals',
      'Current weight',
      'Goal weight',
      'Activity level',
      'Calories & macro plan',
      'Dietary system',
      'Estimated time to goal',
    ]) {
      expect(
        source,
        contains(contract),
        reason: 'Missing profile contract: $contract',
      );
    }
  });
}
