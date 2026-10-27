import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Measure the actual RenderBox, while rejecting any smaller screen transform.
/// Subtracting fractional global coordinates can turn an exact 48-point box
/// into 47.99999999999994. The minimum itself stays exact at the call site.
Size nativeUnscaledHitTargetSize(WidgetTester tester, Finder target) {
  final local = tester.getSize(target);
  final global = tester.getRect(target);
  expect(global.width, closeTo(local.width, precisionErrorTolerance));
  expect(global.height, closeTo(local.height, precisionErrorTolerance));
  return local;
}
