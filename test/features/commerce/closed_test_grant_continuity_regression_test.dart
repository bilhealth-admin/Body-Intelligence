import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/safe_contextual_ad_controller.dart';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  var serial = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://closed-grant-continuity.invalid',
      publishableKey: 'synthetic-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) => fixture.respond(request)),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    fixture = _Fixture(++serial);
    await fixture.signIn(fixture.owner);
  });

  for (final emptyMirror in [false, true]) {
    test(
      'fresh verified Free alone reaches the safe ad request boundary emptyMirror=$emptyMirror',
      () async {
        fixture.grantAbsent = true;
        fixture.storeAbsent = emptyMirror;
        final state = await fixture.repository.current();
        expect(state.plan, CommercePlan.free);
        expect(state.authority, EntitlementAuthority.verifiedServer);
        expect(fixture.grantReads, 1);
        expect(fixture.storeReads, 1);
        final decision = _adDecisionFor(state);
        expect(decision.reason, AdSuppressionReason.allowed);
        final gateway = _RecordingAdGateway();
        expect(
          await SafeContextualAdController(gateway).requestIfAllowed(
            decision: decision,
            placement: AdPlacement.generalDiscovery,
          ),
          ContextualAdResult.noFill,
        );
        expect(gateway.placements, [AdPlacement.generalDiscovery]);
      },
    );
    test(
      'an unreadable grant and fallback Free never request an ad emptyMirror=$emptyMirror',
      () async {
        fixture.grantFailure = _GrantFailure.network;
        fixture.storeAbsent = emptyMirror;
        final state = await fixture.repository.current();
        expect(state.plan, CommercePlan.free);
        expect(state.authority, EntitlementAuthority.localDefault);
        final decision = _adDecisionFor(state);
        expect(decision.reason, AdSuppressionReason.entitlementUnverified);
        final gateway = _RecordingAdGateway();
        expect(
          await SafeContextualAdController(gateway).requestIfAllowed(
            decision: decision,
            placement: AdPlacement.generalDiscovery,
          ),
          ContextualAdResult.unavailable,
        );
        expect(gateway.placements, isEmpty);
      },
    );
  }

  test(
    'grant continuity and its expiry never manufacture ad-eligible Free',
    () async {
      final gateway = _RecordingAdGateway();
      final controller = SafeContextualAdController(gateway);
      final active = await fixture.repository.current();
      expect(
        _adDecisionFor(active).reason,
        AdSuppressionReason.paidSubscription,
      );
      expect(
        await controller.requestIfAllowed(
          decision: _adDecisionFor(active),
          placement: AdPlacement.generalDiscovery,
        ),
        ContextualAdResult.unavailable,
      );
      fixture.grantFailure = _GrantFailure.network;
      fixture.storeAbsent = true;
      fixture.now = fixture.now.add(const Duration(minutes: 2));
      final retained = await fixture.repository.current();
      expect(retained.plan, CommercePlan.premiumAiCoach);
      expect(
        _adDecisionFor(retained).reason,
        AdSuppressionReason.paidSubscription,
      );
      await controller.requestIfAllowed(
        decision: _adDecisionFor(retained),
        placement: AdPlacement.generalDiscovery,
      );
      fixture.now = fixture.now.add(const Duration(minutes: 3, seconds: 1));
      final unresolved = await fixture.repository.current();
      expect(unresolved.plan, CommercePlan.free);
      expect(unresolved.authority, EntitlementAuthority.localDefault);
      expect(
        _adDecisionFor(unresolved).reason,
        AdSuppressionReason.entitlementUnverified,
      );
      await controller.requestIfAllowed(
        decision: _adDecisionFor(unresolved),
        placement: AdPlacement.generalDiscovery,
      );
      expect(gateway.placements, isEmpty);

      // Only a new successful server observation can make Free ad-eligible.
      fixture.grantFailure = _GrantFailure.none;
      fixture.grantAbsent = true;
      final verifiedFree = await fixture.repository.current();
      expect(verifiedFree.authority, EntitlementAuthority.verifiedServer);
      expect(_adDecisionFor(verifiedFree).reason, AdSuppressionReason.allowed);
      await controller.requestIfAllowed(
        decision: _adDecisionFor(verifiedFree),
        placement: AdPlacement.generalDiscovery,
      );
      expect(gateway.placements, [AdPlacement.generalDiscovery]);
    },
  );

  for (final lifecycle in ['expired', 'refunded', 'revoked']) {
    test(
      'grant survives network failure with unrelated $lifecycle Apple row',
      () async {
        final granted = await fixture.repository.current();
        expect(granted.plan, CommercePlan.premiumAiCoach);
        final grantedUntil = granted.currentPeriodEndsAt;
        fixture.grantFailure = _GrantFailure.network;
        fixture.storeLifecycle = lifecycle;

        final retained = await fixture.repository.current();
        expect(retained.plan, CommercePlan.premiumAiCoach);
        expect(retained.authority, EntitlementAuthority.verifiedServer);
        expect(retained.provider, isNull);
        expect(grantedUntil, fixture.grantExpires);
        expect(
          retained.currentPeriodEndsAt,
          fixture.now.add(const Duration(minutes: 5)),
        );
        expect(fixture.grantExpires, grantedUntil);
        expect(fixture.storeReads, 1);
      },
    );
  }

  test(
    '429 continuity is bounded to five minutes and fallback cannot renew it',
    () async {
      final leaseBoundary = fixture.now.add(const Duration(minutes: 5));
      await fixture.repository.current();
      fixture.grantFailure = _GrantFailure.rateLimited;
      fixture.now = fixture.now.add(const Duration(minutes: 2));
      final firstFallback = await fixture.repository.current();
      expect(firstFallback.plan, CommercePlan.premiumAiCoach);
      expect(firstFallback.currentPeriodEndsAt, leaseBoundary);
      fixture.now = fixture.now.add(const Duration(minutes: 2));
      final nextFallback = await fixture.repository.current();
      expect(nextFallback.plan, CommercePlan.premiumAiCoach);
      expect(nextFallback.currentPeriodEndsAt, leaseBoundary);
      fixture.now = fixture.now.add(const Duration(minutes: 1, seconds: 1));
      final expired = await fixture.repository.current();
      expect(expired.plan, CommercePlan.free);
      expect(expired.authority, EntitlementAuthority.localDefault);
    },
  );

  for (final absent in [false, true]) {
    test(
      'successful ${absent ? 'absent' : 'inactive'} grant revokes immediately even with empty mirror',
      () async {
        await fixture.repository.current();
        fixture.grantActive = false;
        fixture.grantAbsent = absent;
        fixture.storeAbsent = true;
        final revoked = await fixture.repository.current();
        expect(revoked.plan, CommercePlan.free);
        expect(revoked.authority, EntitlementAuthority.verifiedServer);
        fixture.grantFailure = _GrantFailure.rateLimited;
        final unavailable = await fixture.repository.current();
        expect(unavailable.plan, CommercePlan.free);
        expect(unavailable.authority, EntitlementAuthority.localDefault);
      },
    );
  }

  test('grant expiry wins before the five-minute continuity window', () async {
    fixture.grantExpires = fixture.now.add(const Duration(seconds: 30));
    await fixture.repository.current();
    fixture.grantFailure = _GrantFailure.rateLimited;
    fixture.now = fixture.now.add(const Duration(seconds: 31));
    final state = await fixture.repository.current();
    expect(state.plan, CommercePlan.free);
    expect(state.authority, EntitlementAuthority.localDefault);
  });

  test(
    'another owner and returning owner cannot borrow prior-session grant',
    () async {
      final original = fixture.owner;
      await fixture.repository.current();
      fixture.grantFailure = _GrantFailure.rateLimited;
      fixture.owner = 'fb000000-0000-4000-8000-999999999999';
      await fixture.signIn(fixture.owner);
      expect((await fixture.repository.current()).plan, CommercePlan.free);
      fixture.owner = original;
      await fixture.signIn(original);
      expect((await fixture.repository.current()).plan, CommercePlan.free);
    },
  );

  test(
    'explicit logout clears grant continuity before signing in again',
    () async {
      await fixture.repository.current();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      expect((await fixture.repository.current()).plan, CommercePlan.free);
      fixture.grantFailure = _GrantFailure.rateLimited;
      await fixture.signIn(fixture.owner);
      expect((await fixture.repository.current()).plan, CommercePlan.free);
    },
  );

  test(
    'grant read failure without prior independent proof grants nothing',
    () async {
      fixture.grantFailure = _GrantFailure.rateLimited;
      final state = await fixture.repository.current();
      expect(state.plan, CommercePlan.free);
      expect(state.authority, EntitlementAuthority.localDefault);
      expect(fixture.storeReads, 1);
    },
  );

  test(
    'untagged cold persisted provider-null state cannot create grant proof',
    () async {
      await fixture.subscriptionStore.remember(
        ownerId: fixture.owner,
        now: fixture.now,
        state: SubscriptionState(
          plan: CommercePlan.premiumAiCoach,
          entitlements: PaidPlanCatalog.composedEntitlementsFor(
            CommercePlan.premiumAiCoach,
          ),
          authority: EntitlementAuthority.verifiedServer,
          lifecycle: SubscriptionLifecycle.active,
          currentPeriodEndsAt: fixture.grantExpires,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
      );
      fixture.grantFailure = _GrantFailure.rateLimited;
      final state = await fixture.repository.current();
      expect(state.plan, CommercePlan.free);
      expect(state.authority, EntitlementAuthority.localDefault);
      expect(fixture.grantReads, greaterThan(0));
    },
  );

  test(
    'valid Apple authority remains independent and terminal Apple revokes only itself',
    () async {
      fixture.grantFailure = _GrantFailure.rateLimited;
      fixture.storeLifecycle = 'active';
      final paid = await fixture.repository.current();
      expect(paid.plan, CommercePlan.premium);
      expect(paid.provider, SubscriptionProvider.apple);
      fixture.storeLifecycle = 'revoked';
      final revoked = await fixture.repository.current();
      expect(revoked.plan, CommercePlan.free);
      expect(revoked.authority, EntitlementAuthority.localDefault);
    },
  );

  test(
    'lower paid store tier cannot erase separately verified higher grant',
    () async {
      await fixture.repository.current();
      fixture.grantFailure = _GrantFailure.rateLimited;
      fixture.storeLifecycle = 'active';
      final state = await fixture.repository.current();
      expect(state.plan, CommercePlan.premiumAiCoach);
      expect(state.provider, isNull);
      fixture.grantFailure = _GrantFailure.none;
      fixture.grantActive = false;
      final storeOnly = await fixture.repository.current();
      expect(storeOnly.plan, CommercePlan.premium);
      expect(storeOnly.provider, SubscriptionProvider.apple);
    },
  );

  test(
    'older active grant response cannot resurrect a newer revocation',
    () async {
      await fixture.repository.current();
      final release = Completer<void>();
      fixture.heldGrant = release;
      fixture.grantReadEntered = Completer<void>();
      final older = fixture.repository.current();
      await fixture.grantReadEntered!.future;
      try {
        fixture.grantActive = false;
        final revoked = await fixture.repository.current();
        expect(revoked.plan, CommercePlan.free);
        expect(revoked.authority, EntitlementAuthority.verifiedServer);
        release.complete();
        final retired = await older;
        expect(retired.plan, CommercePlan.free);
        fixture.grantFailure = _GrantFailure.rateLimited;
        expect((await fixture.repository.current()).plan, CommercePlan.free);
      } finally {
        if (!release.isCompleted) release.complete();
        await older;
      }
    },
  );

  test(
    'older inactive response cannot clear newer same-owner grant proof',
    () async {
      await fixture.repository.current();
      fixture.grantActive = false;
      final release = Completer<void>();
      fixture.heldGrant = release;
      fixture.grantReadEntered = Completer<void>();
      final older = fixture.repository.current();
      await fixture.grantReadEntered!.future;
      try {
        fixture.grantActive = true;
        final latest = await fixture.repository.current();
        expect(latest.plan, CommercePlan.premiumAiCoach);
        expect(latest.currentPeriodEndsAt, fixture.grantExpires);
        release.complete();
        final retained = await older;
        expect(retained.plan, CommercePlan.premiumAiCoach);
        expect(
          retained.currentPeriodEndsAt,
          fixture.now.add(const Duration(minutes: 5)),
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await older;
      }
    },
  );

  test(
    'grant held in secure write cannot outlive a newer revocation',
    () async {
      await fixture.repository.current();
      final release = Completer<void>();
      fixture.subscriptionSecure.heldWrite = release;
      fixture.subscriptionSecure.writeEntered = Completer<void>();
      final older = fixture.repository.current();
      await fixture.subscriptionSecure.writeEntered!.future;
      try {
        fixture.grantActive = false;
        expect((await fixture.repository.current()).plan, CommercePlan.free);
        release.complete();
        expect((await older).plan, CommercePlan.free);
        // The old secure write may finish last. Its untagged provider-null
        // snapshot must not re-create independent grant authority on fallback.
        fixture.grantFailure = _GrantFailure.rateLimited;
        expect((await fixture.repository.current()).plan, CommercePlan.free);
      } finally {
        if (!release.isCompleted) release.complete();
        await older;
      }
    },
  );

  test('grant held in secure write is rechecked at its real expiry', () async {
    fixture.grantExpires = fixture.now.add(const Duration(seconds: 30));
    final release = Completer<void>();
    fixture.subscriptionSecure.heldWrite = release;
    fixture.subscriptionSecure.writeEntered = Completer<void>();
    final older = fixture.repository.current();
    await fixture.subscriptionSecure.writeEntered!.future;
    try {
      fixture.now = fixture.now.add(const Duration(seconds: 31));
      release.complete();
      expect((await older).plan, CommercePlan.free);
    } finally {
      if (!release.isCompleted) release.complete();
      await older;
    }
  });

  test(
    'later admin RPC wait cannot return a retired closed-test grant',
    () async {
      await fixture.repository.current();
      final release = Completer<void>();
      fixture.heldAdmin = release;
      fixture.adminReadEntered = Completer<void>();
      final older = fixture.repository.current();
      await fixture.adminReadEntered!.future;
      try {
        fixture.grantActive = false;
        expect((await fixture.repository.current()).plan, CommercePlan.free);
        release.complete();
        expect((await older).plan, CommercePlan.free);
      } finally {
        if (!release.isCompleted) release.complete();
        await older;
      }
    },
  );
  test(
    'last admin secure operation cannot pin a retired closed-test grant',
    () async {
      await fixture.repository.current();
      final release = Completer<void>();
      fixture.adminSecure.heldDelete = release;
      fixture.adminSecure.deleteEntered = Completer<void>();
      final older = fixture.repository.current();
      await fixture.adminSecure.deleteEntered!.future;
      try {
        fixture.grantActive = false;
        expect((await fixture.repository.current()).plan, CommercePlan.free);
        release.complete();
        expect((await older).plan, CommercePlan.free);
      } finally {
        if (!release.isCompleted) release.complete();
        await older;
      }
    },
  );
}

enum _GrantFailure { none, network, rateLimited }

final class _Fixture {
  _Fixture(int serial)
    : owner = 'fb000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}' {
    grantExpires = now.add(const Duration(hours: 24));
    subscriptionStore = VerifiedEntitlementContinuityStore(
      secureStore: subscriptionSecure,
    );
    repository = ServerEntitlementRepository(
      adminContinuityStore: AdminEntitlementContinuityStore(
        secureStore: adminSecure,
      ),
      subscriptionContinuityStore: subscriptionStore,
      clock: () => now,
    );
  }

  String owner;
  DateTime now = DateTime.utc(2026, 11, 8, 0);
  late DateTime grantExpires;
  final subscriptionSecure = _Secure();
  final adminSecure = _Secure();
  late final VerifiedEntitlementContinuityStore subscriptionStore;
  late final ServerEntitlementRepository repository;
  var grantActive = true;
  var grantAbsent = false;
  var storeAbsent = false;
  var grantFailure = _GrantFailure.none;
  var storeLifecycle = 'expired';
  var grantReads = 0;
  var storeReads = 0;
  Completer<void>? heldGrant;
  Completer<void>? grantReadEntered;
  Completer<void>? heldAdmin;
  Completer<void>? adminReadEntered;

  Future<void> signIn(String ownerId) =>
      Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-grant-continuity-token',
          'token_type': 'bearer',
          'user': {
            'id': ownerId,
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );

  Future<http.Response> respond(http.Request request) async {
    Object? body;
    switch (request.url.path) {
      case '/rest/v1/bil_ai_closed_test_grants':
        grantReads++;
        expect(request.url.queryParameters['owner_id'], 'eq.$owner');
        final failureAtRead = grantFailure;
        final grantAtRead = grantAbsent
            ? []
            : [
                {
                  'active': grantActive,
                  'expires_at': grantExpires.toIso8601String(),
                },
              ];
        final held = heldGrant;
        if (held != null) {
          heldGrant = null;
          grantReadEntered!.complete();
          await held.future;
        }
        if (failureAtRead == _GrantFailure.network) {
          throw http.ClientException('synthetic closed-test network outage');
        }
        if (failureAtRead == _GrantFailure.rateLimited) {
          return http.Response(
            jsonEncode({'code': '429', 'message': 'synthetic rate limit'}),
            429,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        body = grantAtRead;
      case '/rest/v1/bil_subscriptions':
        storeReads++;
        expect(request.url.queryParameters['owner_id'], 'eq.$owner');
        body = storeAbsent
            ? []
            : [
                {
                  'owner_id': owner,
                  'provider': 'apple',
                  'original_transaction_id': 'synthetic-chain',
                  'plan_id': 'premium',
                  'lifecycle': storeLifecycle,
                  'started_at': now
                      .subtract(const Duration(days: 2))
                      .toIso8601String(),
                  'expires_at':
                      (storeLifecycle == 'active'
                              ? now.add(const Duration(days: 1))
                              : now.subtract(const Duration(days: 1)))
                          .toIso8601String(),
                  'verified_at': now.toIso8601String(),
                  'revision': 313,
                },
              ];
      case '/rest/v1/rpc/bil_get_my_admin_subscription':
        final held = heldAdmin;
        if (held != null) {
          heldAdmin = null;
          adminReadEntered!.complete();
          await held.future;
        }
        body = null;
      case '/auth/v1/logout':
        return http.Response('', 204, request: request);
      default:
        throw StateError('Unexpected synthetic fixture path');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

final class _Secure implements AdminEntitlementSecureStore {
  final _values = <String, String>{};
  Completer<void>? heldWrite;
  Completer<void>? writeEntered;
  Completer<void>? heldDelete;
  Completer<void>? deleteEntered;

  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async {
    final held = heldWrite;
    if (held != null) {
      heldWrite = null;
      writeEntered!.complete();
      await held.future;
    }
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    final held = heldDelete;
    if (held != null) {
      heldDelete = null;
      deleteEntered!.complete();
      await held.future;
    }
    _values.remove(key);
  }
}

AdPolicyDecision _adDecisionFor(SubscriptionState state) {
  const policy = AdPolicy();
  return policy.evaluate(
    subscription: state,
    placement: AdPlacement.generalDiscovery,
    providerConfigured: true,
    isOnline: true,
    ageEligibility: AdAgeEligibility.adult,
  );
}

final class _RecordingAdGateway implements ContextualAdGateway {
  final placements = <AdPlacement>[];

  @override
  bool get isConfigured => true;

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async {
    placements.add(placement);
    return ContextualAdResult.noFill;
  }
}
