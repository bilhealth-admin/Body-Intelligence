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
import 'admin_entitlement_continuity_store.dart';
import 'verified_entitlement_continuity_store.dart';

/// Reads only the server-owned subscription snapshot.
///
/// Network failure fails closed when no previously verified entitlement is
/// available. A short, owner-scoped continuity window prevents a transient
/// read/replication failure from flickering a paid member back to Free, while
/// a valid terminal subscription row still revokes access immediately. It
/// never deletes user data and never treats local preferences, debug flags, or
/// a paywall selection as an entitlement.
final class ServerEntitlementRepository {
  const ServerEntitlementRepository({
    EntitlementResolver? resolver,
    AdminEntitlementContinuityStore? adminContinuityStore,
    VerifiedEntitlementContinuityStore? subscriptionContinuityStore,
  }) : _resolver = resolver ?? const EntitlementResolver(),
       _adminContinuityStoreOverride = adminContinuityStore,
       _subscriptionStoreOverride = subscriptionContinuityStore;

  final EntitlementResolver _resolver;
  final AdminEntitlementContinuityStore? _adminContinuityStoreOverride;
  final VerifiedEntitlementContinuityStore? _subscriptionStoreOverride;
  static final AdminEntitlementContinuityStore _defaultAdminContinuityStore =
      AdminEntitlementContinuityStore();
  AdminEntitlementContinuityStore get _adminContinuityStore =>
      _adminContinuityStoreOverride ?? _defaultAdminContinuityStore;
  static final _defaultSubscriptionStore = VerifiedEntitlementContinuityStore();
  VerifiedEntitlementContinuityStore get _subscriptionStore =>
      _subscriptionStoreOverride ?? _defaultSubscriptionStore;
  static final VerifiedEntitlementSessionCache _sessionCache =
      VerifiedEntitlementSessionCache();
  static final VerifiedEntitlementSessionCache _adminSessionCache =
      VerifiedEntitlementSessionCache(maximumAge: const Duration(minutes: 6));
  static final Set<String> _startupContinuityConsumed = <String>{};

