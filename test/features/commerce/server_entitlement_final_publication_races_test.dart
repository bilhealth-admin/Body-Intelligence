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

final _now = DateTime.utc(2026, 11, 21, 2);

enum _Phase {
  lower5,
  free5,
  refunded6,
  revoked6,
  higher7,
  grantFull,
  unreadableRefund6,
  unavailable,
}

class _Secure implements AdminEntitlementSecureStore {
  final values = <String, String>{};
  Completer<void>? heldRead;
  Completer<void>? readEntered;
  int reads = 0;
  bool rejectReads = false;

  @override
  Future<String?> read(String key) async {
    reads++;
    if (rejectReads) throw StateError('synthetic unavailable secure read');
    final snapshot = values[key];
    final gate = heldRead;
    if (gate != null) {
      heldRead = null;
      readEntered!.complete();
      await gate.future;
    }
    return snapshot;
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

SubscriptionState _lowerProof() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: SubscriptionLifecycle.active,
  provider: SubscriptionProvider.google,
  startedAt: _now.subtract(const Duration(days: 1)),
  currentPeriodEndsAt: _now.add(const Duration(days: 1)),
  verifiedAt: _now.subtract(const Duration(seconds: 5)),
  serverRevision: 5,
  storeOriginalTransactionId: 'synthetic-lower-X',
  isPurchasable: false,
  canRestorePurchases: true,
);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var owner = '';
  var serial = 0;
  var phase = _Phase.lower5;
  Completer<void>? heldAdmin;
  Completer<void>? adminEntered;
  var heldAdminFails = false;
  Completer<void>? higherObserved;
  late _Secure secure;
  late VerifiedEntitlementContinuityStore store;
  late ServerEntitlementRepository repository;

