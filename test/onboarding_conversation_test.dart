import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flagship onboarding preserves staged, resumable profile journey', () {
    final page = File(
      'lib/features/onboarding/onboarding_page.dart',
    ).readAsStringSync();
    final flagship = File(
      'lib/features/onboarding/bil_flagship_onboarding.dart',
    ).readAsStringSync();
    expect(page, contains('onboardingDraftRepositoryProvider'));
    expect(page, contains('_initialFlagshipDraft()'));
    expect(page, contains('onComplete: _saveAndComplete'));
    expect(flagship, contains('BilOnboardingDraft'));
    expect(flagship, contains('onExitToWelcome'));
  });
}
