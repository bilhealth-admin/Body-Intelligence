import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual_closure/visual_evidence_font.dart';
import 'feature_splashes_test_support.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  const scenes = [
    (
      language: 'en',
      dark: false,
      width: 390.0,
      height: 844.0,
      scale: 1.0,
      reduced: false,
    ),
    (
      language: 'ar',
      dark: false,
      width: 390.0,
      height: 844.0,
      scale: 1.0,
      reduced: false,
    ),
    (
      language: 'en',
      dark: true,
      width: 390.0,
      height: 844.0,
      scale: 1.0,
      reduced: false,
    ),
    (
      language: 'ar',
      dark: true,
      width: 390.0,
      height: 844.0,
      scale: 1.0,
      reduced: false,
    ),
    (
      language: 'ar',
      dark: false,
      width: 320.0,
      height: 568.0,
      scale: 2.0,
      reduced: true,
    ),
    (
      language: 'en',
      dark: true,
      width: 320.0,
      height: 568.0,
      scale: 2.0,
      reduced: true,
    ),
  ];
  for (final scene in scenes) {
    final suffix =
        '${scene.language}_${scene.dark ? 'dark' : 'light'}_${scene.width.toInt()}_${scene.scale}x';
    for (final kind in BilFeatureEntryKind.values) {
      testWidgets(
        'actual ${kind.name} feature splash capture $suffix',
        (tester) async {
          tester.view.physicalSize = Size(scene.width, scene.height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            featureSplashApp(
              language: scene.language,
              dark: scene.dark,
              scale: scene.scale,
              reduceMotion: scene.reduced,
              child: RepaintBoundary(
                key: key,
                child: BilFeatureEntrySplashGate(
                  kind: kind,
                  child: const Scaffold(body: Text('Destination')),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
            findsOneWidget,
          );
          // Images are the Dashboard's real bundled photos now. Resolve them
          // before recording pixels; this never changes the production hold.
          await settleVisualAssetImages(tester);
          await tester.pump();
          expect(
            find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
            findsOneWidget,
            reason: 'capture actual photo while the welcome is still visible',
          );
          final layoutError = tester.takeException();
          await writeFeatureSplashCapture(tester, key, '${kind.name}_$suffix');
          expect(layoutError, isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
    testWidgets(
      'actual Community feature splash capture $suffix',
      (tester) async {
        tester.view.physicalSize = Size(scene.width, scene.height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          featureSplashApp(
            language: scene.language,
            dark: scene.dark,
            scale: scene.scale,
            reduceMotion: scene.reduced,
            child: RepaintBoundary(key: key, child: const CommunityWelcome()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await settleVisualAssetImages(tester);
        await tester.pump();
        final layoutError = tester.takeException();
        await writeFeatureSplashCapture(tester, key, 'community_$suffix');
        expect(layoutError, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'actual AI Coach feature splash capture $suffix',
      (tester) async {
        tester.view.physicalSize = Size(scene.width, scene.height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final harness = FeatureCoachSplashHarness(
          language: scene.language,
          dark: scene.dark,
          scale: scene.scale,
          reduceMotion: scene.reduced,
        );
        try {
          await harness.mount(tester, captureKey: key);
          await tester.pump(const Duration(milliseconds: 100));
          await settleVisualAssetImages(tester);
          await tester.pump();
          expect(
            find.text(
              scene.language == 'ar'
                  ? 'مرحبًا بك في المدرب الذكي'
                  : 'Welcome to AI Coach',
            ),
            findsOneWidget,
          );
          final layoutError = tester.takeException();
          await writeFeatureSplashCapture(tester, key, 'coach_$suffix');
          expect(layoutError, isNull);
        } finally {
          await harness.dispose(tester);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}
