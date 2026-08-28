import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body setup exposes live estimates with uncertainty and disclaimer', () {
    final source = File(
      'lib/features/onboarding/body_canvas/body_setup_canvas.dart',
    ).readAsStringSync();

    expect(source, contains('BodyModelEngine.calculate('));
    expect(source, contains('Expected body fat'));
    expect(source, contains('Expected fat-free mass'));
    expect(source, isNot(contains('leanBodyMassPercentage')));
    expect(source, contains('fatFreeMassKg'));
    expect(source, contains('Higher uncertainty'));
    expect(source, contains('Educational estimate, not a diagnosis.'));
  });
}
