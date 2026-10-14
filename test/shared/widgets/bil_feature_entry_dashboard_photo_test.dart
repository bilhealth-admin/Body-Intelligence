import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_next/feature_splashes_test_support.dart';
import '../../visual_closure/visual_evidence_font.dart';

const _photos = <BilFeatureEntryKind, (String, String)>{
  BilFeatureEntryKind.recipes: (
    'assets/images/flagship/bil_meal_discovery_v1.png',
    'd75e43e235eff320e7b5912e5bfb6f6e58f8b489acb471baeba5df4708264d3d',
  ),
  BilFeatureEntryKind.videos: (
    'assets/images/flagship/bil_movement_v1.png',
    'c2d804cef28ccd1c639376c2ac971978001a5698c2e8074d0d68c581b127454c',
  ),
  BilFeatureEntryKind.sleep: (
    'assets/images/flagship/bil_sleep_insights_v2.png',
    'cb5b39e393c937c523cc4044e821aeddf09266c60381e91d8a4cb72b2aa2375e',
  ),
  BilFeatureEntryKind.diet: (
    'assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp',
    '8079246da86e82604672390789882e52b32372ac398967518af9104b0bb9ff58',
  ),
};

AssetImage _underlyingAsset(ImageProvider<Object> provider) {
  final original = provider is ResizeImage ? provider.imageProvider : provider;
  expect(original, isA<AssetImage>(), reason: 'dashboard photos stay bundled');
  return original as AssetImage;
}

Widget _actualDiscoverDashboard() => const ProviderScope(
  child: Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: PremiumDashboardBenchmark(
        arabic: false,
        actionTitle: '',
        actionReason: '',
        actionEvidence: '',
        confidence: '',
        onAction: null,
        dailyIntelligence: SizedBox.shrink(),
        bodyTwinSummary: '',
        bodyTwinEvidence: '',
        nutritionSummary: '',
        nutritionEvidence: '',
        trendSummary: '',
        trendEvidence: '',
        loggingItems: [],
        visibleSections: {DashboardSectionIds.discover},
        premiumUnlocked: true,
      ),
    ),
  ),
);

class _UnreadablePhotoBundle extends CachingAssetBundle {
  _UnreadablePhotoBundle(this.photo);
  final String photo;

