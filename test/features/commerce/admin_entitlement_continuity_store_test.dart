import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
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
  final now = DateTime.utc(2026, 9, 28, 6);

  SubscriptionState adminLease(DateTime until) => SubscriptionState(
    plan: CommercePlan.premiumAiCoach,
    entitlements: PaidPlanCatalog.composedEntitlementsFor(
      CommercePlan.premiumAiCoach,
    ),
    authority: EntitlementAuthority.verifiedServer,
    lifecycle: SubscriptionLifecycle.active,
    startedAt: now.subtract(const Duration(days: 1)),
    currentPeriodEndsAt: until,
    isPurchasable: false,
    canRestorePurchases: false,
  );

  test('same owner can recover the remaining verified admin lease', () async {
    final secure = _MemorySecureStore();
    final writer = AdminEntitlementContinuityStore(secureStore: secure);
    await writer.remember(
      ownerId: 'owner-a',
      state: adminLease(now.add(const Duration(minutes: 5))),
      now: now,
    );

    final reader = AdminEntitlementContinuityStore(secureStore: secure);
    final restored = await reader.read(
      ownerId: 'owner-a',
      now: now.add(const Duration(minutes: 2)),
    );

    expect(restored?.plan, CommercePlan.premiumAiCoach);
    expect(restored?.currentPeriodEndsAt, now.add(const Duration(minutes: 5)));
  });

  test('cached lease never crosses owner boundaries', () async {
    final secure = _MemorySecureStore();
    final cache = AdminEntitlementContinuityStore(secureStore: secure);
    await cache.remember(
      ownerId: 'owner-a',
      state: adminLease(now.add(const Duration(minutes: 5))),
      now: now,
    );

    expect(await cache.read(ownerId: 'owner-b', now: now), isNull);
  });

  test('expired cached lease is rejected and deleted', () async {
    final secure = _MemorySecureStore();
    final cache = AdminEntitlementContinuityStore(secureStore: secure);
    await cache.remember(
      ownerId: 'owner-a',
      state: adminLease(now.add(const Duration(minutes: 2))),
      now: now,
    );

    expect(
      await cache.read(
        ownerId: 'owner-a',
        now: now.add(const Duration(minutes: 2)),
      ),
      isNull,
    );
    expect(secure.values, isEmpty);
  });

  test('a lease beyond the server ceiling is never persisted', () async {
    final secure = _MemorySecureStore();
    final cache = AdminEntitlementContinuityStore(secureStore: secure);
    await cache.remember(
      ownerId: 'owner-a',
      state: adminLease(now.add(const Duration(minutes: 7))),
      now: now,
    );

    expect(secure.values, isEmpty);
  });
}
