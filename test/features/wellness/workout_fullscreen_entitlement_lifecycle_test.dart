import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_free_preview_policy.generated.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_workout_video_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform originalPlatform;
  late FakeWorkoutVideoPlatform platform;
  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = FakeWorkoutVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() => VideoPlayerPlatform.instance = originalPlatform);

  for (final terminal in ['refund', 'expiry', 'account change']) {
    testWidgets('playing fullscreen video stops and disposes on $terminal', (
      tester,
    ) async {
      var now = DateTime.utc(2099);
      final end = now.add(const Duration(seconds: 2));
      Future<SubscriptionState> response = Future.value(_paid(end));
      final sameOwner = StateProvider<bool>((_) => true);
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedSubscriptionStateProvider.overrideWith(
            (ref) => ref.watch(sameOwner)
                ? response
                : Future.value(FreePlan.createState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse('https://workouts.bilhealth.com/test.mp4'),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _app(
            buildWorkoutFullscreenVideoForTest(
              accessItem: _item(),
              controllerFactory: () async => controller,
            ),
          ),
        ),
      );
      await _flush(tester);
      expect(controller.value.isPlaying, isTrue);

      if (terminal == 'refund') {
        final pending = Completer<SubscriptionState>();
        response = pending.future;
        container.invalidate(verifiedSubscriptionStateProvider);
        await _flush(tester);
        expect(controller.value.isPlaying, isTrue);
        expect(platform.disposed, isEmpty);
        pending.complete(FreePlan.createState());
      } else if (terminal == 'expiry') {
        now = end;
        await tester.pump(const Duration(seconds: 2));
      } else {
        container.read(sameOwner.notifier).state = false;
      }
      await _flush(tester);
      await _drainDisposal(tester);
      expect(
        find.byKey(const ValueKey('workout-video-access-locked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workout-video-complete-frame')),
        findsNothing,
      );
      expect(platform.pauses, contains(0));
      expect(platform.disposed, [0]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('approved free preview keeps playing without paid authority', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        verifiedSubscriptionStateProvider.overrideWith((_) async {
          throw StateError('Free previews must not depend on this lookup');
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://workouts.bilhealth.com/test.mp4'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(
          buildWorkoutFullscreenVideoForTest(
            accessItem: _item(releaseKey: workoutFreePreviewReleaseKeys.first),
            controllerFactory: () async => controller,
          ),
        ),
      ),
    );
    await _flush(tester);
    expect(controller.value.isPlaying, isTrue);
    expect(
      find.byKey(const ValueKey('workout-video-access-locked')),
      findsNothing,
    );
    expect(platform.disposed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await _drainDisposal(tester);
    expect(platform.disposed, [0]);
    expect(tester.takeException(), isNull);
  });
}

SubscriptionState _paid(DateTime end) => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  currentPeriodEndsAt: end,
  isPurchasable: false,
  canRestorePurchases: true,
);

WellnessContentItem _item({String? releaseKey}) => WellnessContentItem(
  id: 'paid-video-test',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Verified workout',
  description: 'A paid workout.',
  publisher: 'BIL',
  sourceUrl: Uri.parse('https://workouts.bilhealth.com'),
  licenseName: 'Licensed',
  verified: true,
  minimumAccess: WellnessContentAccess.pro,
  releaseKey: releaseKey,
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: child,
);

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> _drainDisposal(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await _flush(tester);
}
