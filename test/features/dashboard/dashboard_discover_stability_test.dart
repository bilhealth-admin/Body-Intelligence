import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/shared/widgets/bil_navigation_feedback.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../qa_next/feature_splashes_test_support.dart';
import '../../visual_closure/visual_evidence_font.dart';

part '../../support/discover_fixture_cleanup.dart';

const _capture = Key('discover-preview-capture');
const _protected = Key('protected-sleep-body');
const _sleepRoute = '/wellness/sleep';
const _photos = [
  'assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp',
  'assets/images/flagship/bil_sleep_insights_v2.png',
  'assets/images/flagship/bil_meal_discovery_v1.png',
  'assets/images/flagship/bil_movement_v1.png',
];

Finder _tile(String path) =>
    find.byKey(ValueKey('dashboard-discover-tile-$path'));

Widget _dashboard({
  required bool arabic,
  bool resolved = true,
  bool paid = false,
  bool checking = false,
}) => RepaintBoundary(
  key: _capture,
  child: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PremiumDashboardBenchmark(
        arabic: arabic,
        actionTitle: '',
        actionReason: '',
        actionEvidence: '',
        confidence: '',
        onAction: null,
        dailyIntelligence: const SizedBox.shrink(),
        bodyTwinSummary: '',
        bodyTwinEvidence: '',
        nutritionSummary: '',
        nutritionEvidence: '',
        trendSummary: '',
        trendEvidence: '',
        loggingItems: const [],
        visibleSections: const {DashboardSectionIds.discover},
        premiumUnlocked: paid,
        premiumAccessResolved: resolved,
        premiumAccessChecking: checking,
      ),
    ),
  ),
);

