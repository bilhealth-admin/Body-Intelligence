import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile route uses the advanced premium profile experience', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final source = File(
      'lib/features/profile/premium_profile_page.dart',
    ).readAsStringSync();

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
    expect(source, contains("context.push('/plan')"));
    expect(source, contains("Key('advanced-body-measurements-action')"));
    expect(source, contains("context.push('/advanced-body-measurements')"));
    expect(router, contains("path: '/advanced-body-measurements'"));
  });

  test('advanced profile exposes identity body location units and goals', () {
    final source = File(
      'lib/features/profile/premium_profile_page.dart',
    ).readAsStringSync();

    for (final contract in <String>[
      'Personal identity',
      'Profile photo',
      'Body details',
      'Location & preferences',
      'Time zone',
      'Health goals',
      'Current weight',
      'Goal weight',
      'Activity level',
      'Calories & macro plan',
    ]) {
      expect(
        source,
        contains(contract),
        reason: 'Missing profile contract: $contract',
      );
    }
  });
}
