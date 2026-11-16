import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/auth/auth_entry_locale_copy.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart'
    show LoginPage;
import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

Map<String, Object?> credits(int amount) => {
  'credits': {'total_remaining': amount},
};

Future<GoRouter> mountGate(
  WidgetTester tester,
  Stream<String?> owners,
  Future<Object?> Function() load, {
  String language = 'en',
  bool dark = false,
  bool reducedMotion = false,
  double textScale = 1,
  String? ownerSeed,
  String initialLocation = '/coach',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/coach',
        builder: (_, _) => Scaffold(
          body: PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: Consumer(
              builder: (_, ref, _) => Text(
                'private:${ref.watch(verifiedEntitlementOwnerIdProvider)}',
                key: const Key('protected-coach-value'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Back destination')),
      ),
      GoRoute(
        path: '/plans',
        builder: (_, _) => const Scaffold(body: Text('Unexpected Plans')),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/account-gateway',
        builder: (_, _) =>
            const Scaffold(body: Text('Root account gateway destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(ownerSeed),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(load),
      ],
      child: MaterialApp.router(
        theme: visualEvidenceTheme(
          dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light(),
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        locale: Locale(language),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await flushGate(tester);
  return router;
}

Future<void> flushGate(WidgetTester tester) async {
  // Pending checks intentionally animate; do not pretend that they settle.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets(
      'settled signed-out Coach offers real sign-in without a credit read $language',
      (tester) async {
        var loads = 0;
        var ownerSubscriptions = 0;
        final owners = Stream<String?>.multi((controller) {
          ownerSubscriptions++;
          controller.add(null);
          controller.close();
        });
        final router = await mountGate(tester, owners, () async {
          loads++;
          return credits(1000);
        }, language: language);
        expect(
          find.byKey(const Key('ai-coach-account-sign-in')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('ai-coach-account-sign-in')),
            matching: find.text(
              authEntryTextForTag(language, AuthEntryCopyKey.signIn),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('ai-coach-access-checking-surface')),
          findsNothing,
        );
        expect(find.byKey(const Key('protected-coach-value')), findsNothing);
        expect(
          find.byKey(const Key('premium-route-upgrade-cta')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('ai-coach-account-check-unavailable')),
          findsNothing,
        );
        expect(loads, 0);
        await tester.tap(find.byKey(const Key('ai-coach-account-sign-in')));
        await flushGate(tester);
        expect(router.state.uri.path, '/login');
        expect(find.byType(LoginPage), findsOneWidget);
        await tester.tap(find.byKey(const Key('login-back')));
        await flushGate(tester);
        expect(router.state.uri.path, '/coach');
        expect(
          find.byKey(const Key('ai-coach-account-sign-in')),
          findsOneWidget,
        );
        expect(loads, 0);
        expect(ownerSubscriptions, greaterThanOrEqualTo(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cold real login Back retains the account-gateway fallback', (
    tester,
  ) async {
    var loads = 0;
    final router = await mountGate(tester, Stream.value(null), () async {
      loads++;
      return credits(1000);
    }, initialLocation: '/login');
    expect(find.byType(LoginPage), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.tap(find.byKey(const Key('login-back')));
    await flushGate(tester);
    expect(router.state.uri.path, '/account-gateway');
    expect(find.text('Root account gateway destination'), findsOneWidget);
    expect(loads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real login cancellation cannot carry A credit into pending owner B',
    (tester) async {
      String? owner = 'synthetic-A';
      final changes = StreamController<String?>.broadcast();
      addTearDown(changes.close);
      final owners = Stream<String?>.multi((controller) {
        controller.add(owner);
        final subscription = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        controller.onCancel = subscription.cancel;
      });
      final ownerB = Completer<Object?>();
      final router = await mountGate(
        tester,
        owners,
        () => owner == 'synthetic-A'
            ? Future.value(credits(1000))
            : ownerB.future,
      );
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      owner = null;
      changes.add(null);
      await flushGate(tester);
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      await tester.tap(find.byKey(const Key('ai-coach-account-sign-in')));
      await flushGate(tester);
      expect(router.state.uri.path, '/login');
      expect(find.byType(LoginPage), findsOneWidget);
      owner = 'synthetic-B';
      changes.add(owner);
      await flushGate(tester);
      await tester.tap(find.byKey(const Key('login-back')));
      await flushGate(tester);
      expect(router.state.uri.path, '/coach');
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsOneWidget,
      );
      ownerB.complete(credits(0));
      await flushGate(tester);
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('premium-route-upgrade-cta')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unresolved owner has a finite recovery deadline and no RPC', (
    tester,
  ) async {
    final owners = StreamController<String?>.broadcast();
    addTearDown(owners.close);
    var loads = 0;
    await mountGate(tester, owners.stream, () async {
      loads++;
      return credits(1000);
    });
    await tester.pump(const Duration(seconds: 8));
    expect(
      find.byKey(const Key('ai-coach-access-checking-surface')),
      findsOneWidget,
    );
    expect(find.byType(BilCoachPortrait), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await flushGate(tester);
    expect(
      find.byKey(const Key('ai-coach-access-checking-surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('ai-coach-account-check-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-coach-account-retry')), findsOneWidget);
    expect(find.byKey(const Key('ai-coach-account-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('protected-coach-value')), findsNothing);
    expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
    expect(loads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner error is recoverable without pretending signed-out or buying credit',
    (tester) async {
      var subscriptions = 0;
      var loads = 0;
      final owners = Stream<String?>.multi((controller) {
        subscriptions++;
        if (subscriptions == 1) {
          controller.addError(StateError('owner check failed'));
        } else {
          controller.add('synthetic-A');
        }
        controller.close();
      });
      await mountGate(tester, owners, () async {
        loads++;
        return credits(1000);
      });
      expect(
        find.byKey(const Key('ai-coach-account-check-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-coach-account-retry')), findsOneWidget);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsNothing,
      );
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(loads, 0);
      await tester.tap(find.byKey(const Key('ai-coach-account-retry')));
      await flushGate(tester);
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('ai-coach-account-check-unavailable')),
        findsNothing,
      );
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner resolved inside grace cancels stale account recovery', (
    tester,
  ) async {
    final owners = StreamController<String?>.broadcast();
    addTearDown(owners.close);
    await mountGate(tester, owners.stream, () async => credits(1000));
    await tester.pump(const Duration(seconds: 3));
    owners.add('synthetic-A');
    await flushGate(tester);
    expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    await flushGate(tester);
    expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('ai-coach-account-check-unavailable')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit sign-out removes a mounted credited child immediately',
    (tester) async {
      final owners = StreamController<String?>();
      addTearDown(owners.close);
      var loads = 0;
      owners.add('synthetic-A');
      await mountGate(tester, owners.stream, () async {
        loads++;
        return credits(1000);
      });
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      owners.add(null);
      await flushGate(tester);
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(find.byKey(const Key('ai-coach-account-sign-in')), findsOneWidget);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsNothing,
      );
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stable known owner survives stream error but explicit null overrides its seed',
    (tester) async {
      final owners = StreamController<String?>();
      addTearDown(owners.close);
      var loads = 0;
      owners.add('synthetic-A');
      await mountGate(tester, owners.stream, () async {
        loads++;
        return credits(1000);
      }, ownerSeed: 'synthetic-A');
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      owners.addError(StateError('transient owner-stream interruption'));
      await flushGate(tester);
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('ai-coach-account-recovery')), findsNothing);
      expect(loads, 1);
      owners.add(null);
      await flushGate(tester);
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(find.byKey(const Key('ai-coach-account-sign-in')), findsOneWidget);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late settled signed-out owner replaces timeout with truthful sign-in',
    (tester) async {
      final owners = StreamController<String?>.broadcast();
      addTearDown(owners.close);
      var loads = 0;
      await mountGate(tester, owners.stream, () async {
        loads++;
        return credits(1000);
      });
      await tester.pump(const Duration(seconds: 11));
      await flushGate(tester);
      expect(
        find.byKey(const Key('ai-coach-account-check-unavailable')),
        findsOneWidget,
      );
      owners.add(null);
      await flushGate(tester);
      expect(
        find.byKey(const Key('ai-coach-account-check-unavailable')),
        findsNothing,
      );
      expect(find.byKey(const Key('ai-coach-account-sign-in')), findsOneWidget);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsNothing,
      );
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(loads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final reduced in [false, true]) {
        testWidgets(
          'initial Coach credit check keeps its real portrait and Preparing capsule $language dark=$dark reduced=$reduced',
          (tester) async {
            final standardPreview = language == 'en' && !dark && !reduced;
            tester.view.physicalSize = standardPreview
                ? const Size(430, 932)
                : const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final held = Completer<Object?>();
            await mountGate(
              tester,
              Stream.value('synthetic-A'),
              () => held.future,
              language: language,
              dark: dark,
              reducedMotion: reduced,
              textScale: standardPreview ? 1 : 2,
            );
            final surface = find.byKey(
              const Key('ai-coach-access-checking-surface'),
            );
            expect(surface, findsOneWidget);
            expect(find.byType(BilCoachPortrait), findsOneWidget);
            expect(
              find.text(language == 'ar' ? 'جارٍ التحضير…' : 'Preparing…'),
              findsOneWidget,
            );
            final capsule = find.descendant(
              of: surface,
              matching: find.byType(BilSplashCapsuleProgress),
            );
            expect(capsule, findsOneWidget);
            expect(
              tester.widget<BilSplashCapsuleProgress>(capsule).reducedMotion,
              reduced,
            );
            expect(find.byType(CupertinoActivityIndicator), findsNothing);
            expect(
              find.byKey(const Key('protected-coach-value')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('premium-route-upgrade-cta')),
              findsNothing,
            );
            // Decode the approved bundled image instead of merely checking
            // that an Image widget was inserted into the pending surface.
            await tester.runAsync(
              () => precacheImage(
                ResizeImage.resizeIfNeeded(
                  512,
                  null,
                  const AssetImage(bilApprovedAiCoachAsset),
                ),
                tester.element(surface),
              ),
            );
            await tester.pump();
            expect(
              tester
                  .widget<RawImage>(
                    find.descendant(
                      of: find.byType(BilCoachPortrait),
                      matching: find.byType(RawImage),
                    ),
                  )
                  .image,
              isNotNull,
            );
            await tester.pump(const Duration(seconds: 3));
            expect(
              surface,
              findsOneWidget,
              reason: 'Real access is still pending.',
            );
            await captureClosureSurface(
              tester,
              surface,
              'coach-credit-entry-$language-dark-$dark-reduced-$reduced-portrait',
            );
            await tester.ensureVisible(capsule);
            await tester.pump();
            await captureClosureSurface(
              tester,
              surface,
              'coach-credit-entry-$language-dark-$dark-reduced-$reduced-preparing',
            );
            held.complete(credits(1000));
            await flushGate(tester);
            expect(surface, findsNothing);
            expect(
              find.text('private:synthetic-A').hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'known initial zero credit shows a truthful gate and working Back',
    (tester) async {
      final router = await mountGate(
        tester,
        Stream.value('synthetic-A'),
        () async => credits(0),
      );
      expect(
        find.byKey(const Key('premium-route-upgrade-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsNothing,
      );
      expect(find.byKey(const Key('protected-coach-value')), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/coach');
      await tester.tap(find.byTooltip('Back'));
      await flushGate(tester);
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(find.text('Unexpected Plans'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old positive credit is never inherited by B during A B A lookup',
    (tester) async {
      final owners = StreamController<String?>();
      addTearDown(owners.close);
      final heldB = Completer<Object?>();
      var owner = 'synthetic-A';
      owners.add(owner);
      final router = await mountGate(
        tester,
        owners.stream,
        () =>
            owner == 'synthetic-B' ? heldB.future : Future.value(credits(1000)),
      );
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      owner = 'synthetic-B';
      owners.add(owner);
      await flushGate(tester);
      expect(
        find.byKey(const Key('ai-coach-access-checking-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('protected-coach-value')).hitTestable(),
        findsNothing,
      );
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      owner = 'synthetic-A';
      owners.add(owner);
      await flushGate(tester);
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      heldB.complete(credits(0));
      await flushGate(tester);
      expect(find.text('private:synthetic-A').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/coach');
      expect(tester.takeException(), isNull);
    },
  );
}
