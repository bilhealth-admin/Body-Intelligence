import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('steps history replaces the settings route instead of stacking it', () {
    final source = File(
      'lib/features/connected_health/steps_settings_page.dart',
    ).readAsStringSync();
    expect(source, contains("context.go('/history')"));
    expect(source, isNot(contains("context.push('/history')")));
  });
}
