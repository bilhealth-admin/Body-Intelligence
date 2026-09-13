import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Map<String, Object?> _aiUsage(Object? totalRemaining) => {
  'plan': 'ai_coach',
  'credits': <String, Object?>{'total_remaining': totalRemaining},
};

void main() {
  testWidgets('Android More to Coach returns through header and system back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: IntelligenceCenterPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
          aiCoachCreditAccessProvider.overrideWithValue(const AsyncData(true)),
          coachContextSnapshotProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.android),
          locale: const Locale('en'),
          routerConfig: router,
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
    await tester.pumpAndSettle();

    Future<void> openCoach() async {
      final entry = find.byKey(const Key('more-ai-coach-entry'));
      await tester.scrollUntilVisible(entry, 280);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-coach-hero')), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
    }

    await openCoach();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await openCoach();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Android AI Coach paywall returns to More without freezing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: IntelligenceCenterPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
          aiCoachCreditAccessProvider.overrideWithValue(const AsyncData(false)),
          coachContextSnapshotProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.android),
          locale: const Locale('en'),
          routerConfig: router,
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
    await tester.pumpAndSettle();

    Future<void> openPaywall() async {
      final entry = find.byKey(const Key('more-ai-coach-entry'));
      await tester.scrollUntilVisible(entry, 280);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-protected-content')),
        findsOneWidget,
      );
      expect(find.text('BIL AI BOOST'), findsWidgets);
      expect(find.text('BIL PREMIUM AI COACH'), findsNothing);
      expect(find.byType(SettingsPage), findsNothing);
    }

    await openPaywall();
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.arrow_back_rounded).last,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await openPaywall();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'verified AI Coach stays mounted during silent server revalidation',
    (tester) async {
      var loads = 0;
      Completer<Object?>? pendingReload;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream<String?>.value('qa-owner'),
            ),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(() {
              loads++;
              if (loads == 1) {
                return Future<Object?>.value(_aiUsage(1000));
              }
              final pending = pendingReload;
              if (pending == null) {
                return Future<Object?>.error(
                  StateError('missing_test_reload_completer'),
                );
              }
              return pending.future;
            }),
          ],
          child: const MaterialApp(
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: Scaffold(body: Text('Coach surface')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coach surface'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('premium-route-access-checking')),
        findsNothing,
      );
      expect(loads, 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      pendingReload = Completer<Object?>();
      container
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      await tester.pump();

      // A background credit refresh must not cover or rebuild a previously
      // verified Coach surface with the full-screen access spinner.
      expect(find.text('Coach surface'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('premium-route-access-checking')),
        findsNothing,
      );

      pendingReload!.complete(_aiUsage(1000));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Coach surface'), findsOneWidget);

      pendingReload = Completer<Object?>();
      container
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      await tester.pump();
      expect(find.text('Coach surface'), findsOneWidget);

      // Once the authoritative server response says the balance is exhausted,
      // the gate must close instead of trusting the retained presentation.
      pendingReload!.complete(_aiUsage(0));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('BIL AI BOOST'), findsWidgets);
      expect(find.text('Coach surface'), findsNothing);
    },
  );

  testWidgets('AI Coach remains back-navigable while access is resolving', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                key: const Key('open-loading-coach'),
                onPressed: () => context.push('/intelligence-center'),
                child: const Text('Open coach'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: Scaffold(body: Text('Coach')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            const AsyncLoading(),
          ),
          aiCoachCreditAccessProvider.overrideWithValue(const AsyncLoading()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/intelligence-center'));
    await tester.pump();
    // The access-checking state intentionally owns an indeterminate progress
    // indicator, so pumpAndSettle would wait forever here.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PremiumRouteGlassGate), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-access-checking')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('premium-route-loading-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-loading-coach')), findsOneWidget);
    expect(find.text('Coach'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
