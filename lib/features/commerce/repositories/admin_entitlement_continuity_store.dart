import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/commerce_plan.dart';
import '../domain/paid_plan_catalog.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_state.dart';

abstract interface class AdminEntitlementSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterAdminEntitlementSecureStore
    implements AdminEntitlementSecureStore {
  FlutterAdminEntitlementSecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists only the short server-issued admin lease, never a purchase claim.
///
/// The cached value is owner-scoped and cannot outlive either the exact
/// `access_until` returned by the server or the six-minute admin lease ceiling.
/// It exists solely to keep a verified admin account stable across a transient
/// network loss or process restart.
final class AdminEntitlementContinuityStore {
  AdminEntitlementContinuityStore({AdminEntitlementSecureStore? secureStore})
    : _secureStore = secureStore ?? FlutterAdminEntitlementSecureStore();

  static const _prefix = 'bil.admin-entitlement-lease.v1.';
  static const _maximumLease = Duration(minutes: 6);

  final AdminEntitlementSecureStore _secureStore;

  Future<void> remember({
    required String ownerId,
    required SubscriptionState state,
    required DateTime now,
  }) async {
    final boundary = state.currentPeriodEndsAt?.toUtc();
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.lifecycle != SubscriptionLifecycle.active ||
        !const {
          CommercePlan.premium,
          CommercePlan.premiumAiCoach,
        }.contains(state.plan) ||
        boundary == null ||
        !boundary.isAfter(now.toUtc()) ||
        boundary.isAfter(now.toUtc().add(_maximumLease))) {
      await clear(ownerId);
      return;
    }
    await _secureStore.write(
      '$_prefix$ownerId',
      jsonEncode(<String, Object?>{
        'owner_id': ownerId,
        'plan_id': state.plan.id,
        'verified_at': now.toUtc().toIso8601String(),
        'started_at': state.startedAt?.toUtc().toIso8601String(),
        'access_until': boundary.toIso8601String(),
      }),
    );
  }

  Future<SubscriptionState?> read({
    required String ownerId,
    required DateTime now,
  }) async {
    final encoded = await _secureStore.read('$_prefix$ownerId');
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map || value['owner_id'] != ownerId) {
        await clear(ownerId);
        return null;
      }
      final verifiedAt = DateTime.tryParse('${value['verified_at']}')?.toUtc();
      final accessUntil = DateTime.tryParse(
        '${value['access_until']}',
      )?.toUtc();
      final startedAt = value['started_at'] == null
          ? null
          : DateTime.tryParse('${value['started_at']}')?.toUtc();
      final plan = switch (value['plan_id']) {
        'premium' => CommercePlan.premium,
        'premium_ai_coach' => CommercePlan.premiumAiCoach,
        _ => null,
      };
      final utcNow = now.toUtc();
      if (verifiedAt == null ||
          accessUntil == null ||
          plan == null ||
          verifiedAt.isAfter(utcNow.add(const Duration(minutes: 1))) ||
          accessUntil.isAfter(verifiedAt.add(_maximumLease)) ||
          !accessUntil.isAfter(utcNow) ||
          (startedAt?.isAfter(utcNow.add(const Duration(minutes: 1))) ??
              false)) {
        await clear(ownerId);
        return null;
      }
      return SubscriptionState(
        plan: plan,
        entitlements: PaidPlanCatalog.composedEntitlementsFor(plan),
        authority: EntitlementAuthority.verifiedServer,
        lifecycle: SubscriptionLifecycle.active,
        startedAt: startedAt,
        currentPeriodEndsAt: accessUntil,
        isPurchasable: false,
        canRestorePurchases: false,
      );
    } on Object {
      await clear(ownerId);
      return null;
    }
  }

  Future<void> clear(String ownerId) => _secureStore.delete('$_prefix$ownerId');
}
