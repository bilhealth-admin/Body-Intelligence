import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('welcome step keeps the approved premium minimal hierarchy', () {
    final source = File(
      'lib/features/onboarding/widgets/welcome_step.dart',
    ).readAsStringSync();

    expect(source, contains("BilWordmark(height: 54)"));
    expect(
      source,
      contains(
        'ابدأ رحلتك نحو جسم أكثر صحة وقوة وذكاء مع نموذج شخصي يتعلم من بياناتك.',
      ),
    );
    expect(source, contains("'متابعة'"));
    expect(
      source,
      contains('assets/images/flagship/bil_body_intelligence_journey_v1.png'),
    );

    expect(source, isNot(contains('LanguageSwitcher')));
    expect(source, isNot(contains('خصوصية ووضوح')));
    expect(source, isNot(contains('مرحبًا بك')));
    expect(source, isNot(contains('Privacy')));
  });
}
