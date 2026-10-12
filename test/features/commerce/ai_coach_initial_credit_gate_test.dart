import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Map<String, Object?> credits(int amount) => {
  'credits': {'total_remaining': amount},
};

Future<GoRouter> mountGate(
  WidgetTester tester,
  Stream<String?> owners,
  Future<Object?> Function() load,
) async {
  final router = GoRouter(
    initialLocation: '/coach',
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
        aiCoachUsageStatusLoaderProvider.overrideWithValue(load),
      ],
      child: MaterialApp.router(
        theme: BilFlagshipTheme.light(),
        locale: const Locale('en'),
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
