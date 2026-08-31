import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality cleanup leaves one production onboarding implementation', () {
    expect(
      File('lib/features/onboarding/onboarding_page.dart').existsSync(),
      isTrue,
    );
    for (final removed in <String>[
      'lib/features/onboarding/bil_flagship_onboarding.dart',
      'lib/features/onboarding/body_canvas/body_setup_canvas.dart',
      'lib/features/onboarding/shared/calibration_components.dart',
      'lib/features/onboarding/widgets/welcome_step.dart',
      'lib/features/onboarding/widgets/profile_step.dart',
    ]) {
      expect(File(removed).existsSync(), isFalse, reason: removed);
    }
  });
}
