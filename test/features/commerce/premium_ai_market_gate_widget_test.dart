import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _prepaidOwnerA = 'prepaid-owner-a';
const _prepaidOwnerB = 'prepaid-owner-b';
const _prepaidAction = Key('actual-prepaid-protected-action');

Map<String, Object?> _prepaidUsage({
  Object? paid = 2500,
  Object? included = 0,
  Object? total = 2500,
}) => {
  'plan': 'free',
  'credits': {
    'paid_remaining': paid,
    'included_remaining': included,
    'total_remaining': total,
  },
};

final class _PendingPrepaidUsage {
  _PendingPrepaidUsage(this.owner, this.visit);
  final String? owner;
  final int visit;
  final result = Completer<Object?>();
}

// Only I/O loaders are replaced: owner visits, quota parsing, snapshot lifetime,
// subscription observation and route access all use the production providers.
final class _PrepaidGateFixture {
  _PrepaidGateFixture(this.response) {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_prepaidOwnerA),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() async {
          subscriptionLoads++;
          return SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: EntitlementAuthority.verifiedServer,
            isPurchasable: false,
            canRestorePurchases: false,
          );
        }),
        storefrontTargetPlanProvider.overrideWith(
          (_) async => CommercePlan.premiumAiCoach,
        ),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(() async {
          usageLoads++;
          if (failUsage) throw StateError('synthetic quota unavailable');
          if (delayUsage) {
            final request = _PendingPrepaidUsage(
              container.read(verifiedEntitlementOwnerIdProvider),
              container.read(verifiedEntitlementOwnerVisitProvider),
            );
            pending.add(request);
            return request.result.future;
          }
          return response;
        }),
      ],
    );
  }

  final owners = StreamController<String?>.broadcast(sync: true);
  late final ProviderContainer container;
  DateTime now = DateTime.utc(2026, 11, 19, 8);
  Object? response;
  bool delayUsage = false;
  bool failUsage = false;
  int usageLoads = 0;
  int subscriptionLoads = 0;
  int protectedTaps = 0;
  final pending = <_PendingPrepaidUsage>[];

  AiCoachAccessSnapshotStore get snapshot =>
      container.read(aiCoachAccessSnapshotStoreProvider);
  bool get freshPrepaid => snapshot.hasFreshPrepaid(
    ownerId: container.read(verifiedEntitlementOwnerIdProvider),
    ownerVisit: container.read(verifiedEntitlementOwnerVisitProvider),
    now: now,
  );

  Future<void> mount(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: Scaffold(
              body: Center(
                child: FilledButton(
                  key: _prepaidAction,
                  onPressed: () => protectedTaps++,
                  child: const Text('Verified prepaid Coach action'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> emitOwner(WidgetTester tester, String? owner) async {
    owners.add(owner);
    await tester.pump();
    await tester.pump();
  }

  void refreshUsage() => container
      .read(aiCoachUsageRefreshProvider.notifier)
      .requestAuthoritativeReload();

  Future<void> close(WidgetTester tester) async {
    for (final request in pending) {
      if (!request.result.isCompleted) {
        request.result.complete(_prepaidUsage(paid: 0, total: 0));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
    await owners.close();
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  Future<void> pumpGate(
    WidgetTester tester, {
    required CommercePlan storefrontPlan,
    Locale locale = const Locale('en'),
    bool creditAccess = false,
    CommercePlan subscriptionPlan = CommercePlan.free,
    PremiumGateFeature feature = PremiumGateFeature.aiCoach,
    Widget? child,
  }) async {
    final subscriptionState = subscriptionPlan == CommercePlan.free
        ? SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: EntitlementAuthority.verifiedServer,
            isPurchasable: false,
            canRestorePurchases: false,
          )
        : SubscriptionState(
            plan: subscriptionPlan,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            currentPeriodEndsAt: DateTime.now().toUtc().add(
              const Duration(days: 30),
            ),
            isPurchasable: true,
            canRestorePurchases: true,
          );
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey('gate-${storefrontPlan.name}-${feature.name}'),
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            "golden-gate-synthetic-member",
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => subscriptionState,
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => storefrontPlan,
          ),
          aiCoachCreditAccessProvider.overrideWith((_) async => creditAccess),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            ThemeData(),
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          builder: (context, child) => visualEvidenceTextSurface(
            child,
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          home: PremiumRouteGlassGate(
            feature: feature,
            child:
                child ??
                const ColoredBox(
                  key: ValueKey('unlocked-ai-coach'),
                  color: Colors.white,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pending entitlement never flashes an upgrade offer', (
    tester,
  ) async {
    final subscription = Completer<SubscriptionState>();
    final credits = Completer<bool>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            "golden-gate-synthetic-member",
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) => subscription.future,
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premiumAiCoach,
          ),
          aiCoachCreditAccessProvider.overrideWith((_) => credits.future),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: ColoredBox(
              key: ValueKey('pending-ai-coach'),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('ai-coach-access-checking-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-access-checking')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsNothing,
    );
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Get AI Boost'), findsNothing);

    subscription.complete(
      SubscriptionState(
        plan: CommercePlan.premiumAiCoach,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        currentPeriodEndsAt: DateTime.now().toUtc().add(
          const Duration(days: 30),
        ),
        isPurchasable: true,
        canRestorePurchases: true,
      ),
    );
    credits.complete(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pending-ai-coach')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-access-checking')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsNothing,
    );
  });

  testWidgets(
    'malformed actual quota shows retry, then valid server proof opens Coach',
    (tester) async {
      Object? value = {
        'credits': {'total_remaining': '2500'},
      };
      var protectedTaps = 0;
      var loads = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'quota-fixture',
            ),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(() async {
              loads++;
              return value;
            }),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: Scaffold(
                body: FilledButton(
                  key: const Key('actual-quota-protected-action'),
                  onPressed: () => protectedTaps++,
                  child: const Text('Coach action'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('premium-route-access-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(
        find.byKey(const Key('actual-quota-protected-action')).hitTestable(),
        findsNothing,
      );
      value = {
        'credits': {'total_remaining': 100},
      };
      await tester.tap(find.byKey(const Key('premium-route-access-retry')));
      await tester.pumpAndSettle();
      expect(loads, 2);
      await tester.tap(find.byKey(const Key('actual-quota-protected-action')));
      expect(protectedTaps, 1);
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
    },
  );

  testWidgets(
    'verified zero then malformed or failed quota shows neutral actual gate',
    (tester) async {
      Object? value = {
        'credits': {'total_remaining': 0},
      };
      var fail = false;
      var protectedTaps = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'quota-zero-fixture',
            ),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(() async {
              if (fail) throw StateError('temporary quota outage');
              return value;
            }),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: Scaffold(
                body: FilledButton(
                  key: const Key('quota-zero-protected-action'),
                  onPressed: () => protectedTaps++,
                  child: const Text('Coach action'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PremiumRouteGlassGate)),
      );
      expect(
        find.byKey(const Key('premium-route-upgrade-cta')),
        findsOneWidget,
      );
      value = {
        'credits': {'total_remaining': '2500'},
      };
      container.invalidate(aiCoachCreditAccessProvider);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('premium-route-access-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(
        find.byKey(const Key('quota-zero-protected-action')).hitTestable(),
        findsNothing,
      );
      fail = true;
      await tester.tap(find.byKey(const Key('premium-route-access-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('premium-route-access-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('premium-route-upgrade-cta')), findsNothing);
      expect(protectedTaps, 0);
      fail = false;
      value = {
        'credits': {'total_remaining': 100},
      };
      await tester.tap(find.byKey(const Key('premium-route-access-retry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quota-zero-protected-action')));
      expect(protectedTaps, 1);
    },
  );

  testWidgets(
    'AI credit lookup error shows neutral retry and never a purchase CTA',
    (tester) async {
      var creditLookupFails = true;
      var creditLookupAttempts = 0;
      var protectedTaps = 0;
      final activeSubscription = SubscriptionState(
        plan: CommercePlan.premiumAiCoach,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        currentPeriodEndsAt: DateTime.now().toUtc().add(
          const Duration(days: 30),
        ),
        isPurchasable: true,
        canRestorePurchases: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              "golden-gate-synthetic-member",
            ),
            verifiedSubscriptionStateProvider.overrideWith(
              (_) async => activeSubscription,
            ),
            storefrontTargetPlanProvider.overrideWith(
              (_) async => CommercePlan.premiumAiCoach,
            ),
            aiCoachCreditAccessProvider.overrideWith((_) async {
              creditLookupAttempts += 1;
              if (creditLookupFails) {
                throw StateError('usage status unavailable');
              }
              return true;
            }),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('credit-error-protected-content'),
                    onPressed: () => protectedTaps += 1,
                    child: const Text('PROTECTED AI COACH ACTION'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Get AI Boost'), findsNothing);
      expect(creditLookupAttempts, 1);
      // Failed verification must not even mount the private action. The
      // retry below then proves that the actual action works after authority
      // returns, without suppressing hit-test failures.
      expect(
        find.byKey(const ValueKey('credit-error-protected-content')),
        findsNothing,
      );
      expect(find.text('PROTECTED AI COACH ACTION'), findsNothing);
      expect(protectedTaps, 0);

      creditLookupFails = false;
      await tester.tap(
        find.byKey(const ValueKey('premium-route-access-retry')),
      );
      await tester.pumpAndSettle();

      expect(creditLookupAttempts, 2);
      expect(
        find.byKey(const ValueKey('credit-error-protected-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('credit-error-protected-content')),
      );
      expect(protectedTaps, 1);
    },
  );

  testWidgets('verified Boost does not depend on a subscription lookup', (
    tester,
  ) async {
    try {
      var subscriptionLookupAttempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              "golden-gate-synthetic-member",
            ),
            verifiedSubscriptionStateProvider.overrideWith((_) async {
              subscriptionLookupAttempts += 1;
              throw StateError('subscription unavailable');
            }),
            storefrontTargetPlanProvider.overrideWith((_) async {
              throw StateError('storefront unavailable');
            }),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(
              () async => _prepaidUsage(),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: ColoredBox(
                key: ValueKey('subscription-error-protected-content'),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(subscriptionLookupAttempts, 0);
      expect(
        find.byKey(const ValueKey('subscription-error-protected-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      expect(find.text('Get AI Boost'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('no tokens offers Boost without requiring any subscription', (
    tester,
  ) async {
    await pumpGate(tester, storefrontPlan: CommercePlan.premiumAiCoach);

    expect(find.text('Get AI Boost'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('BIL AI BOOST'), findsOneWidget);
    expect(find.text('BIL PREMIUM AI COACH'), findsNothing);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.textContaining('non-expiring'), findsWidgets);
  });

  testWidgets('free AI Coach gate back action returns to the dashboard', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/intelligence-center',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) =>
              const Scaffold(body: Text('Dashboard destination')),
        ),
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const PremiumRouteGlassGate(
            feature: PremiumGateFeature.aiCoach,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            "golden-gate-synthetic-member",
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => FreePlan.createState(),
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premiumAiCoach,
          ),
          aiCoachCreditAccessProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp.router(
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
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('premium-route-back')), findsOneWidget);
    expect(find.text('Get AI Boost'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('premium-route-back')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard destination'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('token storefront offers Boost at an exhausted balance', (
    tester,
  ) async {
    await pumpGate(tester, storefrontPlan: CommercePlan.premium);

    expect(find.text('Get AI Boost'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Global multilingual voice'), findsOneWidget);
  });

  testWidgets('glass names the subscription family returned by the store', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.weeklyReport,
    );
    expect(find.text('BIL PREMIUM AI COACH'), findsOneWidget);

    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.weeklyReport,
    );
    expect(find.text('BIL PREMIUM'), findsOneWidget);
    expect(find.text('BIL PREMIUM AI COACH'), findsNothing);
  });

  testWidgets('Arabic AI gate has no English fallback', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      locale: const Locale('ar'),
    );

    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Get AI Boost'), findsNothing);
    expect(
      find.text(RuntimeCopy.resolve('Get AI Boost', 'ar')!),
      findsOneWidget,
    );
  });

  testWidgets('regular Premium does not unlock AI Coach', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      subscriptionPlan: CommercePlan.premium,
    );

    expect(find.text('Get AI Boost'), findsOneWidget);
  });

  testWidgets('regular Premium plus verified Boost unlocks only AI Coach', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      subscriptionPlan: CommercePlan.premium,
      creditAccess: true,
    );

    expect(find.byKey(const ValueKey('unlocked-ai-coach')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsNothing,
    );
  });

  testWidgets('Free opens community without a membership offer', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.community,
      child: const ColoredBox(
        key: ValueKey('community-preview-content'),
        color: Color(0xFFE9FAFF),
      ),
    );

    expect(
      find.byKey(const ValueKey('community-preview-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsNothing,
    );
    expect(find.text('Friends and requests'), findsNothing);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Plans'), findsNothing);
  });

  testWidgets('glass gate shows at most one Premium label per route', (
    tester,
  ) async {
    Future<void> expectSinglePremiumLabel({
      required CommercePlan storefrontPlan,
      required PremiumGateFeature feature,
    }) async {
      await pumpGate(tester, storefrontPlan: storefrontPlan, feature: feature);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (widget) => widget.key != const Key('premium-route-public-title'),
          )
          .where(
            (widget) => (widget.data ?? '').toLowerCase().contains('premium'),
          );
      expect(labels, hasLength(feature == PremiumGateFeature.aiCoach ? 0 : 1));
    }

    await expectSinglePremiumLabel(
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.premium,
    );
    await expectSinglePremiumLabel(
      storefrontPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.aiCoach,
    );
    await expectSinglePremiumLabel(
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.contentPacks,
    );
  });

  testWidgets('verified Boost never unlocks a Premium entitlement', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      creditAccess: true,
      feature: PremiumGateFeature.weeklyReport,
      child: const ColoredBox(
        key: ValueKey('boost-cannot-unlock-weekly-report'),
        color: Colors.white,
      ),
    );

    expect(
      find.byKey(const ValueKey('boost-cannot-unlock-weekly-report')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsOneWidget,
    );
  });

  testWidgets('Premium AI Coach inherits and opens community', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      subscriptionPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.community,
      child: const ColoredBox(
        key: ValueKey('community-preview-content'),
        color: Color(0xFFE9FAFF),
      ),
    );

    expect(
      find.byKey(const ValueKey('community-preview-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsNothing,
    );
  });

  testWidgets('active AI subscription with allowance unlocks AI Coach', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      subscriptionPlan: CommercePlan.premiumAiCoach,
      creditAccess: true,
    );

    expect(find.byKey(const ValueKey('unlocked-ai-coach')), findsOneWidget);
    expect(find.text('Get AI Boost'), findsNothing);
  });

  testWidgets('active AI subscription at zero shows Boost only', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      subscriptionPlan: CommercePlan.premiumAiCoach,
    );

    expect(
      find.byKey(const ValueKey('premium-route-upgrade-cta')),
      findsOneWidget,
    );
    expect(find.text('Get AI Boost'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsNothing);
    expect(find.text('BIL AI BOOST'), findsOneWidget);
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('server AI grant opens coach in profitable storefront', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      creditAccess: true,
    );

    expect(find.byKey(const ValueKey('unlocked-ai-coach')), findsOneWidget);
    expect(find.text('Get AI Boost'), findsNothing);
  });

  testWidgets(
    'zero, Boost purchase, consumption to zero, and subscription restore refresh gate',
    (tester) async {
      final accessState = StateProvider<bool>((_) => false);
      final planState = StateProvider<CommercePlan>((_) => CommercePlan.free);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              "golden-gate-synthetic-member",
            ),
            verifiedSubscriptionStateProvider.overrideWith((ref) async {
              final plan = ref.watch(planState);
              return plan == CommercePlan.free
                  ? FreePlan.createState()
                  : SubscriptionState(
                      plan: plan,
                      entitlements: const {},
                      authority: EntitlementAuthority.verifiedServer,
                      currentPeriodEndsAt: DateTime.now().toUtc().add(
                        const Duration(days: 30),
                      ),
                      isPurchasable: true,
                      canRestorePurchases: true,
                    );
            }),
            storefrontTargetPlanProvider.overrideWith(
              (_) async => CommercePlan.premiumAiCoach,
            ),
            aiCoachCreditAccessProvider.overrideWith(
              (ref) async => ref.watch(accessState),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: ColoredBox(
                key: ValueKey('dynamic-ai-coach'),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PremiumRouteGlassGate)),
      );

      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsOneWidget,
      );

      container.read(accessState.notifier).state = true;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );

      container.read(accessState.notifier).state = false;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsOneWidget,
      );

      container.read(planState.notifier).state = CommercePlan.premiumAiCoach;
      container.read(accessState.notifier).state = true;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );

      container.read(planState.notifier).state = CommercePlan.free;
      container.read(accessState.notifier).state = false;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'locked route exposes its title without mounting private content',
    (tester) async {
      var protectedTaps = 0;
      await pumpGate(
        tester,
        storefrontPlan: CommercePlan.premium,
        feature: PremiumGateFeature.weeklyReport,
        child: Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('protected-action'),
              onPressed: () => protectedTaps += 1,
              child: const Text('PROTECTED DASHBOARD ACTION'),
            ),
          ),
        ),
      );

      expect(find.text('PROTECTED DASHBOARD ACTION'), findsNothing);
      expect(find.text('Weekly report'), findsOneWidget);
      expect(find.byKey(const ValueKey('protected-action')), findsNothing);
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(PremiumRouteGlassGate)),
        isNot(isSemantics(label: 'PROTECTED DASHBOARD ACTION')),
      );
      await tester.tap(find.byKey(const Key('premium-route-public-title')));
      semantics.dispose();
      await tester.pump();
      expect(protectedTaps, 0);
    },
  );

  test(
    'prepaid provenance accepts only an exact reserved-aware paid-only wire',
    () {
      final requestedAt = DateTime.utc(2026, 11, 19, 8);
      VerifiedPrepaidAiCredit? proof(
        Object? value, {
        String owner = _prepaidOwnerA,
        int visit = 2,
        int generation = 7,
      }) => VerifiedPrepaidAiCredit.fromUsageStatus(
        value,
        ownerId: owner,
        ownerVisit: visit,
        generation: generation,
        requestedAt: requestedAt,
      );
      for (final wire in [
        _prepaidUsage(),
        _prepaidUsage(paid: 1.5, total: 1.5),
      ]) {
        final accepted = proof(wire);
        expect(accepted, isNotNull);
        expect(accepted!.ownerId, _prepaidOwnerA);
        expect(accepted.ownerVisit, 2);
        expect(accepted.generation, 7);
        expect(accepted.requestedAt, requestedAt);
        expect(
          accepted.expiresAt,
          requestedAt.add(const Duration(seconds: 30)),
        );
      }
      final rejected = <String, Object?>{
        'missing body': null,
        'non-map body': [],
        'missing credits': {},
        'non-map credits': {'credits': []},
        'missing paid breakdown': {
          'credits': {'total_remaining': 2500},
        },
        'missing included breakdown': {
          'credits': {'paid_remaining': 2500, 'total_remaining': 2500},
        },
        'missing total': {
          'credits': {'paid_remaining': 2500, 'included_remaining': 0},
        },
        'string paid': _prepaidUsage(paid: '2500'),
        'boolean included': _prepaidUsage(included: false),
        'string total': _prepaidUsage(total: '2500'),
        'zero': _prepaidUsage(paid: 0, total: 0),
        'negative': _prepaidUsage(paid: -1, total: -1),
        'nonfinite paid': _prepaidUsage(paid: double.nan, total: double.nan),
        'infinite paid': _prepaidUsage(
          paid: double.infinity,
          total: double.infinity,
        ),
        'nonfinite included': _prepaidUsage(included: double.nan),
        'nonfinite total': _prepaidUsage(total: double.infinity),
        'included only': _prepaidUsage(paid: 0, included: 2500),
        'mixed included and paid': _prepaidUsage(paid: 2000, included: 500),
        'negative included': _prepaidUsage(included: -1),
        'reserved-aware total differs': _prepaidUsage(total: 2499),
      };
      for (final entry in rejected.entries) {
        expect(proof(entry.value), isNull, reason: entry.key);
      }
      expect(proof(_prepaidUsage(), owner: '  '), isNull);
      expect(proof(_prepaidUsage(), visit: -1), isNull);
      expect(proof(_prepaidUsage(), generation: 0), isNull);
    },
  );

  test(
    'prepaid shortcut requires current authority, visit, generation and request-time freshness',
    () {
      final requestedAt = DateTime.utc(2026, 11, 19, 8);
      final proof = VerifiedPrepaidAiCredit.fromUsageStatus(
        _prepaidUsage(),
        ownerId: _prepaidOwnerA,
        ownerVisit: 2,
        generation: 7,
        requestedAt: requestedAt,
      )!;
      AiCoachAccessSnapshotStore fresh() => AiCoachAccessSnapshotStore()
        ..verifiedAccess = true
        ..usageResponseFresh = true
        ..generation = 7
        ..usageRequestedAt = requestedAt
        ..prepaidProof = proof;
      bool current(
        AiCoachAccessSnapshotStore value, {
        String? owner = _prepaidOwnerA,
        int visit = 2,
        DateTime? at,
      }) => value.hasFreshPrepaid(
        ownerId: owner,
        ownerVisit: visit,
        now: at ?? requestedAt,
      );
      expect(current(fresh()), isTrue);
      expect(
        current(
          fresh(),
          at: proof.expiresAt.subtract(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
      expect(
        current(
          fresh(),
          at: requestedAt.subtract(const Duration(microseconds: 1)),
        ),
        isFalse,
      );
      expect(current(fresh(), at: proof.expiresAt), isFalse);
      expect(
        current(fresh(), at: proof.expiresAt.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(current(fresh(), owner: null), isFalse);
      expect(current(fresh(), owner: _prepaidOwnerB), isFalse);
      expect(current(fresh(), visit: 3), isFalse);
      for (final invalid in [
        fresh()..verifiedAccess = false,
        fresh()..verifiedAccess = null,
        fresh()..usageResponseFresh = false,
        fresh()..generation = 8,
        fresh()..usageRequestedAt = null,
        fresh()
          ..usageRequestedAt = requestedAt.add(const Duration(microseconds: 1)),
        fresh()..prepaidProof = null,
      ]) {
        expect(current(invalid), isFalse);
      }
    },
  );

  testWidgets(
    'initial pending quota and owned prepaid expiry refresh never observe subscriptions',
    (tester) async {
      final fixture = _PrepaidGateFixture(_prepaidUsage())..delayUsage = true;
      try {
        await fixture.mount(tester, settle: false);
        expect(fixture.pending, hasLength(1));
        expect(fixture.subscriptionLoads, 0);
        expect(find.byKey(_prepaidAction), findsNothing);
        expect(
          find.byKey(const Key('ai-coach-access-checking-surface')),
          findsOneWidget,
        );
        fixture.pending.single.result.complete(_prepaidUsage());
        await tester.pumpAndSettle();
        expect(fixture.freshPrepaid, isTrue);
        expect(fixture.subscriptionLoads, 0);
        await tester.tap(find.byKey(_prepaidAction));
        expect(fixture.protectedTaps, 1);
        final oldProof = fixture.snapshot.prepaidProof!;
        fixture.now = oldProof.expiresAt;
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(fixture.usageLoads, 2);
        expect(fixture.pending, hasLength(2));
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.snapshot.usageResponseFresh, isFalse);
        expect(fixture.subscriptionLoads, 0);
        expect(find.byKey(_prepaidAction).hitTestable(), findsNothing);
        fixture.pending.last.result.complete(_prepaidUsage());
        await tester.pumpAndSettle();
        expect(fixture.freshPrepaid, isTrue);
        expect(
          fixture.snapshot.prepaidProof!.generation,
          oldProof.generation + 1,
        );
        expect(fixture.snapshot.prepaidProof!.requestedAt, oldProof.expiresAt);
        expect(fixture.subscriptionLoads, 0);
        expect(find.byKey(_prepaidAction).hitTestable(), findsOneWidget);
        fixture.now = fixture.now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(fixture.usageLoads, 2);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  for (final entry in <String, Object?>{
    'included allowance': _prepaidUsage(paid: 0, included: 2500),
    'mixed allowance and prepaid': _prepaidUsage(paid: 2000, included: 500),
    'positive total without paid provenance': {
      'credits': {'total_remaining': 2500},
    },
  }.entries) {
    testWidgets('${entry.key} retains the actual subscription observer', (
      tester,
    ) async {
      final fixture = _PrepaidGateFixture(entry.value);
      try {
        await fixture.mount(tester);
        expect(fixture.snapshot.verifiedAccess, isTrue);
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.freshPrepaid, isFalse);
        expect(fixture.subscriptionLoads, greaterThan(0));
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });
  }

  testWidgets(
    'fresh prepaid cannot cross real owner ABA visits or accept retired B quota',
    (tester) async {
      final fixture = _PrepaidGateFixture(_prepaidUsage());
      try {
        await fixture.mount(tester);
        final firstA = fixture.snapshot;
        expect(fixture.freshPrepaid, isTrue);
        expect(fixture.subscriptionLoads, 0);
        fixture.delayUsage = true;
        await fixture.emitOwner(tester, _prepaidOwnerB);
        expect(fixture.pending, hasLength(1));
        expect(
          (fixture.pending.single.owner, fixture.pending.single.visit),
          (_prepaidOwnerB, 1),
        );
        // This owned B future will deliberately fail its superseded-read guard.
        fixture.container.read(aiCoachCreditAccessProvider.future).ignore();
        expect(find.byKey(_prepaidAction), findsNothing);
        await fixture.emitOwner(tester, _prepaidOwnerA);
        expect(fixture.pending, hasLength(2));
        expect(
          (fixture.pending.last.owner, fixture.pending.last.visit),
          (_prepaidOwnerA, 2),
        );
        expect(identical(fixture.snapshot, firstA), isFalse);
        expect(
          firstA.hasFreshPrepaid(
            ownerId: _prepaidOwnerA,
            ownerVisit: 2,
            now: fixture.now,
          ),
          isFalse,
        );
        fixture.pending.first.result.complete(_prepaidUsage());
        await tester.pump();
        await tester.pump();
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.freshPrepaid, isFalse);
        expect(find.byKey(_prepaidAction), findsNothing);
        fixture.pending.last.result.complete(_prepaidUsage());
        await tester.pumpAndSettle();
        expect(fixture.freshPrepaid, isTrue);
        expect(fixture.snapshot.prepaidProof!.ownerId, _prepaidOwnerA);
        expect(fixture.snapshot.prepaidProof!.ownerVisit, 2);
        expect(fixture.subscriptionLoads, 0);
        expect(find.byKey(_prepaidAction).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets('logout retires prepaid proof and its owned refresh timer', (
    tester,
  ) async {
    final fixture = _PrepaidGateFixture(_prepaidUsage());
    try {
      await fixture.mount(tester);
      expect(fixture.freshPrepaid, isTrue);
      await fixture.emitOwner(tester, null);
      await tester.pumpAndSettle();
      expect(fixture.snapshot.prepaidProof, isNull);
      expect(fixture.freshPrepaid, isFalse);
      expect(find.byKey(_prepaidAction), findsNothing);
      fixture.now = fixture.now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      expect(fixture.usageLoads, 1);
      expect(fixture.subscriptionLoads, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets(
    'refund refresh clears prepaid proof before response and zero blocks the action',
    (tester) async {
      final fixture = _PrepaidGateFixture(_prepaidUsage());
      try {
        await fixture.mount(tester);
        expect(fixture.freshPrepaid, isTrue);
        fixture.delayUsage = true;
        fixture.refreshUsage();
        await tester.pump();
        await tester.pump();
        expect(fixture.pending, hasLength(1));
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.snapshot.usageResponseFresh, isFalse);
        expect(find.byKey(_prepaidAction).hitTestable(), findsNothing);
        fixture.pending.single.result.complete(
          _prepaidUsage(paid: 0, total: 0),
        );
        await tester.pumpAndSettle();
        expect(fixture.snapshot.verifiedAccess, isFalse);
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.freshPrepaid, isFalse);
        expect(find.byKey(_prepaidAction).hitTestable(), findsNothing);
        expect(
          find.byKey(const Key('premium-route-upgrade-cta')),
          findsOneWidget,
        );
        expect(fixture.subscriptionLoads, greaterThan(0));
        expect(fixture.protectedTaps, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'failed same-owner refresh retains no prepaid optimization proof',
    (tester) async {
      final fixture = _PrepaidGateFixture(_prepaidUsage());
      try {
        await fixture.mount(tester);
        expect(fixture.freshPrepaid, isTrue);
        fixture.failUsage = true;
        fixture.refreshUsage();
        await tester.pumpAndSettle();
        expect(fixture.snapshot.prepaidProof, isNull);
        expect(fixture.snapshot.usageResponseFresh, isFalse);
        expect(fixture.freshPrepaid, isFalse);
        expect(fixture.subscriptionLoads, greaterThan(0));
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets('premium route glass visual proof', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.weeklyReport,
      child: const _PremiumGlassFixture(),
    );

    await expectLater(
      find.byType(PremiumRouteGlassGate),
      matchesGoldenFile('goldens/premium_route_glass_gate.png'),
    );
  });
}

class _PremiumGlassFixture extends StatelessWidget {
  const _PremiumGlassFixture();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly report')),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FAFF), Color(0xFFF8E9FF), Color(0xFFFFF4D6)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'YOUR ORIGINAL REPORT',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          for (final item in const [
            ('Calories', '1,840 kcal', Color(0xFF18A9D5)),
            ('Protein', '126 g', Color(0xFF8A5CE6)),
            ('Progress', '+ 4.8%', Color(0xFFE8A31A)),
          ])
            Card(
              color: item.$3,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
