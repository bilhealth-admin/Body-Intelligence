import 'dart:async';
import 'dart:convert';

import '../domain/commerce_plan.dart';
import '../domain/paid_plan_catalog.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_state.dart';
import 'admin_entitlement_continuity_store.dart';

/// Encrypted, owner-scoped continuity for the last server-verified paid state.
///
/// This never creates entitlement authority. It only preserves facts already
/// verified by BIL's server, and it can never outlive the exact billing
/// boundary carried by that state. A later authoritative Free or terminal
/// response clears the stored snapshot immediately.
final class VerifiedEntitlementContinuityStore {
  VerifiedEntitlementContinuityStore({AdminEntitlementSecureStore? secureStore})
    : _secureStore = secureStore ?? FlutterAdminEntitlementSecureStore();

  static const _prefix = 'bil.verified-entitlement.v1.';
  // All instances share the same encrypted owner slot. Serialize its existing
  // operations so an old held write/cleanup cannot overwrite a newer receipt.
  static final Map<String, Future<void>> _pending = {};

  Future<T> _serialized<T>(String ownerId, Future<T> Function() action) {
    final previous = _pending[ownerId] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[ownerId] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_pending[ownerId], settled)) _pending.remove(ownerId);
      }),
    );
    return result;
  }

  final AdminEntitlementSecureStore _secureStore;

  Future<void> remember({
    required String ownerId,
    required SubscriptionState state,
    required DateTime now,
  }) => _serialized(ownerId, () => _remember(ownerId, state, now));

  Future<void> _remember(
    String ownerId,
    SubscriptionState state,
    DateTime now,
  ) async {
    final boundary = verifiedSubscriptionPriorBoundary(state);
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.plan == CommercePlan.free ||
        !state.lifecycle.mayGrantPaidAccess ||
        boundary == null ||
        !boundary.toUtc().isAfter(now.toUtc())) {
      try {
        await _clear(ownerId);
      } on Object {
        if (state.authority != EntitlementAuthority.verifiedServer ||
            state.plan != CommercePlan.free) {
          rethrow;
        }
        // If delete is unavailable but writes still work, retire the old paid
        // payload in its existing encrypted slot for the next process too.
        await _secureStore.write(
          '$_prefix$ownerId',
          jsonEncode({'owner_id': ownerId, 'retired_paid_proof': true}),
        );
      }
      return;
    }

    await _secureStore.write(
      '$_prefix$ownerId',
      jsonEncode(<String, Object?>{
        'owner_id': ownerId,
        'plan_id': state.plan.id,
        'lifecycle': _lifecycleId(state.lifecycle),
        'provider': _providerId(state.provider),
        'cached_at': now.toUtc().toIso8601String(),
        'started_at': state.startedAt?.toUtc().toIso8601String(),
        'access_until': boundary.toUtc().toIso8601String(),
        'original_transaction_id': state.storeOriginalTransactionId,
        'verified_at': state.verifiedAt?.toUtc().toIso8601String(),
        'server_revision': state.serverRevision,
      }),
    );
  }

  Future<SubscriptionState?> read({
    required String ownerId,
    required DateTime now,
  }) => _serialized(ownerId, () => _read(ownerId, now));

  Future<SubscriptionState?> _read(String ownerId, DateTime now) async {
    final encoded = await _secureStore.read('$_prefix$ownerId');
    if (encoded == null) return null;

    try {
      final value = jsonDecode(encoded);
      if (value is! Map || value['owner_id'] != ownerId) {
        await _clear(ownerId);
        return null;
      }

      if (value['retired_paid_proof'] == true) return null;

      final rawProvider = value['provider'];
      if (rawProvider != null &&
          rawProvider != 'apple' &&
          rawProvider != 'google' &&
          rawProvider != 'web') {
        await _clear(ownerId);
        return null;
      }

      final plan = _plan(value['plan_id']);
      final lifecycle = _lifecycle(value['lifecycle']);
      final provider = _provider(rawProvider);
      final cachedAt = DateTime.tryParse('${value['cached_at']}')?.toUtc();
      final startedAt = value['started_at'] == null
          ? null
          : DateTime.tryParse('${value['started_at']}')?.toUtc();
      final accessUntil = DateTime.tryParse(
        '${value['access_until']}',
      )?.toUtc();
      final utcNow = now.toUtc();

      if (plan == null ||
          lifecycle == null ||
          !lifecycle.mayGrantPaidAccess ||
          cachedAt == null ||
          cachedAt.isAfter(utcNow.add(const Duration(minutes: 1))) ||
          accessUntil == null ||
          !accessUntil.isAfter(utcNow) ||
          (startedAt?.isAfter(utcNow.add(const Duration(minutes: 1))) ??
              false)) {
        await _clear(ownerId);
        return null;
      }

      return SubscriptionState(
        plan: plan,
        entitlements: PaidPlanCatalog.composedEntitlementsFor(plan),
        authority: EntitlementAuthority.verifiedServer,
        lifecycle: lifecycle,
        provider: provider,
        startedAt: startedAt,
        storeOriginalTransactionId: value['original_transaction_id'] is String
            ? value['original_transaction_id'] as String
            : null,
        verifiedAt: DateTime.tryParse('${value['verified_at']}')?.toUtc(),
        serverRevision: value['server_revision'] is int
            ? value['server_revision'] as int
            : null,
        currentPeriodEndsAt: switch (lifecycle) {
          SubscriptionLifecycle.active ||
          SubscriptionLifecycle.cancelled => accessUntil,
          _ => null,
        },
        trialEndsAt: lifecycle == SubscriptionLifecycle.trial
            ? accessUntil
            : null,
        gracePeriodEndsAt: lifecycle == SubscriptionLifecycle.gracePeriod
            ? accessUntil
            : null,
        isPurchasable: false,
        canRestorePurchases: provider != null,
      );
    } on Object {
      await _clear(ownerId);
      return null;
    }
  }

  Future<void> clear(String ownerId) =>
      _serialized(ownerId, () => _clear(ownerId));

  Future<void> _clear(String ownerId) =>
      _secureStore.delete('$_prefix$ownerId');

  String _lifecycleId(SubscriptionLifecycle lifecycle) => switch (lifecycle) {
    SubscriptionLifecycle.trial => 'trial',
    SubscriptionLifecycle.active => 'active',
    SubscriptionLifecycle.gracePeriod => 'grace_period',
    SubscriptionLifecycle.cancelled => 'cancelled',
    _ => throw ArgumentError.value(lifecycle, 'lifecycle'),
  };

  String? _providerId(SubscriptionProvider? provider) => switch (provider) {
    SubscriptionProvider.apple => 'apple',
    SubscriptionProvider.google => 'google',
    SubscriptionProvider.web => 'web',
    null => null,
  };

  SubscriptionProvider? _provider(Object? value) => switch (value) {
    'apple' => SubscriptionProvider.apple,
    'google' => SubscriptionProvider.google,
    'web' => SubscriptionProvider.web,
    null => null,
    _ => null,
  };

  SubscriptionLifecycle? _lifecycle(Object? value) => switch (value) {
    'trial' => SubscriptionLifecycle.trial,
    'active' => SubscriptionLifecycle.active,
    'grace_period' => SubscriptionLifecycle.gracePeriod,
    'cancelled' => SubscriptionLifecycle.cancelled,
    _ => null,
  };

  CommercePlan? _plan(Object? value) => switch (value) {
    'premium' => CommercePlan.premium,
    'premium_ai_coach' => CommercePlan.premiumAiCoach,
    'plus' => CommercePlan.plus,
    'pro' => CommercePlan.pro,
    _ => null,
  };
}