  Future<SubscriptionState> current() async {
    if (!AppEnvironment.supabaseRuntimeReady) return FreePlan.createState();
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) return FreePlan.createState();
    // On a cold process, render a still-valid server lease from encrypted
    // storage before waiting for network timeouts. Consume this shortcut once
    // per owner so the observed provider's next scheduled refresh reaches the
    // server and renews or revokes the lease normally.
    if (_startupContinuityConsumed.add(ownerId)) {
      final now = DateTime.now().toUtc();
      try {
        final persistedAdmin = await _adminContinuityStore.read(
          ownerId: ownerId,
          now: now,
        );
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        if (persistedAdmin != null) {
          _adminSessionCache.remember(
            ownerId: ownerId,
            state: persistedAdmin,
            now: now,
          );
          return persistedAdmin;
        }

        final persistedSubscription = await _subscriptionStore.read(
          ownerId: ownerId,
          now: now,
        );
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        if (persistedSubscription != null) {
          _sessionCache.remember(
            ownerId: ownerId,
            state: persistedSubscription,
            now: now,
          );
          return persistedSubscription;
        }
      } on Object {
        // Continue to the authoritative network path when secure storage is
        // unavailable or corrupt.
      }
    }
    final store = await _storeCurrent();
    if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
    try {
      final grant = await client
          .rpc('bil_get_my_admin_subscription')
          .timeout(const Duration(seconds: 10));
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      final resolved = composeAdminSubscriptionAccess(
        store: store,
        grant: grant,
        ownerId: ownerId,
        now: DateTime.now().toUtc(),
      );
      _adminSessionCache.remember(
        ownerId: ownerId,
        state: resolved,
        now: DateTime.now().toUtc(),
      );
      if (identical(resolved, store)) {
        await _adminContinuityStore.clear(ownerId);
      } else {
        await _adminContinuityStore.remember(
          ownerId: ownerId,
          state: resolved,
          now: DateTime.now().toUtc(),
        );
      }
      return resolved;
    } on Object {
      // A transient RPC failure must not visibly switch a currently verified
      // admin lease between Premium and Free. Continuity is owner-scoped,
      // bounded to the exact server lease, and cannot cross owners. Secure
      // continuity also survives a process restart during that same lease.
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      final inMemory = _adminSessionCache.fallbackFor(
        ownerId: ownerId,
        now: DateTime.now().toUtc(),
      );
      if (inMemory != null) return inMemory;
      try {
        final persisted = await _adminContinuityStore.read(
          ownerId: ownerId,
          now: DateTime.now().toUtc(),
        );
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        if (persisted != null) {
          _adminSessionCache.remember(
            ownerId: ownerId,
            state: persisted,
            now: DateTime.now().toUtc(),
          );
          return persisted;
        }
      } on Object {
        // Secure storage is continuity only. Store authority still determines
        // access when the local encrypted slot is unavailable.
      }
      return store;
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
      var closedTestReadFailed = false;
      List<Map<String, dynamic>> closedTestRows;
      try {
        closedTestRows = await client
            .from('bil_ai_closed_test_grants')
            .select('active, expires_at')
            .eq('owner_id', user.id)
            .limit(1)
            .timeout(const Duration(seconds: 10));
      } on Object {
        // Closed-test is an independent, additive server authority. A
        // temporary failure to read that overlay must not skip the separate
        // verified Google/Apple subscription mirror for this same owner.
        // This catch grants nothing; the next lookup must still verify paid
        // access through its own provider, timestamps and lifecycle.
        // An independently verified Free subscription is not proof that the
        // unreadable additive grant is also Free.
        closedTestReadFailed = true;
        closedTestRows = const [];
      }
      final closedTestExpiresAt = closedTestRows.isEmpty
          ? null
          : DateTime.tryParse('${closedTestRows.first['expires_at']}')?.toUtc();
      final closedTestActive =
          closedTestRows.isNotEmpty &&
          closedTestRows.first['active'] == true &&
          closedTestExpiresAt != null &&
          closedTestExpiresAt.isAfter(now);
      if (closedTestActive) {
        return await _remember(
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
        return await _transientFallback(user.id, now);
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
        return await _transientFallback(user.id, now);
      }
      final plan = _planOrNull('${row['plan_id']}');
      if (plan == null) return await _transientFallback(user.id, now);
      if (plan == CommercePlan.free) {
        return closedTestReadFailed
            ? FreePlan.createState()
            : await _remember(user.id, _verifiedFree(), now);
      }
      final lifecycle = _lifecycleOrNull('${row['lifecycle']}');
      if (lifecycle == null) return await _transientFallback(user.id, now);
      final expiresAt = DateTime.tryParse('${row['expires_at']}')?.toUtc();
      final gracePeriodEndsAt = DateTime.tryParse(
        '${row['grace_period_ends_at']}',
      )?.toUtc();
      final provider = providerValue == 'apple'
          ? SubscriptionProvider.apple
          : providerValue == 'google'
          ? SubscriptionProvider.google
          : null;
      if (provider == null) return await _transientFallback(user.id, now);
      final accessBoundary = lifecycle == SubscriptionLifecycle.gracePeriod
          ? gracePeriodEndsAt
          : expiresAt;
      if (lifecycle.mayGrantPaidAccess && accessBoundary == null) {
        // A paid lifecycle without its boundary is malformed, not a verified
        // cancellation. Treat it like a transient read so the last valid
        // entitlement can carry the UI through replication/schema lag.
        return await _transientFallback(user.id, now);
      }
      if (lifecycle.mayGrantPaidAccess && !accessBoundary!.isAfter(now)) {
        // An expired store receipt does not prove that an unreadable separate
        // closed-test grant is revoked. Keep verification unresolved.
        return closedTestReadFailed
            ? FreePlan.createState()
            : await _remember(user.id, _verifiedFree(), now);
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
        return await _transientFallback(user.id, now);
      }
      if (closedTestReadFailed && resolved.plan == CommercePlan.free) {
        // A verified terminal store cannot be overridden by a cached paid
        // store receipt. An independently unreadable grant keeps the overall
        // subscription decision unverified, with protected Retry UI.
        return FreePlan.createState();
      }
      return await _remember(user.id, resolved, now);
    } on Object {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      return await _transientFallback(user.id, DateTime.now().toUtc());
    }
  }

  Future<SubscriptionState> _remember(
    String ownerId,
    SubscriptionState state,
    DateTime now,
  ) async {
    _sessionCache.remember(ownerId: ownerId, state: state, now: now);
    try {
      await _subscriptionStore.remember(
        ownerId: ownerId,
        state: state,
        now: now,
      );
    } on Object {
      // Secure continuity is an optimization. The verified in-memory result
      // remains authoritative for this process when secure storage is absent.
    }
    return state;
  }

  Future<SubscriptionState> _transientFallback(
    String ownerId,
    DateTime now,
  ) async {
    if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
      return FreePlan.createState();
    }
    final inMemory = _sessionCache.fallbackFor(ownerId: ownerId, now: now);
    if (inMemory != null) return inMemory;
    try {
      final persisted = await _subscriptionStore.read(
        ownerId: ownerId,
        now: now,
      );
      if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
        return FreePlan.createState();
      }
      if (persisted != null) {
        _sessionCache.remember(ownerId: ownerId, state: persisted, now: now);
        return persisted;
      }
    } on Object {
      // A failed secure read cannot create access.
    }
    return FreePlan.createState();
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