  http.Response response(
    http.Request request,
    Object? value, [
    int status = 200,
  ]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://final-publication-races.invalid',
      publishableKey: 'synthetic-only-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          expect(request.url.host, 'final-publication-races.invalid');
          final path = request.url.path;
          expect(
            path,
            anyOf(
              '/rest/v1/bil_ai_closed_test_grants',
              '/rest/v1/bil_subscriptions',
              '/rest/v1/rpc/bil_get_my_admin_subscription',
            ),
          );
          if (path == '/rest/v1/rpc/bil_get_my_admin_subscription') {
            final gate = heldAdmin;
            final fails = heldAdminFails;
            if (gate != null) {
              heldAdmin = null;
              adminEntered!.complete();
              await gate.future;
              if (fails) {
                return response(request, {
                  'message': 'synthetic rate limit',
                }, 429);
              }
            }
            return response(request, null);
          }
          if (phase == _Phase.unreadableRefund6 &&
              path == '/rest/v1/bil_ai_closed_test_grants') {
            return response(request, {'message': 'synthetic rate limit'}, 429);
          }
          if (phase == _Phase.unavailable) {
            return response(request, {'message': 'synthetic rate limit'}, 429);
          }
          if (path == '/rest/v1/bil_ai_closed_test_grants') {
            return response(
              request,
              phase == _Phase.grantFull
                  ? [
                      {
                        'active': true,
                        'expires_at': _now
                            .add(const Duration(hours: 1))
                            .toIso8601String(),
                      },
                    ]
                  : <Object?>[],
            );
          }
          final observedPhase = phase;
          if (observedPhase == _Phase.free5) {
            return response(request, <Object?>[]);
          }
          if (observedPhase == _Phase.higher7 &&
              higherObserved?.isCompleted == false) {
            higherObserved!.complete();
          }
          final revision = observedPhase == _Phase.higher7
              ? 7
              : (observedPhase == _Phase.refunded6 ||
                    observedPhase == _Phase.revoked6 ||
                    observedPhase == _Phase.unreadableRefund6)
              ? 6
              : 5;
          return response(request, [
            {
              'owner_id': owner,
              'plan_id': observedPhase == _Phase.higher7
                  ? 'premium_ai_coach'
                  : 'premium',
              'provider': 'google',
              if (observedPhase == _Phase.higher7)
                'product_id': 'bil_premium_ai_coach_annual',
              'original_transaction_id': observedPhase == _Phase.higher7
                  ? 'synthetic-higher-Y'
                  : 'synthetic-lower-X',
              'lifecycle':
                  (observedPhase == _Phase.refunded6 ||
                      observedPhase == _Phase.unreadableRefund6)
                  ? 'refunded'
                  : observedPhase == _Phase.revoked6
                  ? 'revoked'
                  : 'active',
              'revision': revision,
              'started_at': _now
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'expires_at': _now.add(const Duration(days: 1)).toIso8601String(),
              'verified_at': _now
                  .subtract(Duration(seconds: 10 - revision))
                  .toIso8601String(),
            },
          ]);
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    owner = 'ed000000-0000-4000-8000-${(++serial).toString().padLeft(12, '0')}';
    phase = _Phase.lower5;
    heldAdmin = adminEntered = higherObserved = null;
    heldAdminFails = false;
    secure = _Secure();
    store = VerifiedEntitlementContinuityStore(secureStore: secure);
    repository = ServerEntitlementRepository(
      subscriptionContinuityStore: store,
      adminContinuityStore: AdminEntitlementContinuityStore(
        secureStore: _Secure(),
      ),
      clock: () => _now,
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode(_session(owner)),
    );
    await Future<void>.delayed(Duration.zero);
  });

  for (final replacement in [_Phase.refunded6, _Phase.higher7]) {
    test(
      'final admin await cannot publish captured r5 after ${replacement.name}',
      () async {
        final release = Completer<void>();
        heldAdmin = release;
        adminEntered = Completer<void>();
        heldAdminFails = replacement == _Phase.higher7;
        final older = repository.current();
        Future<SubscriptionState>? newer;
        try {
          await adminEntered!.future.timeout(const Duration(seconds: 3));
          phase = replacement;
          newer = repository.current();
          final published = await newer;
          expect(
            published.plan,
            replacement == _Phase.refunded6
                ? CommercePlan.free
                : CommercePlan.premiumAiCoach,
          );
          release.complete();
          final late = await older;
          if (replacement == _Phase.refunded6) {
            expect(
              late.plan,
              CommercePlan.free,
              reason:
                  'The final admin null must not revive a refunded store receipt.',
            );
          } else {
            expect(
              late.plan,
              CommercePlan.premiumAiCoach,
              reason:
                  'The final admin error must retain the newer independent higher proof.',
            );
            expect(late.serverRevision, 7);
            expect(late.storeOriginalTransactionId, 'synthetic-higher-Y');
          }
        } finally {
          if (!release.isCompleted) release.complete();
          await Future.wait([older, ?newer]);
        }
      },
    );
  }

  test('final admin await cannot publish captured Free after paid r7', () async {
    phase = _Phase.free5;
    final release = Completer<void>();
    heldAdmin = release;
    adminEntered = Completer<void>();
    final older = repository.current();
    Future<SubscriptionState>? newer;
    try {
      await adminEntered!.future.timeout(const Duration(seconds: 3));
      phase = _Phase.higher7;
      newer = repository.current();
      final paid = await newer;
      expect(paid.plan, CommercePlan.premiumAiCoach);
      expect(paid.serverRevision, 7);
      release.complete();
      final late = await older;
      expect(
        late.plan,
        CommercePlan.premiumAiCoach,
        reason:
            'A captured older Free cannot replace a newer completed paid proof.',
      );
      expect(late.serverRevision, 7);
      expect(late.storeOriginalTransactionId, 'synthetic-higher-Y');
    } finally {
      if (!release.isCompleted) release.complete();
      await Future.wait([older, ?newer]);
    }
  });

  for (final explicit in [false, true]) {
    test(
      'fresh canonical terminal retains authority and metadata (explicit=$explicit)',
      () async {
        phase = explicit ? _Phase.revoked6 : _Phase.refunded6;
        final result = explicit
            ? await repository.currentForExplicitCheckoutRecovery()
            : await repository.current();
        expect(result.plan, CommercePlan.free);
        expect(
          result.authority,
          EntitlementAuthority.verifiedServer,
          reason: 'A current canonical negative remains fresh server evidence.',
        );
        expect(
          result.lifecycle,
          explicit
              ? SubscriptionLifecycle.revoked
              : SubscriptionLifecycle.refunded,
        );
        expect(result.provider, SubscriptionProvider.google);
        expect(result.serverRevision, 6);
        expect(result.storeRenewalDefinitivelyInactive, isTrue);
        expect(result.canRestorePurchases, isTrue);
      },
    );
  }

  test(
    'final admin await preserves a newer independent closed grant overlay',
    () async {
      final release = Completer<void>();
      heldAdmin = release;
      adminEntered = Completer<void>();
      final older = repository.current();
      Future<SubscriptionState>? newer;
      try {
        await adminEntered!.future.timeout(const Duration(seconds: 3));
        phase = _Phase.grantFull;
        newer = repository.current();
        final full = await newer;
        expect(full.plan, CommercePlan.premiumAiCoach);
        expect(full.provider, isNull);
        release.complete();
        final late = await older;
        expect(
          late.plan,
          CommercePlan.premiumAiCoach,
          reason:
              'A still-valid lower store receipt cannot hide a newer independent Full grant.',
        );
        expect(late.provider, isNull);
        expect(late.authority, EntitlementAuthority.verifiedServer);
      } finally {
        if (!release.isCompleted) release.complete();
        await Future.wait([older, ?newer]);
      }
    },
  );

  test(
    'late unverified terminal metadata cannot replace newer paid r7',
    () async {
      phase = _Phase.unreadableRefund6;
      final release = Completer<void>();
      heldAdmin = release;
      adminEntered = Completer<void>();
      final older = repository.current();
      Future<SubscriptionState>? newer;
      try {
        await adminEntered!.future.timeout(const Duration(seconds: 3));
        phase = _Phase.higher7;
        newer = repository.current();
        final paid = await newer;
        expect(paid.plan, CommercePlan.premiumAiCoach);
        expect(paid.serverRevision, 7);
        release.complete();
        final late = await older;
        expect(
          late.plan,
          CommercePlan.premiumAiCoach,
          reason:
              'Preserving raw negative metadata must not publish it past newer paid proof.',
        );
        expect(late.serverRevision, 7);
        expect(late.storeOriginalTransactionId, 'synthetic-higher-Y');
      } finally {
        if (!release.isCompleted) release.complete();
        await Future.wait([older, ?newer]);
      }
    },
  );

  for (final startup in [true, false]) {
    test(
      '${startup ? 'startup' : 'fallback'} disk read cannot replace newer live independent proof',
      () async {
        if (!startup) {
          phase = _Phase.unavailable;
          expect((await repository.current()).plan, CommercePlan.free);
        }
        await store.remember(ownerId: owner, state: _lowerProof(), now: _now);
        final release = Completer<void>();
        secure.heldRead = release;
        secure.readEntered = Completer<void>();
        phase = _Phase.unavailable;
        final older = repository.current();
        Future<SubscriptionState>? newer;
        try {
          await secure.readEntered!.future.timeout(const Duration(seconds: 3));
          phase = _Phase.higher7;
          higherObserved = Completer<void>();
          newer = repository.current();
          await higherObserved!.future.timeout(const Duration(seconds: 3));
          // Flush the canonical response into its synchronous revision/cache
          // publication; its secure write is queued behind the still-held read.
          await Future<void>.delayed(Duration.zero);
          release.complete();
          final results = await Future.wait([older, newer]);
          // This outage must use the live cache, not the now-newer durable slot.
          secure.rejectReads = true;
          phase = _Phase.unavailable;
          final cached = await repository.current();
          expect(
            cached.plan,
            CommercePlan.premiumAiCoach,
            reason:
                'A completed stale disk read must not replace live higher-tier proof.',
          );
          expect(cached.serverRevision, 7);
          expect(cached.storeOriginalTransactionId, 'synthetic-higher-Y');
          for (final result in results) {
            expect(result.plan, CommercePlan.premiumAiCoach);
            expect(result.serverRevision, 7);
          }
        } finally {
          if (!release.isCompleted) release.complete();
          await Future.wait([older, ?newer]);
        }
      },
    );
  }
}
