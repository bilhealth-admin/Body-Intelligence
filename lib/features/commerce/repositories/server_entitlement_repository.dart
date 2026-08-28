import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/free_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_state.dart';

/// Reads only the server-owned subscription snapshot.
///
/// Network failure deliberately returns Free. It never deletes user data and
/// never treats local preferences, debug flags, or a paywall selection as an
/// entitlement.
final class ServerEntitlementRepository {
  const ServerEntitlementRepository({EntitlementResolver? resolver})
    : _resolver = resolver ?? const EntitlementResolver();

  final EntitlementResolver _resolver;
  static final VerifiedEntitlementSessionCache _sessionCache =
      VerifiedEntitlementSessionCache();

  Future<SubscriptionState> current() async {
    if (!AppEnvironment.supabaseRuntimeReady) {
      return FreePlan.createState();
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      final now = DateTime.now().toUtc();
      final closedTestRows = await client
          .from('bil_ai_closed_test_grants')
          .select('active, expires_at')
          .eq('owner_id', user.id)
          .limit(1);
      final closedTestExpiresAt = closedTestRows.isEmpty
          ? null
          : DateTime.tryParse('${closedTestRows.first['expires_at']}')?.toUtc();
      final closedTestActive =
          closedTestRows.isNotEmpty &&
          closedTestRows.first['active'] == true &&
          closedTestExpiresAt != null &&
          !now.isAfter(closedTestExpiresAt);
      final rows = await client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1);
      if (rows.isEmpty) {
        if (!closedTestActive) {
          return _remember(user.id, _verifiedFree(), now);
        }
        return _remember(
          user.id,
          _closedTestState(now: now, expiresAt: closedTestExpiresAt),
          now,
        );
      }
      final row = rows.first;
      final providerValue = '${row['provider']}'.trim();
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (!closedTestActive &&
          (verifiedAt == null ||
              (providerValue != 'closed_test' &&
                  (verifiedAt.isAfter(now.add(const Duration(minutes: 5))) ||
                      now.difference(verifiedAt) >
                          const Duration(hours: 72))))) {
        return _remember(user.id, FreePlan.createState(), now);
      }
      final plan = closedTestActive
          ? CommercePlan.premiumAiCoach
          : _plan('${row['plan_id']}');
      if (plan == CommercePlan.free) {
        return _remember(user.id, _verifiedFree(), now);
      }
      final lifecycle = closedTestActive
          ? SubscriptionLifecycle.active
          : _lifecycle('${row['lifecycle']}');
      final expiresAt = closedTestActive
          ? closedTestExpiresAt
          : DateTime.tryParse('${row['expires_at']}')?.toUtc();
      final provider = providerValue == 'apple'
          ? SubscriptionProvider.apple
          : providerValue == 'google'
          ? SubscriptionProvider.google
          : null;
      if (provider == null &&
          !closedTestActive &&
          providerValue != 'closed_test') {
        return _remember(user.id, FreePlan.createState(), now);
      }
      return _remember(
        user.id,
        _resolver.resolve(
          record: SubscriptionRecord(
            plan: plan,
            lifecycle: lifecycle,
            authorityVerified: true,
            provider: provider,
            startedAt: DateTime.tryParse('${row['started_at']}')?.toUtc(),
            currentPeriodEndsAt: expiresAt,
            trialEndsAt: lifecycle == SubscriptionLifecycle.trial
                ? expiresAt
                : null,
            gracePeriodEndsAt: DateTime.tryParse(
              '${row['grace_period_ends_at']}',
            )?.toUtc(),
          ),
          now: now,
        ),
        now,
      );
    } on Object {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      return _sessionCache.fallbackFor(
            ownerId: user.id,
            now: DateTime.now().toUtc(),
          ) ??
          FreePlan.createState();
    }
  }

  SubscriptionState _remember(
    String ownerId,
    SubscriptionState state,
    DateTime now,
  ) {
    _sessionCache.remember(ownerId: ownerId, state: state, now: now);
    return state;
  }

  SubscriptionState _verifiedFree() => SubscriptionState(
    plan: CommercePlan.free,
    entitlements: FreePlan.entitlements,
    authority: EntitlementAuthority.verifiedServer,
    lifecycle: SubscriptionLifecycle.inactive,
    isPurchasable: false,
    canRestorePurchases: false,
  );

  SubscriptionState _closedTestState({
    required DateTime now,
    required DateTime expiresAt,
  }) => _resolver.resolve(
    record: SubscriptionRecord(
      plan: CommercePlan.premiumAiCoach,
      lifecycle: SubscriptionLifecycle.active,
      authorityVerified: true,
      provider: null,
      startedAt: now,
      currentPeriodEndsAt: expiresAt,
    ),
    now: now,
  );

  CommercePlan _plan(String value) => switch (value.trim()) {
    'premium' => CommercePlan.premium,
    'premium_ai_coach' => CommercePlan.premiumAiCoach,
    // Read-only compatibility for receipts verified before the canonical
    // consumer tier migration. New registry rows cannot use these IDs.
    'pro' => CommercePlan.premium,
    'plus' || 'legacy_plus' => CommercePlan.plus,
    _ => CommercePlan.free,
  };

  SubscriptionLifecycle _lifecycle(String value) => switch (value) {
    'pending' => SubscriptionLifecycle.pending,
    'trial' => SubscriptionLifecycle.trial,
    'active' => SubscriptionLifecycle.active,
    'grace_period' => SubscriptionLifecycle.gracePeriod,
    'billing_retry' => SubscriptionLifecycle.billingRetry,
    'account_hold' => SubscriptionLifecycle.accountHold,
    'paused' => SubscriptionLifecycle.paused,
    'suspended' => SubscriptionLifecycle.suspended,
    'deferred' => SubscriptionLifecycle.deferred,
    'cancelled' => SubscriptionLifecycle.cancelled,
    'expired' => SubscriptionLifecycle.expired,
    'refunded' => SubscriptionLifecycle.refunded,
    'revoked' => SubscriptionLifecycle.revoked,
    _ => SubscriptionLifecycle.inactive,
  };
}

