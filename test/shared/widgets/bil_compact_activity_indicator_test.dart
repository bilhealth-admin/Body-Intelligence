import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native reduce motion stops and resumes the actual iOS wait', (
    tester,
  ) async {
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BilCompactActivityIndicator())),
      ),
    );
    CupertinoActivityIndicator indicator() =>
        tester.widget<CupertinoActivityIndicator>(
          find.byType(CupertinoActivityIndicator),
        );
    expect(indicator().animating, isTrue);
    expect(indicator().color, const Color(0xFF697178));
    expect(indicator().radius, 12);
    expect(
      tester.getSize(find.byType(BilCompactActivityIndicator)),
      const Size.square(24),
    );
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(indicator().animating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pump();
    expect(indicator().animating, isTrue);
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'Dashboard explicitly retains its old circular wait reduced=$reduced',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Scaffold(
                body: Center(child: BilCompactActivityIndicator.dashboard()),
              ),
            ),
          ),
        );
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(
          find.byType(CircularProgressIndicator),
          reduced ? findsNothing : findsOneWidget,
        );
        expect(
          tester.getSize(find.byType(BilCompactActivityIndicator)),
          const Size.square(24),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
