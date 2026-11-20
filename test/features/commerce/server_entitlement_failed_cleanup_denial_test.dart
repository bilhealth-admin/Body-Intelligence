import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _start = DateTime.utc(2026, 11, 20, 21);

enum _Phase { paid5, revoked6, refunded6, stale5, paid7, offline }

class _Secure implements AdminEntitlementSecureStore {
  final values = <String, String>{};
  bool failDelete = false, failWrite = false;
  int deleteAttempts = 0, writeAttempts = 0;
  Completer<void>? holdPaid5Write;
  Completer<void>? paid5WriteEntered;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    writeAttempts++;
    final gate = holdPaid5Write;
    if (gate != null && (jsonDecode(value) as Map)['server_revision'] == 5) {
      holdPaid5Write = null;
      paid5WriteEntered!.complete();
      await gate.future;
    }
    if (failWrite) throw StateError('synthetic secure write failure');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteAttempts++;
    if (failDelete) throw StateError('synthetic secure delete failure');
    values.remove(key);
  }
}

Map<String, Object?> _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-only-$owner',
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

SubscriptionState _proof({int revision = 5}) => SubscriptionState(
  plan: CommercePlan.premiumAiCoach,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(
    CommercePlan.premiumAiCoach,
  ),
  authority: EntitlementAuthority.verifiedServer,
  provider: SubscriptionProvider.google,
  lifecycle: SubscriptionLifecycle.active,
  startedAt: _start.subtract(const Duration(days: 1)),
  currentPeriodEndsAt: _start.add(Duration(days: revision == 7 ? 2 : 1)),
  verifiedAt: _start.subtract(Duration(seconds: 10 - revision)),
  serverRevision: revision,
  storeOriginalTransactionId: 'synthetic-owned-annual-lineage',
  isPurchasable: false,
  canRestorePurchases: true,
);

