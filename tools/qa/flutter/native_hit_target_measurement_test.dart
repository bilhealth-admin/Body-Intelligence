import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_layout_measurements.dart';

void main() {
  const target = ValueKey('actual-hit-target');

  Future<void> mount(WidgetTester tester, double height, {double scale = 1}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned(
                left: 16,
                top: 464.3,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(key: target, width: 200, height: height),
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('fractional translation preserves the exact 48-point target', (
    tester,
  ) async {
    await mount(tester, 48);
    final finder = find.byKey(target);
    expect(tester.getRect(finder).height, lessThan(48));
    expect(tester.getSize(finder).height, 48);
    expect(
      nativeUnscaledHitTargetSize(tester, finder).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a genuinely undersized target still fails the same minimum', (
    tester,
  ) async {
    await mount(tester, 47.5);
    final size = nativeUnscaledHitTargetSize(tester, find.byKey(target));
    expect(size.height >= 48, isFalse);
  });

  testWidgets('a screen transform cannot disguise a smaller physical target', (
    tester,
  ) async {
    await mount(tester, 48, scale: .8);
    expect(tester.getSize(find.byKey(target)).height, 48);
    expect(
      () => nativeUnscaledHitTargetSize(tester, find.byKey(target)),
      throwsA(isA<TestFailure>()),
    );
  });
}