Future<List<int>> _frame(WidgetTester tester, String? name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Real render returned no PNG');
      final bytes = data.buffer.asUint8List();
      const output = String.fromEnvironment('BIL_DASHBOARD_CAPTURE_DIR');
      if (output.isNotEmpty && name != null) {
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      }
      return bytes;
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  return bytes!;
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$language dark=$dark: discover pixels and arrows remain stable through access rechecks',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var resolved = true;
          var paid = false;
          var checking = false;
          late StateSetter update;
          try {
            await tester.pumpWidget(
              ProviderScope(
                child: featureSplashApp(
                  language: language,
                  dark: dark,
                  reduceMotion: true,
                  child: StatefulBuilder(
                    builder: (_, setState) {
                      update = setState;
                      return _dashboard(
                        arabic: language == 'ar',
                        resolved: resolved,
                        paid: paid,
                        checking: checking,
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pump();
            await settleVisualAssetImages(tester);
            await tester.pump(const Duration(milliseconds: 200));
            final sleep = _tile(_sleepRoute);
            final arrow = find.descendant(
              of: sleep,
              matching: find.byType(BilNavigationFeedback),
            );
            expect(arrow, findsOneWidget);
            final originalArrow = tester.element(arrow);
            final originalRect = tester.getRect(sleep);
            final before = await _frame(
              tester,
              'discover-$language-${dark ? 'dark' : 'light'}',
            );

            for (final state in [
              (false, false, true), // Initial/unresolved server authority.
              (true, true, false), // Verified paid response.
              (false, false, true), // Periodic/background revalidation.
              (true, false, false), // Verified Free/expired response.
              (false, false, false), // Unavailable verification.
            ]) {
              update(() {
                resolved = state.$1;
                paid = state.$2;
                checking = state.$3;
              });
              await tester.pump();
              await tester.pump(const Duration(seconds: 30));
              expect(tester.element(arrow), same(originalArrow));
              expect(tester.getRect(sleep), originalRect);
              expect(tester.widget<InkWell>(sleep).onTap, isNotNull);
              expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
              expect(await _frame(tester, null), orderedEquals(before));
            }
            for (final photo in _photos) {
              final finder = find.byKey(
                Key('dashboard-discover-complete-$photo'),
              );
              final image = tester.widget<Image>(finder);
              final raw = tester.widget<RawImage>(
                find.descendant(of: finder, matching: find.byType(RawImage)),
              );
              expect(raw.image, isNotNull);
              expect(image.fit, BoxFit.cover);
              expect(image.gaplessPlayback, isTrue);
              final output = tester.getSize(finder);
              final fitted = applyBoxFit(
                image.fit!,
                Size(raw.image!.width.toDouble(), raw.image!.height.toDouble()),
                output,
              );
              expect(fitted.destination, output);
              if (photo.endsWith('bil_movement_v1.png')) {
                expect(image.alignment, const Alignment(0, -.6));
                // The reviewed focal point preserves the subject on phone
                // and wide cards; coverage still fills the actual viewport.
                expect(fitted.source.height, greaterThan(450));
              }
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(Duration.zero);
          }
        },
      );
    }
  }

  testWidgets(
    'discover cleanup closes a never-listened owner stream and preserves the original failure',
    (tester) async {
      final owners = _DiscoverOwnerStream();
      final original = StateError('controlled discover body failure');
      final failures = <({String stage, Object error, StackTrace stack})>[
        (stage: 'original', error: original, stack: StackTrace.current),
      ];
      await _attemptDiscoverCleanup(
        failures,
        'never-listened owners',
        () => owners.close(tester),
      );
      expect(owners.completionObserved, isTrue);
      expect(
        () => _throwDiscoverCleanupFailures(failures),
        throwsA(same(original)),
      );
    },
  );

  testWidgets(
    'unresolved discover entry opens the real gate, not protected content; fresh paid verification is required',
    (tester) async {
      final pending = Completer<SubscriptionState>();
      Future<SubscriptionState> response = pending.future;
      final owners = _DiscoverOwnerStream();
      final now = DateTime.utc(2026, 11, 8);
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('demo-owner'),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() => response),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) =>
                _dashboard(arabic: false, resolved: false, checking: true),
          ),
          GoRoute(
            path: _sleepRoute,
            builder: (_, _) => const PremiumRouteGlassGate(
              feature: PremiumGateFeature.sleep,
              child: Scaffold(body: Text('Protected sleep', key: _protected)),
            ),
          ),
        ],
      );
      final cleanupFailures =
          <({String stage, Object error, StackTrace stack})>[];
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              theme: featureSplashEvidenceTheme(language: 'en', dark: false),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.tap(_tile(_sleepRoute));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          _sleepRoute,
        );
        expect(
          find.byKey(const ValueKey('premium-route-access-checking')),
          findsOneWidget,
        );
        expect(find.byKey(_protected), findsNothing);
        pending.complete(
          SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: EntitlementAuthority.verifiedServer,
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_protected), findsNothing);
        expect(
          find.byKey(const ValueKey('premium-route-upgrade-cta')),
          findsOneWidget,
        );
        final verifiedPaid = Completer<SubscriptionState>();
        response = verifiedPaid.future;
        container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(find.byKey(_protected), findsNothing);
        verifiedPaid.complete(
          SubscriptionState(
            plan: CommercePlan.premium,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            isPurchasable: false,
            canRestorePurchases: true,
            currentPeriodEndsAt: now.add(const Duration(hours: 1)),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_protected), findsOneWidget);
        expect(tester.takeException(), isNull);
      } catch (error, stack) {
        cleanupFailures.add((stage: 'original', error: error, stack: stack));
      } finally {
        await _attemptDiscoverCleanup(cleanupFailures, 'unmount', () async {
          await tester.pumpWidget(const SizedBox.shrink());
        });
        await _attemptDiscoverCleanup(cleanupFailures, 'router', () async {
          router.dispose();
        });
        await _attemptDiscoverCleanup(cleanupFailures, 'container', () async {
          container.dispose();
          await tester.pump(Duration.zero);
        });
        await _attemptDiscoverCleanup(
          cleanupFailures,
          'owners',
          () => owners.close(tester),
        );
        _throwDiscoverCleanupFailures(cleanupFailures);
      }
    },
  );
}