/// A short, owner-scoped continuity window for a previously server-verified
/// paid entitlement.
///
/// It is consulted only after a transient server read failure. A successful
/// Free response clears it immediately, it never crosses account boundaries,
/// and it never outlives either the entitlement period or five minutes. This
/// prevents route-to-route Premium/Free flicker without treating local state
/// as purchase authority.
final class VerifiedEntitlementSessionCache {
  VerifiedEntitlementSessionCache({
    this.maximumAge = const Duration(minutes: 5),
  });

  final Duration maximumAge;
  final Map<String, _VerifiedEntitlementCacheEntry> _entries = {};

  void remember({
    required String ownerId,
    required SubscriptionState state,
    required DateTime now,
  }) {
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.plan == CommercePlan.free) {
      _entries.remove(ownerId);
      return;
    }
    final entitlementBoundary = switch (state.lifecycle) {
      SubscriptionLifecycle.trial => state.trialEndsAt,
      SubscriptionLifecycle.gracePeriod => state.gracePeriodEndsAt,
      SubscriptionLifecycle.active ||
      SubscriptionLifecycle.cancelled => state.currentPeriodEndsAt,
      _ => null,
    };
    if (entitlementBoundary == null) {
      _entries.remove(ownerId);
      return;
    }
    final continuityBoundary = now.toUtc().add(maximumAge);
    final validUntil = entitlementBoundary.toUtc().isBefore(continuityBoundary)
        ? entitlementBoundary.toUtc()
        : continuityBoundary;
    if (!validUntil.isAfter(now.toUtc())) {
      _entries.remove(ownerId);
      return;
    }
    _entries[ownerId] = _VerifiedEntitlementCacheEntry(state, validUntil);
  }

  SubscriptionState? fallbackFor({
    required String ownerId,
    required DateTime now,
  }) {
    final entry = _entries[ownerId];
    if (entry == null) return null;
    if (now.toUtc().isAfter(entry.validUntil)) {
      _entries.remove(ownerId);
      return null;
    }
    return entry.state;
  }
}

final class _VerifiedEntitlementCacheEntry {
  const _VerifiedEntitlementCacheEntry(this.state, this.validUntil);

  final SubscriptionState state;
  final DateTime validUntil;
}
