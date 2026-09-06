import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings can reopen onboarding without destructive reset', () {
    final settingsPage = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/settings/settings_page_actions.dart',
    ).readAsStringSync();

    expect(actions, contains("set('forceOnboarding', 'true')"));
    expect(actions, contains("context.go('/onboarding')"));
    expect(
      settingsPage,
      contains("key: const Key('settings-review-onboarding')"),
    );
    expect(actions, contains('keeping your profile, weight records, meals'));
    expect(actions, contains('Nothing will be deleted or uploaded.'));
    for (final destructiveCall in const [
      '.delete(',
      'deleteAll(',
      'clearAll(',
      'resetDatabase(',
    ]) {
      expect(actions, isNot(contains(destructiveCall)));
    }
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
      final completion = File(
        'lib/features/onboarding/domain/onboarding_completion_service.dart',
      ).readAsStringSync();

      expect(completion, contains("'forceOnboarding': 'false'"));
      expect(completion, contains('setManyInCurrentTransaction'));
      expect(onboarding, contains("context.go('/dashboard')"));
      expect(onboarding, isNot(contains("context.go('/startup')")));
    },
  );
}
