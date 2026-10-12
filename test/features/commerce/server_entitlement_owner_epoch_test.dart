import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../community/support/community_rewards_rpc_fixture.dart';

class _Secure implements AdminEntitlementSecureStore {
  final values = <String, String>{};
  Completer<String?>? pending;
  final entered = Completer<void>();
  @override
  Future<String?> read(String key) {
    final held = pending;
    if (held == null) return Future.value(values[key]);
    if (!entered.isCompleted) entered.complete();
    return held.future;
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var requests = 0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://entitlement-owner.invalid',
      publishableKey: 'synthetic-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode([]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final roundTrip in [false, true]) {
    test(
      'cold entitlement lease cannot return after account transition ABA=$roundTrip',
      () async {
        final owner = roundTrip
            ? '44000000-0000-4000-8000-000000000001'
            : '44000000-0000-4000-8000-000000000002';
        final client = Supabase.instance.client;
        await client.auth.recoverSession(
          jsonEncode(RewardsRpcFixture.session(owner)),
        );
        final secure = _Secure();
        final store = AdminEntitlementContinuityStore(secureStore: secure);
        final now = DateTime.now().toUtc();
        await store.remember(
          ownerId: owner,
          now: now,
          state: SubscriptionState(
            plan: CommercePlan.premiumAiCoach,
            entitlements: PaidPlanCatalog.composedEntitlementsFor(
              CommercePlan.premiumAiCoach,
            ),
            authority: EntitlementAuthority.verifiedServer,
            startedAt: now.subtract(const Duration(days: 1)),
            currentPeriodEndsAt: now.add(const Duration(minutes: 5)),
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        );
        final original = secure.values.values.single;
        secure.pending = Completer<String?>();
        final count = requests;
        final pending = ServerEntitlementRepository(
          adminContinuityStore: store,
        ).current();
        final assertion = expectLater(
          pending,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await secure.entered.future;
        await client.auth.recoverSession(
          jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
        );
        if (roundTrip) {
          await client.auth.recoverSession(
            jsonEncode(RewardsRpcFixture.session(owner)),
          );
        }
        secure.pending!.complete(original);
        await assertion;
        expect(
          requests,
          count,
          reason: 'A retired request must not continue under the later session',
        );
      },
    );
  }

  test(
    'same-owner restoration keeps the valid cold lease without a network request',
    () async {
      const owner = '44000000-0000-4000-8000-000000000003';
      final client = Supabase.instance.client;
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(owner)),
      );
      final secure = _Secure();
      final store = AdminEntitlementContinuityStore(secureStore: secure);
      final now = DateTime.now().toUtc();
      final boundary = now.add(const Duration(minutes: 5));
      await store.remember(
        ownerId: owner,
        now: now,
        state: SubscriptionState(
          plan: CommercePlan.premiumAiCoach,
          entitlements: PaidPlanCatalog.composedEntitlementsFor(
            CommercePlan.premiumAiCoach,
          ),
          authority: EntitlementAuthority.verifiedServer,
          startedAt: now.subtract(const Duration(days: 1)),
          currentPeriodEndsAt: boundary,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
      );
      final original = secure.values.values.single;
      secure.pending = Completer<String?>();
      final count = requests;
      final pending = ServerEntitlementRepository(
        adminContinuityStore: store,
      ).current();
      await secure.entered.future;
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(owner)),
      );
      secure.pending!.complete(original);
      final state = await pending;
      expect(state.plan, CommercePlan.premiumAiCoach);
      expect(state.currentPeriodEndsAt, boundary);
      expect(requests, count);
    },
  );
}
