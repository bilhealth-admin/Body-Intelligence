import 'dart:ui' as ui;
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final reduced in [false, true]) {
      for (final size in [16.0, 24.0, 48.0]) {
        testWidgets(
          'shared grey waiting fits $size dark=$dark reduced=$reduced',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? ThemeData.dark() : ThemeData.light(),
                  home: MediaQuery(
                    data: MediaQueryData(disableAnimations: reduced),
                    child: Scaffold(
                      body: Center(
                        child: SizedBox.square(
                          dimension: size,
                          child: const BilFeatureWelcomeStatus(
                            key: Key('waiting'),
                            color: Colors.blue,
                            label: 'Checking safely',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 80));
              final indicator = tester.widget<CupertinoActivityIndicator>(
                find.byType(CupertinoActivityIndicator),
              );
              expect(indicator.radius, 12);
              expect(indicator.animating, !reduced);
              expect(
                indicator.color,
                dark ? const Color(0xFFBBC4CD) : const Color(0xFF697178),
              );
              expect(
                tester.getSize(find.byKey(const Key('waiting'))),
                Size.square(size),
              );
              expect(find.byType(BilSplashCapsuleProgress), findsNothing);
              final role = tester
                  .getSemantics(find.byKey(const Key('waiting')))
                  .getSemanticsData();
              expect(role.role, ui.SemanticsRole.loadingSpinner);
              expect(role.label, 'Checking safely');
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets('shared loading follows native reduce motion changes', (
    tester,
  ) async {
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BilFeatureWelcomeStatus())),
      ),
    );
    expect(
      tester
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          )
          .animating,
      isTrue,
    );
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(
      tester
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          )
          .animating,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'explicit Splash variant retains its capsule reduced=$reduced',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Scaffold(
                body: Center(
                  child: BilFeatureWelcomeStatus.splash(
                    color: Color(0xFFBBC4CD),
                  ),
                ),
              ),
            ),
          ),
        );
        final capsule = tester.widget<BilSplashCapsuleProgress>(
          find.byType(BilSplashCapsuleProgress),
        );
        expect(capsule.reducedMotion, reduced);
        expect(capsule.color, const Color(0xFFBBC4CD));
        expect(capsule.width, 24);
        expect(tester.getSize(find.byType(BilSplashCapsuleProgress)).height, 7);
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
