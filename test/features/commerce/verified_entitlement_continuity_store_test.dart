import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemorySecureStore implements AdminEntitlementSecureStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);

  SubscriptionState paid(
    SubscriptionLifecycle lifecycle,
    DateTime accessUntil, {
    SubscriptionProvider? provider = SubscriptionProvider.apple,
  }) {
    return SubscriptionState(
      plan: CommercePlan.premium,
      entitlements: PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premium,
      ),
      authority: EntitlementAuthority.verifiedServer,
      lifecycle: lifecycle,
      provider: provider,
      startedAt: now.subtract(const Duration(days: 2)),
      currentPeriodEndsAt:
          lifecycle == SubscriptionLifecycle.active ||
              lifecycle == SubscriptionLifecycle.cancelled
          ? accessUntil
          : null,
      trialEndsAt: lifecycle == SubscriptionLifecycle.trial
          ? accessUntil
          : null,
      gracePeriodEndsAt: lifecycle == SubscriptionLifecycle.gracePeriod
          ? accessUntil
          : null,
      isPurchasable: false,
      canRestorePurchases: provider != null,
    );
  }

  test(
    'same owner restores paid access until exact verified boundary',
    () async {
      final secure = _MemorySecureStore();
      final store = VerifiedEntitlementContinuityStore(secureStore: secure);
      final until = now.add(const Duration(days: 8));

      await store.remember(
        ownerId: 'owner-a',
        state: paid(SubscriptionLifecycle.active, until),
        now: now,
      );

      final restored = await store.read(
        ownerId: 'owner-a',
        now: now.add(const Duration(days: 3)),
      );

      expect(restored?.plan, CommercePlan.premium);
      expect(restored?.authority, EntitlementAuthority.verifiedServer);
      expect(restored?.currentPeriodEndsAt, until);
      expect(restored?.provider, SubscriptionProvider.apple);
      expect(restored?.canRestorePurchases, isTrue);
    },
  );

  test('continuity never crosses owners or verified boundary', () async {
    final secure = _MemorySecureStore();
    final store = VerifiedEntitlementContinuityStore(secureStore: secure);
    final until = now.add(const Duration(hours: 2));

    await store.remember(
      ownerId: 'owner-a',
      state: paid(SubscriptionLifecycle.active, until),
      now: now,
    );

    expect(await store.read(ownerId: 'owner-b', now: now), isNull);
    expect(await store.read(ownerId: 'owner-a', now: until), isNull);
    expect(secure.values, isEmpty);
  });

  for (final lifecycle in <SubscriptionLifecycle>[
    SubscriptionLifecycle.trial,
    SubscriptionLifecycle.gracePeriod,
    SubscriptionLifecycle.cancelled,
  ]) {
    test('$lifecycle restores only its matching access boundary', () async {
      final secure = _MemorySecureStore();
      final store = VerifiedEntitlementContinuityStore(secureStore: secure);
      final until = now.add(const Duration(days: 2));

      await store.remember(
        ownerId: 'owner-a',
        state: paid(lifecycle, until),
        now: now,
      );
      final restored = await store.read(ownerId: 'owner-a', now: now);

      expect(restored?.lifecycle, lifecycle);
      expect(
        switch (lifecycle) {
          SubscriptionLifecycle.trial => restored?.trialEndsAt,
          SubscriptionLifecycle.gracePeriod => restored?.gracePeriodEndsAt,
          SubscriptionLifecycle.cancelled => restored?.currentPeriodEndsAt,
          _ => null,
        },
        until,
      );
    });
  }

  test('authoritative Free clears prior paid continuity', () async {
    final secure = _MemorySecureStore();
    final store = VerifiedEntitlementContinuityStore(secureStore: secure);
    await store.remember(
      ownerId: 'owner-a',
      state: paid(
        SubscriptionLifecycle.active,
        now.add(const Duration(days: 5)),
      ),
      now: now,
    );

    await store.remember(
      ownerId: 'owner-a',
      state: FreePlan.createState(),
      now: now.add(const Duration(minutes: 1)),
    );

    expect(secure.values, isEmpty);
    expect(await store.read(ownerId: 'owner-a', now: now), isNull);
  });

  test('corrupt provider fails closed and deletes snapshot', () async {
    final secure = _MemorySecureStore();
    final store = VerifiedEntitlementContinuityStore(secureStore: secure);
    await store.remember(
      ownerId: 'owner-a',
      state: paid(
        SubscriptionLifecycle.active,
        now.add(const Duration(days: 5)),
      ),
      now: now,
    );
    final key = secure.values.keys.single;
    final value = jsonDecode(secure.values[key]!) as Map<String, dynamic>;
    value['provider'] = 'unknown-provider';
    secure.values[key] = jsonEncode(value);

    expect(await store.read(ownerId: 'owner-a', now: now), isNull);
    expect(secure.values, isEmpty);
  });
}