class _Fixture {
  _Fixture(this.owner, this.secure) {
    store = VerifiedEntitlementContinuityStore(secureStore: secure);
    repository = ServerEntitlementRepository(
      subscriptionContinuityStore: store,
      adminContinuityStore: AdminEntitlementContinuityStore(
        secureStore: _Secure(),
      ),
      clock: () => now,
    );
  }
  final String owner;
  final _Secure secure;
  late final VerifiedEntitlementContinuityStore store;
  late final ServerEntitlementRepository repository;
  DateTime now = _start;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var owner = '';
  var phase = _Phase.paid5;
  var sequence = 0;
  final observedRevisions = <int, Completer<void>>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://denial-cleanup.invalid',
      publishableKey: 'synthetic-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          expect(request.url.host, 'denial-cleanup.invalid');
          final path = request.url.path;
          expect(
            path,
            anyOf(
              '/rest/v1/bil_ai_closed_test_grants',
              '/rest/v1/bil_subscriptions',
              '/rest/v1/rpc/bil_get_my_admin_subscription',
            ),
          );
          if (phase == _Phase.offline) {
            return http.Response(
              '{"message":"synthetic metadata outage"}',
              503,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          final revision = phase == _Phase.paid7
              ? 7
              : (phase == _Phase.revoked6 || phase == _Phase.refunded6)
              ? 6
              : 5;
          if (path == '/rest/v1/bil_subscriptions') {
            final observed = observedRevisions[revision];
            if (observed != null && !observed.isCompleted) observed.complete();
          }
          final Object? value = switch (path) {
            '/rest/v1/bil_ai_closed_test_grants' => <Object?>[],
            '/rest/v1/rpc/bil_get_my_admin_subscription' => null,
            _ => [
              {
                'owner_id': owner,
                'plan_id': 'premium_ai_coach',
                'provider': 'google',
                'product_id': 'bil_premium_ai_coach_annual',
                'original_transaction_id': 'synthetic-owned-annual-lineage',
                'lifecycle': switch (phase) {
                  _Phase.revoked6 => 'revoked',
                  _Phase.refunded6 => 'refunded',
                  _ => 'active',
                },
                'revision': revision,
                'started_at': _start
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'expires_at': _start
                    .add(Duration(days: revision == 7 ? 2 : 1))
                    .toIso8601String(),
                'verified_at': _start
                    .subtract(Duration(seconds: 10 - revision))
                    .toIso8601String(),
                'auto_renews':
                    phase != _Phase.revoked6 && phase != _Phase.refunded6,
              },
            ],
          };
          return http.Response(
            jsonEncode(value),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> selectOwner(String id) async {
    owner = id;
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode(_session(id)),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<_Fixture> fixture() async {
    final id =
        'de000000-0000-4000-8000-${(++sequence).toString().padLeft(12, '0')}';
    await selectOwner(id);
    phase = _Phase.paid5;
    return _Fixture(id, _Secure());
  }

  void expectDeniedUnknown(SubscriptionState state) {
    expect(state.plan, CommercePlan.free);
    expect(
      state.authority,
      EntitlementAuthority.localDefault,
      reason: 'A transport failure does not fabricate verified Free.',
    );
  }

  for (final terminal in [_Phase.revoked6, _Phase.refunded6]) {
    for (final failure in [
      'delete',
      'delete-and-write',
      'write-only-control',
    ]) {
      test(
        '${terminal.name}: persisted r5 cannot revive after r6 $failure failure',
        () async {
          final f = await fixture();
          expect((await f.repository.current()).serverRevision, 5);
          f.secure.failDelete = failure != 'write-only-control';
          f.secure.failWrite = failure != 'delete';
          phase = terminal;
          final denied = await f.repository.current();
          expect(denied.plan, CommercePlan.free);
          expect(denied.authority, EntitlementAuthority.verifiedServer);
          phase = _Phase.offline;
          expectDeniedUnknown(await f.repository.current());
          // A stale network row cannot borrow the persisted old paid proof either.
          phase = _Phase.stale5;
          expectDeniedUnknown(await f.repository.current());
          // The denial is a version floor, not a permanent account ban.
          f.secure.failDelete = false;
          f.secure.failWrite = false;
          phase = _Phase.paid7;
          final repurchased = await f.repository.current();
          expect(repurchased.plan, CommercePlan.premiumAiCoach);
          expect(repurchased.serverRevision, 7);
          phase = _Phase.offline;
          expect(
            (await f.repository.current()).plan,
            CommercePlan.premiumAiCoach,
          );
        },
      );
    }
  }
  for (final writeFails in [false, true]) {
    test(
      'startup and A B A cannot restore denied r5 when secure write fails=$writeFails',
      () async {
        final f = await fixture();
        // Explicit recovery bypasses the one-shot startup shortcut, so the next
        // normal read exercises the actual persisted startup branch.
        await f.store.remember(ownerId: f.owner, state: _proof(), now: f.now);
        f.secure.failDelete = true;
        f.secure.failWrite = writeFails;
        phase = _Phase.refunded6;
        expect(
          (await f.repository.currentForExplicitStoreRecovery()).plan,
          CommercePlan.free,
        );
        phase = _Phase.offline;
        final other =
            'df000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}';
        await selectOwner(other);
        expectDeniedUnknown(await f.repository.current());
        await selectOwner(f.owner);
        expectDeniedUnknown(await f.repository.current());
        expectDeniedUnknown(await f.repository.current());
      },
      // Three real SDK outage/retry cycles exceed the default 30-second test
      // limit. Keep a finite bound and preserve all startup/owner assertions.
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
  test(
    'held paid r5 cannot overwrite denial r6 and newer repurchase r7',
    () async {
      final f = await fixture();
      final release = Completer<void>();
      f.secure.holdPaid5Write = release;
      f.secure.paid5WriteEntered = Completer<void>();
      observedRevisions[6] = Completer<void>();
      observedRevisions[7] = Completer<void>();
      final old = f.repository.current();
      Future<SubscriptionState>? denied;
      Future<SubscriptionState>? repurchased;
      try {
        await f.secure.paid5WriteEntered!.future.timeout(
          const Duration(seconds: 3),
        );
        phase = _Phase.refunded6;
        denied = f.repository.current();
        await observedRevisions[6]!.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
        phase = _Phase.paid7;
        repurchased = f.repository.current();
        await observedRevisions[7]!.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
        // Both newer canonical responses have arrived while r5 persistence is
        // still held. Serialized storage may defer their durability, never the
        // owner/version witness or the already-verified current r7 cache.
        release.complete();
        final states = await Future.wait([old, denied, repurchased]);
        expect(states[2].serverRevision, 7);
        expect(
          states[0].serverRevision,
          7,
          reason: 'The stale caller must preserve the newer surviving proof.',
        );
        phase = _Phase.offline;
        final offline = await f.repository.current();
        expect(offline.plan, CommercePlan.premiumAiCoach);
        expect(offline.serverRevision, 7);
        final durable = _Secure()..values.addAll(f.secure.values);
        final restored = await VerifiedEntitlementContinuityStore(
          secureStore: durable,
        ).read(ownerId: f.owner, now: f.now);
        expect(
          restored?.serverRevision,
          7,
          reason:
              'A held old write must not overwrite the newer durable receipt.',
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await Future.wait([old, ?denied, ?repurchased]);
        observedRevisions.clear();
      }
    },
  );
  test(
    'new storage reader sees durable denial after failed secure deletion',
    () async {
      final f = await fixture();
      expect((await f.repository.current()).plan, CommercePlan.premiumAiCoach);
      f.secure.failDelete = true;
      phase = _Phase.refunded6;
      expect((await f.repository.current()).plan, CommercePlan.free);
      // Clone only durable bytes, with no repository/session state. This checks
      // the persisted-store contract used by a fresh process, not a fake reset.
      final afterRestart = _Secure()..values.addAll(f.secure.values);
      final restored = await VerifiedEntitlementContinuityStore(
        secureStore: afterRestart,
      ).read(ownerId: f.owner, now: f.now);
      expect(restored, isNull);
    },
  );
  test(
    'valid paid offline continuity remains bounded by its original period',
    () async {
      final f = await fixture();
      expect((await f.repository.current()).plan, CommercePlan.premiumAiCoach);
      phase = _Phase.offline;
      expect((await f.repository.current()).plan, CommercePlan.premiumAiCoach);
      f.now = _start.add(const Duration(days: 1));
      expectDeniedUnknown(await f.repository.current());
    },
  );
}
