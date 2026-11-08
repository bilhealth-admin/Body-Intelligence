import 'dart:ui' as ui;
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final reduced in [false, true]) {
      for (final size in [16.0, 24.0, 48.0]) {
        testWidgets(
          'shared Splash loading fits $size dark=$dark reduced=$reduced',
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
                            label: 'Checking safely',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 80));
              final indicator = tester.widget<BilSplashCapsuleProgress>(
                find.byType(BilSplashCapsuleProgress),
              );
              expect(
                tester.getSize(find.byType(BilSplashCapsuleProgress)).height,
                7,
              );
              expect(indicator.reducedMotion, reduced);
              expect(
                indicator.color,
                dark ? const Color(0xFF8CCFFF) : const Color(0xFF10254A),
              );
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
          .widget<BilSplashCapsuleProgress>(
            find.byType(BilSplashCapsuleProgress),
          )
          .reducedMotion,
      isFalse,
    );
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(
      tester
          .widget<BilSplashCapsuleProgress>(
            find.byType(BilSplashCapsuleProgress),
          )
          .reducedMotion,
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
