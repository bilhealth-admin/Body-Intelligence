import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings can reopen onboarding without destructive reset', () {
    final settings = [
      File('lib/features/settings/settings_page.dart').readAsStringSync(),
      File(
        'lib/features/settings/settings_page_actions.dart',
      ).readAsStringSync(),
    ].join('\n');

    expect(settings, contains("set('forceOnboarding', 'true')"));
    expect(settings, contains("context.go('/onboarding')"));
    expect(settings, contains("key: const Key('settings-review-onboarding')"));
    expect(settings, contains('without deleting your profile or records'));
  });

  test('startup honors force-onboarding before dashboard routing', () {
    final startup = File(
      'lib/features/startup/startup_page.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/profile/providers/user_profile_provider.dart',
    ).readAsStringSync();

    expect(providers, contains('final forceOnboardingProvider'));
    expect(startup, contains('ref.watch(forceOnboardingProvider)'));
    expect(startup, contains('else if (forceOnboarding.value == true)'));
    expect(startup, contains('else if (user == null'));
  });

  test(
    'successful onboarding clears the flag and enters dashboard directly',
    () {
      final onboarding = File(
        'lib/features/onboarding/onboarding_page.dart',
      ).readAsStringSync();

      expect(onboarding, contains("set('forceOnboarding', 'false')"));
      expect(onboarding, contains("context.go('/dashboard')"));
      expect(onboarding, isNot(contains("context.go('/startup')")));
    },
  );
}