  @override
  Future<ByteData> load(String key) {
    if (key == photo) {
      return Future.error(StateError('Synthetic missing photo'));
    }
    return rootBundle.load(key);
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final entry in _photos.entries) {
    final kind = entry.key;
    final asset = entry.value.$1;
    testWidgets(
      '${kind.name} splash decodes the exact existing Dashboard photo bytes in the Community template',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        try {
          await tester.pumpWidget(
            featureSplashApp(
              language: 'en',
              dark: false,
              reduceMotion: true,
              child: _actualDiscoverDashboard(),
            ),
          );
          await tester.pump();
          final dashboardPhoto = tester.widget<Image>(
            find.byKey(Key('dashboard-discover-complete-$asset')),
          );
          final dashboardAsset = _underlyingAsset(dashboardPhoto.image);
          expect(dashboardAsset.assetName, asset);
          expect(dashboardPhoto.fit, BoxFit.contain);
          final dashboardBytes = await tester.runAsync(
            () => rootBundle.load(dashboardAsset.assetName),
          );
          expect(dashboardBytes, isNotNull);
          expect(
            sha256
                .convert(
                  dashboardBytes!.buffer.asUint8List(
                    dashboardBytes.offsetInBytes,
                    dashboardBytes.lengthInBytes,
                  ),
                )
                .toString(),
            entry.value.$2,
            reason: 'use the owner-approved bytes, not a newly generated image',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            featureSplashApp(
              language: 'en',
              dark: false,
              reduceMotion: true,
              child: BilFeatureEntrySplashGate(
                kind: kind,
                child: const Scaffold(body: Text('Destination')),
              ),
            ),
          );
          await tester.pump();
          final photoFinder = find.descendant(
            of: find.byKey(Key('bil-feature-welcome-artwork')),
            matching: find.byType(Image),
          );
          expect(photoFinder, findsOneWidget);
          final splashPhoto = tester.widget<Image>(photoFinder);
          final splashAsset = _underlyingAsset(splashPhoto.image);
          expect(splashAsset.assetName, dashboardAsset.assetName);
          expect(splashPhoto.fit, BoxFit.contain);
          expect(splashPhoto.alignment, Alignment.center);
          await settleVisualAssetImages(tester);
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(
                    of: photoFinder,
                    matching: find.byType(RawImage),
                  ),
                )
                .image,
            isNotNull,
            reason: 'actual engine photo decode, not just a matching path',
          );
          final welcome = tester.widget<BilPearlFeatureWelcome>(
            find.byType(BilPearlFeatureWelcome),
          );
          final decoded = tester
              .widget<RawImage>(
                find.descendant(
                  of: photoFinder,
                  matching: find.byType(RawImage),
                ),
              )
              .image!;
          expect(
            welcome.artworkAspectRatio,
            closeTo(decoded.width / decoded.height, .002),
            reason:
                'mask follows the real photo bounds; cache resize can round one pixel',
          );
          expect(
            welcome.artworkWidth,
            kind == BilFeatureEntryKind.recipes ||
                    kind == BilFeatureEntryKind.videos
                ? 220
                : 440,
          );
          expect(welcome.featherArtwork, isTrue);
          expect(find.byType(ShaderMask), findsOneWidget);
          expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(
            find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language feature and Community titles use the established Coach title font at 320px 2x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        try {
          final expectedFamily = language == 'ar' ? 'BILArabic' : 'BILDisplay';
          final surfaces = <Widget>[
            const CommunityWelcome(),
            for (final kind in BilFeatureEntryKind.values)
              BilFeatureEntrySplashGate(
                kind: kind,
                child: const Scaffold(body: Text('Destination')),
              ),
          ];
          for (final surface in surfaces) {
            await tester.pumpWidget(
              featureSplashApp(
                language: language,
                dark: false,
                scale: 2,
                reduceMotion: true,
                child: surface,
              ),
            );
            await tester.pump();
            final title = tester.widget<Text>(
              find.byKey(const Key('bil-feature-welcome-title')),
            );
            expect(title.style!.fontFamily, expectedFamily);
            expect(title.style!.fontWeight, FontWeight.w700);
            expect(title.style!.height, 1.25);
            expect(title.style!.shadows ?? const [], isEmpty);
            expect(
              MediaQuery.textScalerOf(
                tester.element(find.byWidget(title)),
              ).scale(1),
              2,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }

  testWidgets(
    'missing bundled photo keeps the readable welcome and exact 2200ms release',
    (tester) async {
      final asset = _photos[BilFeatureEntryKind.recipes]!.$1;
      try {
        await tester.pumpWidget(
          featureSplashApp(
            language: 'en',
            dark: false,
            reduceMotion: true,
            child: DefaultAssetBundle(
              bundle: _UnreadablePhotoBundle(asset),
              child: const BilFeatureEntrySplashGate(
                kind: BilFeatureEntryKind.recipes,
                child: Scaffold(body: Text('Destination')),
              ),
            ),
          ),
        );
        await tester.pump();
        final fallback = find.byKey(
          const ValueKey('feature-entry-artwork-fallback-recipes'),
        );
        for (
          var frame = 0;
          frame < 50 && fallback.evaluate().isEmpty;
          frame++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(Duration.zero);
        }
        expect(fallback, findsOneWidget);
        expect(find.text('BIL Recipes'), findsOneWidget);
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2199));
        expect(
          find.byKey(const ValueKey('feature-entry-splash-recipes')),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(Duration.zero);
        expect(
          find.byKey(const ValueKey('feature-entry-splash-recipes')),
          findsNothing,
        );
        expect(find.text('Destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
