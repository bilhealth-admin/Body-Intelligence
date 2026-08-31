import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the modern BIL onboarding flow remains wired', () {
    final production = <File>[
      ...Directory('lib/features/onboarding')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('lib/app/router/app_router.dart'),
      File('pubspec.yaml'),
    ];
    final source = production.map((file) => file.readAsStringSync()).join('\n');

    for (final stale in const [
      'BilFlagshipOnboarding',
      'BodySetupCanvas',
      'WelcomeScreen',
      'onboarding_locale_copy',
      'body_canvas',
      'welcome_screen',
      'models/onboarding_data',
      'assets/images/onboarding/',
    ]) {
      expect(source, isNot(contains(stale)), reason: stale);
    }
    for (final externalBrand in const [
      'MyFitnessPal',
      'My Fitness Pal',
      'myfitness',
      'Terms & Conditions',
    ]) {
      expect(
        source.toLowerCase(),
        isNot(contains(externalBrand.toLowerCase())),
      );
    }

    expect(source, contains('class OnboardingPage'));
    expect(source, contains("context.push('/legal/privacy')"));
    expect(source, contains("context.push('/legal/terms')"));
  });

  test('legacy onboarding files and artwork are physically absent', () {
    for (final path in const [
      'lib/features/onboarding/bil_flagship_onboarding.dart',
      'lib/features/onboarding/body_canvas',
      'lib/features/onboarding/onboarding_locale_copy.dart',
      'lib/features/onboarding/shared',
      'lib/features/onboarding/welcome',
      'lib/features/onboarding/models/onboarding_data.dart',
      'assets/images/onboarding',
    ]) {
      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    }
  });
}
