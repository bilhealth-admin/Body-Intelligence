import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/support/community_rewards_rpc_fixture.dart';

const _ownerA = '56000000-0000-4000-8000-000000000001';
const _ownerB = '56000000-0000-4000-8000-000000000002';

class _SecureStore implements AdminEntitlementSecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reads = <String>[];
  late DateTime now;
  late DateTime periodEnd;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.now().toUtc();
    periodEnd = now.add(const Duration(hours: 1));
    await Supabase.initialize(
      url: 'https://personal-plan-authority.invalid',
      publishableKey: 'synthetic-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          reads.add(request.url.path);
          Object? body;
          if (request.url.path == '/rest/v1/bil_ai_closed_test_grants') {
            body = <Object>[];
          } else if (request.url.path == '/rest/v1/bil_subscriptions') {
            expect(request.url.queryParameters['owner_id'], 'eq.$_ownerA');
            body = [
              {
                'owner_id': _ownerA,
                'plan_id': 'premium',
                'provider': 'apple',
                'product_id': 'bil_premium_annual',
                'lifecycle': 'active',
                'started_at': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'expires_at': periodEnd.toIso8601String(),
                'verified_at': now.toIso8601String(),
                'revision': 134,
              },
            ];
          } else if (request.url.path ==
              '/rest/v1/rpc/bil_get_my_admin_subscription') {
            body = null;
          } else {
            throw StateError(
              'Unexpected fixture transport: ${request.url.path}',
            );
          }
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'active Apple annual row opens both Personal plan gates across resume and rejects a new owner',
    (tester) async {
      final client = Supabase.instance.client;
      final secure = _SecureStore();
      final repository = ServerEntitlementRepository(
        adminContinuityStore: AdminEntitlementContinuityStore(
          secureStore: secure,
        ),
        subscriptionContinuityStore: VerifiedEntitlementContinuityStore(
          secureStore: secure,
        ),
      );
      final paid = await tester.runAsync(() async {
        await client.auth.recoverSession(
          jsonEncode(RewardsRpcFixture.session(_ownerA)),
        );
        return repository.current();
      });
      expect(reads, contains('/rest/v1/bil_subscriptions'));
      expect(reads, contains('/rest/v1/rpc/bil_get_my_admin_subscription'));
      expect(paid!.authority, EntitlementAuthority.verifiedServer);
      expect(paid.plan, CommercePlan.premium);
      expect(paid.currentPeriodEndsAt, periodEnd);

      var loads = 0;
      Completer<SubscriptionState>? pending;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() {
            loads++;
            if (client.auth.currentUser?.id == _ownerB) {
              return Future.value(
                SubscriptionState(
                  plan: CommercePlan.free,
                  entitlements: const {},
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: false,
                  canRestorePurchases: false,
                ),
              );
            }
            return pending?.future ?? Future.value(paid);
          }),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/plan',
        routes: [
          for (final path in ['/plan', '/smart-plan'])
            GoRoute(
              path: path,
              builder: (_, _) => PremiumRouteGlassGate(
                feature: PremiumGateFeature.personalPlan,
                child: Text(
                  'Authorized $path',
                  key: ValueKey('authorized-$path'),
                ),
              ),
            ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
      expect(find.byKey(const ValueKey('authorized-/plan')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );

      router.go('/smart-plan');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('authorized-/smart-plan')),
        findsOneWidget,
      );
      final beforeResume = loads;
      pending = Completer<SubscriptionState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(loads, greaterThan(beforeResume));
      expect(
        find.byKey(const ValueKey('authorized-/smart-plan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      pending.complete(paid);
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pumpAndSettle();

      pending = Completer<SubscriptionState>();
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      pending.completeError(StateError('synthetic authority read failure'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      pending = Completer<SubscriptionState>();
      await tester.tap(
        find.byKey(const ValueKey('premium-route-access-retry')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsNothing,
      );
      pending.complete(paid);
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('authorized-/smart-plan')),
        findsOneWidget,
      );

      await tester.runAsync(
        () => client.auth.recoverSession(
          jsonEncode(RewardsRpcFixture.session(_ownerB)),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(container.read(verifiedEntitlementOwnerIdProvider), _ownerB);
      expect(
        find.byKey(const ValueKey('authorized-/smart-plan')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('premium-route-upgrade-cta')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await tester.pump();
    },
  );
}
