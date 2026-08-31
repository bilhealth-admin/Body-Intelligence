import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _testWidgetsOnAndroid(
    'opening details resolves the poster but never requests MP4 online',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'bil-explicit-video-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final cache = _ExplicitMediaCache(directory: directory);

      await tester.pumpWidget(_app(cache));
      await _settleExplicitMedia(tester);

      expect(cache.posterOnlineResolutions, 1);
      expect(cache.videoOfflineResolutions, 1);
      expect(cache.videoOnlineResolutions, 0);
      expect(find.byKey(const ValueKey('workout-video-play')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workout-video-download')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('workout-video-play')));
      await _settleExplicitMedia(tester);

      expect(cache.videoOnlineResolutions, 1);
    },
  );

  _testWidgetsOnAndroid(
    'Download persists explicitly and Remove deletes the cached MP4',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'bil-explicit-download-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final cache = _ExplicitMediaCache(
        directory: directory,
        makeVideoReadyOnline: true,
      );

      await tester.pumpWidget(_app(cache));
      await _settleExplicitMedia(tester);
      await tester.tap(find.byKey(const ValueKey('workout-video-download')));
      await _settleExplicitMedia(tester);

      expect(cache.videoOnlineResolutions, 1);
      expect(cache.downloaded, isTrue);
      expect(
        find.byKey(const ValueKey('workout-video-remove')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(_app(cache, key: const ValueKey('restarted')));
      await _settleExplicitMedia(tester);

      expect(cache.videoOnlineResolutions, 1);
      expect(cache.videoOfflineResolutions, 2);
      expect(
        find.byKey(const ValueKey('workout-video-remove')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('workout-video-remove')));
      await _settleExplicitMedia(tester);

      expect(cache.removals, 1);
      expect(cache.downloaded, isFalse);
      expect(
        find.byKey(const ValueKey('workout-video-download')),
        findsOneWidget,
      );
    },
  );
}

void _testWidgetsOnAndroid(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _settleExplicitMedia(WidgetTester tester) async {
  for (var index = 0; index < 8; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _app(WellnessMediaCache cache, {Key? key}) => ProviderScope(
  overrides: [
    verifiedSubscriptionStateProvider.overrideWith(
      (ref) async => FreePlan.createState(),
    ),
  ],
  child: MaterialApp(
    key: key,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: BilWorkoutRoutineDetailsPage(
      item: _videoWorkout,
      initiallySaved: false,
      onToggleSaved: () async {},
      mediaCache: cache,
      offline: false,
    ),
  ),
);

final _videoWorkout = WellnessContentItem(
  id: 'explicit-video-fixture',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Explicit workout video',
  description: 'A verified explicit-transfer fixture.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/explicit-video-fixture'),
  licenseName: 'BIL licensed original',
  verified: true,
  minimumAccess: WellnessContentAccess.free,
  imageMedia: WellnessMediaAsset(
    url: Uri.parse('https://workouts.bilhealth.com/v2/objects/poster.webp'),
    mimeType: 'image/webp',
    sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    sizeBytes: 12,
  ),
  videoMedia: WellnessMediaAsset(
    url: Uri.parse('https://workouts.bilhealth.com/v2/objects/video.mp4'),
    mimeType: 'video/mp4',
    sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    sizeBytes: 12,
    mediaRole: WellnessMediaRole.preview,
  ),
  steps: const ['Move with control.'],
  reviewedAt: DateTime.utc(2026, 8, 31),
  safetyReviewed: true,
);

final class _ExplicitMediaCache extends WellnessMediaCache {
  _ExplicitMediaCache({
    required this.directory,
    this.makeVideoReadyOnline = false,
  });

  final Directory directory;
  final bool makeVideoReadyOnline;
  int posterOnlineResolutions = 0;
  int videoOnlineResolutions = 0;
  int videoOfflineResolutions = 0;
  int removals = 0;
  bool downloaded = false;

  @override
  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) async {
    if (asset.mimeType.startsWith('image/')) {
      if (online) posterOnlineResolutions += 1;
      return const WellnessMediaCacheResult.unavailableOffline();
    }
    if (online) {
      videoOnlineResolutions += 1;
      if (makeVideoReadyOnline) downloaded = true;
    } else {
      videoOfflineResolutions += 1;
    }
    if (!downloaded) {
      return const WellnessMediaCacheResult.unavailableOffline();
    }
    final file = File('${directory.path}/verified.mp4');
    if (!file.existsSync()) file.writeAsBytesSync(List<int>.filled(12, 7));
    return WellnessMediaCacheResult.ready(file, fromCache: !online);
  }

  @override
  Future<void> remove(WellnessMediaAsset asset) async {
    removals += 1;
    downloaded = false;
    final file = File('${directory.path}/verified.mp4');
    if (file.existsSync()) file.deleteSync();
  }
}