/// Exercise the actual Dashboard tile -> real paid gate -> Android system Back.
/// The old source-spelling assertion could not prove either stack or authority.
Future<void> verifyAndroidDiscoverBackNavigation(WidgetTester tester) async {
  final previousPlatform = foundation.debugDefaultTargetPlatformOverride;
  foundation.debugDefaultTargetPlatformOverride =
      foundation.TargetPlatform.android;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final pending = Completer<SubscriptionState>();
  Future<SubscriptionState> response = pending.future;
  final owners = _DiscoverOwnerStream();
  final now = DateTime.utc(2026, 11, 8);
  var protectedBuilds = 0;
  final container = ProviderContainer(
    overrides: [
      verifiedEntitlementOwnerSeedProvider.overrideWithValue('demo-owner'),
      verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
      verifiedEntitlementClockProvider.overrideWithValue(() => now),
      verifiedEntitlementLoaderProvider.overrideWithValue(() => response),
      storefrontTargetPlanProvider.overrideWith(
        (_) async => CommercePlan.premium,
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) =>
            _dashboard(arabic: false, resolved: false, checking: true),
      ),
      GoRoute(
        path: _sleepRoute,
        builder: (_, _) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.sleep,
          child: Builder(
            builder: (_) {
              protectedBuilds++;
              return const Scaffold(
                body: Text('Protected sleep', key: _protected),
              );
            },
          ),
        ),
      ),
    ],
  );
  String currentRoute() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
  Future<void> driveTransition(
    ModalRoute<dynamic> route, {
    required bool reverse,
  }) async {
    final animation = route.animation!;
    final duration = reverse
        ? route.reverseTransitionDuration
        : route.transitionDuration;
    final target = reverse
        ? AnimationStatus.dismissed
        : AnimationStatus.completed;
    final limit = (duration.inMicroseconds / 16000).ceil() + 2;
    var frames = 0;
    while (animation.status != target && frames < limit) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    await tester.pump();
    debugPrint(
      'DISCOVER_ANIMATION reverse=$reverse duration_ms=${duration.inMilliseconds} frames=$frames status=${animation.status} value=${animation.value} overlays=${route.overlayEntries.map((entry) => entry.mounted).toList()}',
    );
    expect(
      animation.status,
      target,
      reason: 'Complete the declared route transition within bounded frames.',
    );
    if (reverse) expect(_tile(_sleepRoute).hitTestable(), findsOneWidget);
  }

  Future<void> openSleep() async {
    debugPrint('DISCOVER_BACK openSleep tap begin');
    expect(_tile(_sleepRoute).hitTestable(), findsOneWidget);
    await tester.tap(_tile(_sleepRoute));
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(
      tester.element(find.byType(PremiumRouteGlassGate)),
    )!;
    await driveTransition(route, reverse: false);
    debugPrint(
      'DISCOVER_BACK openSleep transition done route=${currentRoute()}',
    );
    expect(currentRoute(), _sleepRoute);
    expect(router.canPop(), isTrue);
  }

  Future<bool> handleSystemBack(String phase) async {
    var completed = false;
    bool? handled;
    Object? failure;
    StackTrace? failureStack;
    final route = ModalRoute.of(
      tester.element(find.byType(PremiumRouteGlassGate)),
    )!;
    debugPrint('DISCOVER_BACK pop=$phase dispatch begin');
    tester.binding.handlePopRoute().then<void>(
      (value) {
        handled = value;
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    );
    await tester.pump();
    await driveTransition(route, reverse: true);
    debugPrint(
      'DISCOVER_BACK pop=$phase completed=$completed handled=$handled route=${currentRoute()}',
    );
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    expect(
      completed,
      isTrue,
      reason:
          'Real system Back completes within the declared route transition.',
    );
    return handled!;
  }

  final cleanupFailures = <({String stage, Object error, StackTrace stack})>[];
  try {
    debugPrint('DISCOVER_BACK font load begin');
    // The imported helper's caller has no font setUpAll. File reads and
    // FontLoader engine futures must run on the real host event loop.
    await tester.runAsync(loadVisualEvidenceFont);
    debugPrint('DISCOVER_BACK font load done; mount begin');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: featureSplashEvidenceTheme(
            language: 'en',
            dark: false,
          ).copyWith(platform: foundation.TargetPlatform.android),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    debugPrint('DISCOVER_BACK mount done; initial frame begin');
    await tester.pump();
    debugPrint('DISCOVER_BACK initial frame done');
    expect(foundation.defaultTargetPlatform, foundation.TargetPlatform.android);
    expect(currentRoute(), '/dashboard');
    expect(router.canPop(), isFalse);
    final originalTile = tester.element(_tile(_sleepRoute));

    // Unresolved access still permits navigation to the public gate, while
    // verified paid content is never built or exposed to interaction.
    await openSleep();
    expect(
      find.byKey(const ValueKey('premium-route-access-checking')),
      findsOneWidget,
    );
    expect(find.byKey(_protected), findsNothing);
    expect(protectedBuilds, 0);
    expect(await handleSystemBack('unresolved'), isTrue);
    expect(currentRoute(), '/dashboard');
    expect(router.canPop(), isFalse);
    expect(tester.element(_tile(_sleepRoute)), same(originalTile));

    // Completing the previous check after Back cannot navigate on its own.
    pending.complete(
      SubscriptionState(
        plan: CommercePlan.free,
        entitlements: FreePlan.entitlements,
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(currentRoute(), '/dashboard');
    await openSleep();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsOneWidget,
    );
    expect(find.byKey(_protected), findsNothing);
    expect(protectedBuilds, 0);
    expect(await handleSystemBack('verified-free'), isTrue);
    expect(currentRoute(), '/dashboard');
    expect(tester.element(_tile(_sleepRoute)), same(originalTile));

    // A positive control proves the real destination gate can open only after
    // a fresh verified paid response, rather than using an always-locked stub.
    response = Future<SubscriptionState>.value(
      SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: true,
        currentPeriodEndsAt: now.add(const Duration(hours: 1)),
      ),
    );
    container.invalidate(verifiedSubscriptionStateProvider);
    await openSleep();
    await tester.pump();
    expect(find.byKey(_protected), findsOneWidget);
    expect(protectedBuilds, greaterThan(0));
    expect(await handleSystemBack('verified-paid'), isTrue);
    expect(currentRoute(), '/dashboard');
    expect(router.canPop(), isFalse);
    expect(tester.element(_tile(_sleepRoute)), same(originalTile));
    expect(tester.takeException(), isNull);
  } catch (error, stack) {
    cleanupFailures.add((stage: 'original', error: error, stack: stack));
  } finally {
    await _attemptDiscoverCleanup(cleanupFailures, 'unmount', () async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await _attemptDiscoverCleanup(cleanupFailures, 'router', () async {
      router.dispose();
    });
    await _attemptDiscoverCleanup(cleanupFailures, 'container', () async {
      container.dispose();
      await tester.pump(Duration.zero);
    });
    await _attemptDiscoverCleanup(
      cleanupFailures,
      'owners',
      () => owners.close(tester),
    );
    await _attemptDiscoverCleanup(cleanupFailures, 'view size', () async {
      tester.view.resetPhysicalSize();
    });
    await _attemptDiscoverCleanup(cleanupFailures, 'view ratio', () async {
      tester.view.resetDevicePixelRatio();
    });
    await _attemptDiscoverCleanup(cleanupFailures, 'platform', () async {
      foundation.debugDefaultTargetPlatformOverride = previousPlatform;
    });
    _throwDiscoverCleanupFailures(cleanupFailures);
  }
}
