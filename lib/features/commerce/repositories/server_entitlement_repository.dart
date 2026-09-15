import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/admin_subscription_access.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/free_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_state.dart';

/// Reads only the server-owned subscription snapshot.
///
/// Network failure fails closed when no previously verified entitlement is
/// available. A short, owner-scoped continuity window prevents a transient
/// read/replication failure from flickering a paid member back to Free, while
/// a valid terminal subscription row still revokes access immediately. It
/// never deletes user data and never treats local preferences, debug flags, or
/// a paywall selection as an entitlement.
final class ServerEntitlementRepository {
  const ServerEntitlementRepository({EntitlementResolver? resolver})
    : _resolver = resolver ?? const EntitlementResolver();

  final EntitlementResolver _resolver;
  static final VerifiedEntitlementSessionCache _sessionCache =
      VerifiedEntitlementSessionCache();

  Future<SubscriptionState> current() async {
    if (!AppEnvironment.supabaseRuntimeReady) return FreePlan.createState();
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) return FreePlan.createState();
    final store = await _storeCurrent();
    if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
    try {
      final grant = await client
          .rpc('bil_get_my_admin_subscription')
          .timeout(const Duration(seconds: 10));
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      return composeAdminSubscriptionAccess(
        store: store,
        grant: grant,
        ownerId: ownerId,
        now: DateTime.now().toUtc(),
      );
    } on Object {
      // A missing/new admin endpoint or a revoked grant must never erase a
      // verified store purchase. Admin grants are not put in the store cache.
      return client.auth.currentUser?.id == ownerId
          ? store
          : FreePlan.createState();
    }
  }

  Future<SubscriptionState> _storeCurrent() async {
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
          .limit(1)
          .timeout(const Duration(seconds: 10));
      final closedTestExpiresAt = closedTestRows.isEmpty
          ? null
          : DateTime.tryParse('${closedTestRows.first['expires_at']}')?.toUtc();
      final closedTestActive =
          closedTestRows.isNotEmpty &&
          closedTestRows.first['active'] == true &&
          closedTestExpiresAt != null &&
          closedTestExpiresAt.isAfter(now);
      if (closedTestActive) {
        return _remember(
          user.id,
          _closedTestState(now: now, expiresAt: closedTestExpiresAt),
          now,
        );
      }
      final rows = await client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (rows.isEmpty) {
        // An empty response can be produced while a just-verified purchase is
        // still replicating through Supabase. Do not erase the short-lived
        // verified continuity cache on that transient read.
        return _transientFallback(user.id, now);
      }
      final row = rows.first;
      final providerValue = row['provider']?.toString().trim().toLowerCase();
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (!isAcceptableServerVerificationTimestamp(
        verifiedAt: verifiedAt,
        now: now,
      )) {
        // A malformed/future timestamp is not an authoritative revocation;
        // it is an unreadable snapshot. Keep a previously verified member
        // visible for the bounded continuity window instead.
        return _transientFallback(user.id, now);
      }
      final plan = _planOrNull('${row['plan_id']}');
      if (plan == null) return _transientFallback(user.id, now);
      if (plan == CommercePlan.free) {
        return _remember(user.id, _verifiedFree(), now);
      }
      final lifecycle = _lifecycleOrNull('${row['lifecycle']}');
      if (lifecycle == null) return _transientFallback(user.id, now);
      final expiresAt = DateTime.tryParse('${row['expires_at']}')?.toUtc();
      final gracePeriodEndsAt = DateTime.tryParse(
        '${row['grace_period_ends_at']}',
      )?.toUtc();
      final provider = providerValue == 'apple'
          ? SubscriptionProvider.apple
          : providerValue == 'google'
          ? SubscriptionProvider.google
          : null;
      if (provider == null) return _transientFallback(user.id, now);
      final accessBoundary = lifecycle == SubscriptionLifecycle.gracePeriod
          ? gracePeriodEndsAt
          : expiresAt;
      if (lifecycle.mayGrantPaidAccess && accessBoundary == null) {
        // A paid lifecycle without its boundary is malformed, not a verified
        // cancellation. Treat it like a transient read so the last valid
        // entitlement can carry the UI through replication/schema lag.
        return _transientFallback(user.id, now);
      }
      if (lifecycle.mayGrantPaidAccess && !accessBoundary!.isAfter(now)) {
        // Expiration at the boundary is an authoritative loss of access.
        return _remember(user.id, _verifiedFree(), now);
      }
      final resolved = _resolver.resolve(
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
          gracePeriodEndsAt: gracePeriodEndsAt,
        ),
        now: now,
      );
      // The resolver can still fail closed for a future-dated/malformed
      // snapshot. Preserve the last valid paid state instead of converting
      // that unreadable response into a visible Free flicker.
      if (lifecycle.mayGrantPaidAccess && resolved.plan == CommercePlan.free) {
        return _transientFallback(user.id, now);
      }
      return _remember(user.id, resolved, now);
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

  SubscriptionState _transientFallback(String ownerId, DateTime now) =>
      _sessionCache.fallbackFor(ownerId: ownerId, now: now) ??
      FreePlan.createState();

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

  CommercePlan? _planOrNull(String value) => switch (value.trim()) {
    'premium' => CommercePlan.premium,
    'premium_ai_coach' => CommercePlan.premiumAiCoach,
    // Read-only compatibility for receipts verified before the canonical
    // consumer tier migration. New registry rows cannot use these IDs.
    'pro' => CommercePlan.premium,
    'plus' || 'legacy_plus' => CommercePlan.plus,
    'free' => CommercePlan.free,
    _ => null,
  };

  SubscriptionLifecycle? _lifecycleOrNull(String value) => switch (value) {
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
    _ => null,
  };
}

/// `bil_subscriptions` is a protected server mirror, so an active row remains
/// authoritative until its lifecycle boundary. `verified_at` must exist and
/// must not be implausibly in the future, but it is not a 72-hour lease: store
/// renewals can legitimately leave a still-active period unchanged for days.
bool isAcceptableServerVerificationTimestamp({
  required DateTime? verifiedAt,
  required DateTime now,
}) {
  if (verifiedAt == null) return false;
  return !verifiedAt.toUtc().isAfter(
    now.toUtc().add(const Duration(minutes: 5)),
  );
}

/// A short, owner-scoped continuity window for a previously server-verified
/// paid entitlement.
///
/// It is consulted only after a transient server read failure or an
/// unreadable/incomplete snapshot. A valid verified Free/terminal response
/// clears it immediately, it never crosses account boundaries, and it never
/// outlives either the entitlement period or five minutes. This prevents
/// route-to-route Premium/Free flicker without treating local state as
/// purchase authority.
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
    if (!entry.validUntil.isAfter(now.toUtc())) {
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
