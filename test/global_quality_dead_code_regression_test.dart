import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quality cleanup leaves no dangling removed optional-state references',
    () {
      final setupTileSource = File(
        'lib/features/onboarding/body_canvas/body_setup_canvas.dart',
      ).readAsStringSync();
      final calibrationSource = File(
        'lib/features/onboarding/shared/calibration_components.dart',
      ).readAsStringSync();

      expect(setupTileSource, isNot(contains('widget.unit')));
      expect(calibrationSource, isNot(contains('child: busy')));
      expect(calibrationSource, isNot(contains('final bool busy')));
    },
  );
}
