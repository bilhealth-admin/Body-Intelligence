import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _now = DateTime.utc(2026, 11, 19, 3);

Map<String, Object?> _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'public-synthetic-refresh-$owner',
    'token_type': 'bearer',
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

SubscriptionState _proof(DateTime until) => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  provider: SubscriptionProvider.apple,
  lifecycle: SubscriptionLifecycle.active,
  startedAt: _now.subtract(const Duration(days: 1)),
  currentPeriodEndsAt: until,
  verifiedAt: _now,
  isPurchasable: false,
  canRestorePurchases: true,
);

class _Secure implements AdminEntitlementSecureStore {
  final values = <String, String>{};
  Completer<void>? readGate;
  final entered = Completer<void>();

  @override
  Future<String?> read(String key) async {
    final gate = readGate;
    if (gate != null) {
      if (!entered.isCompleted) {
        entered.complete();
      }
      await gate.future;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Completer<void>? metadataGate;
  var authRequests = 0;
  var metadataRequests = 0;
  var terminal = false;
  var owner = '';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Real async setup/dispose keeps the SDK JSON isolate out of FakeAsync.
    await Supabase.initialize(
      url: 'https://offline-proof.invalid',
      publishableKey: 'public-synthetic-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          final path = request.url.path;
          if (path == '/auth/v1/token') {
            authRequests++;
            expect(request.url.queryParameters['grant_type'], 'refresh_token');
            // SDK 2.26 retries for 30s. A single bounded transport failure longer
            // than that window reaches its public refreshSession stream-error
            // path without internal SDK hooks, source edits, or an auth server.
            await Future<void>.delayed(const Duration(seconds: 31));
            return http.Response(
              jsonEncode({'message': 'Synthetic outage'}),
              503,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (path == '/auth/v1/logout') {
            return http.Response('', 204, request: request);
          }
          metadataRequests++;
          await metadataGate?.future;
          if (terminal) {
            final Object? body = switch (path) {
              '/rest/v1/bil_ai_closed_test_grants' => <Object?>[],
              '/rest/v1/bil_subscriptions' => [
                {
                  'owner_id': owner,
                  'plan_id': 'premium',
                  'provider': 'apple',
                  'lifecycle': 'revoked',
                  'revision': 2,
                  'started_at': _now
                      .subtract(const Duration(days: 1))
                      .toIso8601String(),
                  'expires_at': _now
                      .add(const Duration(days: 1))
                      .toIso8601String(),
                  'verified_at': _now.toIso8601String(),
                },
              ],
              '/rest/v1/rpc/bil_get_my_admin_subscription' => null,
              _ => throw StateError('Unexpected metadata route: $path'),
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          expect(
            path,
            anyOf(
              '/rest/v1/bil_ai_closed_test_grants',
              '/rest/v1/bil_subscriptions',
              '/rest/v1/rpc/bil_get_my_admin_subscription',
            ),
          );
          return http.Response(
            jsonEncode({'message': 'Synthetic metadata outage'}),
            503,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<ServerEntitlementRepository> repository(
    String id,
    _Secure secure, {
    DateTime? now,
    bool seed = true,
  }) async {
    owner = id;
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode(_session(id)),
    );
    final store = VerifiedEntitlementContinuityStore(secureStore: secure);
    if (seed) {
      await store.remember(
        ownerId: id,
        state: _proof(_now.add(const Duration(hours: 1))),
        now: _now,
      );
    }
    return ServerEntitlementRepository(
      adminContinuityStore: AdminEntitlementContinuityStore(
        secureStore: _Secure(),
      ),
      subscriptionContinuityStore: store,
      clock: () => now ?? _now,
    );
  }

  test(
    'public SDK retryable failure preserves verified normal read only',
    () async {
      const id = 'ab000000-0000-4000-8000-000000000001';
      final secure = _Secure();
      final repo = await repository(id, secure);
      final client = Supabase.instance.client;
      final errors = <Object>[];
      final errorDelivered = Completer<void>();
      final authObserver = client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object error, StackTrace _) {
          errors.add(error);
          if (!errorDelivered.isCompleted) {
            errorDelivered.complete();
          }
        },
      );
      final scope = ProviderContainer(retry: (_, _) => null);
      final ownerObserver = scope.listen(
        verifiedEntitlementOwnerProvider,
        (_, _) {},
      );
      final release = Completer<void>();
      secure.readGate = Completer<void>();
      Future<Object?> capture(Future<Object?> future) => future.then<Object?>(
        (value) => value,
        onError: (Object error) => error,
      );
      final normal = capture(repo.current());
      final strict = capture(
        CommunityOwnerOperation.run<int>(
          client: client,
          ownerId: id,
          action: (_) async {
            await release.future;
            return 9;
          },
        ),
      );
      Future<Object?>? checkout;
      Future<Object?>? storeRecovery;
      try {
        await secure.entered.future.timeout(const Duration(seconds: 3));
        await scope.pump();
        expect(scope.read(verifiedEntitlementOwnerProvider).requireValue, id);
        await expectLater(
          client.auth.refreshSession().timeout(const Duration(seconds: 40)),
          throwsA(isA<AuthRetryableFetchException>()),
        );
        await errorDelivered.future.timeout(const Duration(seconds: 3));
        expect(
          authRequests,
          1,
          reason: 'Exactly one synthetic auth refresh, no retry loop.',
        );
        expect(errors, hasLength(1));
        expect(client.auth.currentSession?.user.id, id);
        // Recovery starts after the SDK failure, so the real replaying stream
        // delivers its cached error to these fresh strict observers as well.
        metadataGate = Completer<void>();
        checkout = capture(repo.currentForExplicitCheckoutRecovery());
        storeRecovery = capture(repo.currentForExplicitStoreRecovery());
        await scope.pump();
        secure.readGate!.complete();
        metadataGate!.complete();
        release.complete();
        final state = await normal;
        expect(
          state,
          isA<SubscriptionState>(),
          reason:
              'A transport error must not cancel the existing verified read.',
        );
        final paid = state as SubscriptionState;
        expect(paid.plan, CommercePlan.premium);
        expect(paid.currentPeriodEndsAt, _now.add(const Duration(hours: 1)));
        expect(await strict, isA<CommunityOwnerOperationCancelled>());
        expect((await checkout as SubscriptionState).plan, CommercePlan.free);
        expect(await storeRecovery, isA<CommunityOwnerOperationCancelled>());
        await scope.pump();
        expect(scope.read(verifiedEntitlementOwnerProvider).hasError, isFalse);
        expect(scope.read(verifiedEntitlementOwnerProvider).requireValue, id);
        // A fresh read also sees the SDK's retained last stream error. It must
        // recover the same bounded proof, never require a new purchase/restore.
        expect((await repo.current()).plan, CommercePlan.premium);
      } finally {
        if (!secure.readGate!.isCompleted) {
          secure.readGate!.complete();
        }
        if (metadataGate != null && !metadataGate!.isCompleted) {
          metadataGate!.complete();
        }
        if (!release.isCompleted) {
          release.complete();
        }
        await Future.wait([normal, strict, ?checkout, ?storeRecovery]);
        metadataGate = null;
        ownerObserver.close();
        scope.dispose();
        await authObserver.cancel();
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'normal offline read cannot grant without proof or past exact expiry',
    () async {
      for (final seeded in [false, true]) {
        final repo = await repository(
          seeded
              ? 'ab000000-0000-4000-8000-000000000003'
              : 'ab000000-0000-4000-8000-000000000002',
          _Secure(),
          seed: seeded,
          now: seeded ? _now.add(const Duration(hours: 1)) : _now,
        );
        expect((await repo.current()).plan, CommercePlan.free);
      }
    },
  );

  test(
    'authoritative revocation clears cached proof and offline cannot revive it',
    () async {
      final secure = _Secure();
      final repo = await repository(
        'ab000000-0000-4000-8000-000000000004',
        secure,
      );
      expect((await repo.current()).plan, CommercePlan.premium);
      terminal = true;
      try {
        expect((await repo.current()).plan, CommercePlan.free);
        expect(secure.values, isEmpty);
      } finally {
        terminal = false;
      }
      expect((await repo.current()).plan, CommercePlan.free);
      expect(metadataRequests, greaterThan(0));
    },
  );
}
