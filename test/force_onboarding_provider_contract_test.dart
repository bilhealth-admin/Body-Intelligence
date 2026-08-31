import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('force onboarding uses a one-shot auto-disposed preference read', () {
    final source = File(
      'lib/features/profile/providers/user_profile_provider.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final forceOnboardingProvider = FutureProvider.autoDispose<bool>',
      ),
    );
    expect(source, contains(".get('forceOnboarding')"));
    expect(source, isNot(contains("watch('forceOnboarding')")));
  });

  test('startup tests isolate force onboarding from the real database', () {
    final source = File('test/startup_state_test.dart').readAsStringSync();

    expect(
      'forceOnboardingProvider.overrideWith'.allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
  });
}
