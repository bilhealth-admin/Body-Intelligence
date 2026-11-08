import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../community/services/community_owner_operation.dart';
import '../domain/commerce_plan.dart';
import '../domain/admin_subscription_access.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/free_plan.dart';
import '../domain/paid_plan_catalog.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_state.dart';
import 'admin_entitlement_continuity_store.dart';
import 'verified_entitlement_continuity_store.dart';
import 'verified_entitlement_session_cache.dart';

export 'verified_entitlement_session_cache.dart';

part 'server_entitlement_grant_continuity.dart';

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
    DateTime Function()? clock,
  }) : _resolver = resolver ?? const EntitlementResolver(),
       _adminContinuityStoreOverride = adminContinuityStore,
       _subscriptionStoreOverride = subscriptionContinuityStore,
       _clock = clock ?? DateTime.now;

  final EntitlementResolver _resolver;
  final AdminEntitlementContinuityStore? _adminContinuityStoreOverride;
  final VerifiedEntitlementContinuityStore? _subscriptionStoreOverride;
  final DateTime Function() _clock;
  DateTime _now() => _clock().toUtc();
  static final AdminEntitlementContinuityStore _defaultAdminContinuityStore =
      AdminEntitlementContinuityStore();
  AdminEntitlementContinuityStore get _adminContinuityStore =>
      _adminContinuityStoreOverride ?? _defaultAdminContinuityStore;
  static final _defaultSubscriptionStore = VerifiedEntitlementContinuityStore();
  VerifiedEntitlementContinuityStore get _subscriptionStore =>
      _subscriptionStoreOverride ?? _defaultSubscriptionStore;
  static final VerifiedEntitlementSessionCache _sessionCache =
      VerifiedEntitlementSessionCache();
  // Only a successful closed-test read populates this independent authority.
  // Store revocation cannot revoke it; failed reads cannot renew its lease.
  static VerifiedEntitlementSessionCache _closedTestSessionCache =
      VerifiedEntitlementSessionCache();
  static int _closedTestReadGeneration = 0;
  static int _settledClosedTestReadGeneration = 0;
  static final VerifiedEntitlementSessionCache _adminSessionCache =
      VerifiedEntitlementSessionCache(maximumAge: const Duration(minutes: 6));
  static final Set<String> _startupContinuityConsumed = <String>{};
  static String? _activeOwnerId;
  static SupabaseClient? _observedClient;
  static StreamSubscription<AuthState>? _ownerChanges;
  static final Map<
    String,
    ({DateTime verifiedAt, int? revision, String? provider, String? lineage})
  >
  _latestStoreVersions = {};

  Future<SubscriptionState> current() async {
    if (!AppEnvironment.supabaseRuntimeReady) return FreePlan.createState();
    final client = Supabase.instance.client;
    _observeOwnerChanges(client);
    final ownerId = client.auth.currentUser?.id;
    if (ownerId != _activeOwnerId) {
      // A future activation is session-only. Retire it even for A -> B -> A;
      // the returning owner must obtain that future receipt again.
      _sessionCache.discardPendingPeriods();
      _closedTestSessionCache = VerifiedEntitlementSessionCache();
      _activeOwnerId = ownerId;
    }
    if (ownerId == null) return FreePlan.createState();
    // Reuse the app transport's existing auth fence. UID equality alone does
    // not retire A -> B -> A; the zone also checks after SDK token resolution.
    return CommunityOwnerOperation.run(
      client: client,
      ownerId: ownerId,
      action: (_) => _currentOwned(client, ownerId),
    );
  }

  void _observeOwnerChanges(SupabaseClient client) {
    if (identical(_observedClient, client)) return;
    unawaited(_ownerChanges?.cancel());
    _sessionCache.discardPendingPeriods();
    _closedTestSessionCache = VerifiedEntitlementSessionCache();
    _observedClient = client;
    _activeOwnerId = client.auth.currentUser?.id;
    _ownerChanges = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session == null && state.event != AuthChangeEvent.signedOut) {
          return;
        }
        final nextOwner = state.session?.user.id;
        if (nextOwner != _activeOwnerId) {
          _sessionCache.discardPendingPeriods();
          _closedTestSessionCache = VerifiedEntitlementSessionCache();
          _activeOwnerId = nextOwner;
        }
      },
      onError: (Object _, StackTrace _) {
        _sessionCache.discardPendingPeriods();
      },
    );
  }

  Future<SubscriptionState> _currentOwned(
    SupabaseClient client,
    String ownerId,
  ) async {
    // On a cold process, render a still-valid server lease from encrypted
    // storage before waiting for network timeouts. Consume this shortcut once
    // per owner so the observed provider's next scheduled refresh reaches the
    // server and renews or revokes the lease normally.
    if (_startupContinuityConsumed.add(ownerId)) {
      final now = _now();
      SubscriptionState? persistedAdmin;
      try {
        persistedAdmin = await _adminContinuityStore.read(
          ownerId: ownerId,
          now: now,
        );
        CommunityOwnerOperation.checkCurrent();
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        if (persistedAdmin != null) {
          _adminSessionCache.remember(
            ownerId: ownerId,
            state: persistedAdmin,
            now: now,
          );
        }

        final persistedSubscription = await _subscriptionStore.read(
          ownerId: ownerId,
          now: now,
        );
        CommunityOwnerOperation.checkCurrent();
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        // Legacy provider-null storage does not identify an independent grant.
        // Confirm that source again rather than turning it into fresh proof.
        if (persistedSubscription != null &&
            persistedSubscription.provider != null) {
          _rememberRestoredStoreVersion(ownerId, persistedSubscription);
          _sessionCache.remember(
            ownerId: ownerId,
            state: persistedSubscription,
            now: now,
          );
          return persistedAdmin == null
              ? persistedSubscription
              : _withAdminContinuity(persistedSubscription, persistedAdmin);
        }
        if (persistedAdmin != null) return persistedAdmin;
      } on CommunityOwnerOperationCancelled {
        rethrow;
      } on Object {
        // Continue to the authoritative network path when secure storage is
        // unavailable or corrupt.
        CommunityOwnerOperation.checkCurrent();
        if (persistedAdmin != null && client.auth.currentUser?.id == ownerId) {
          return persistedAdmin;
        }
      }
    }
    // A verified empty store/closed-test read is only a negative paid-source
    // witness. Do not treat it as Free until the independent admin RPC also
    // succeeds and explicitly returns no active grant.
    var verifiedNoStorePaidSource = false;
    int? closedTestObservationGeneration;
    final store = await _storeCurrent(
      onVerifiedNoStorePaidSource: () => verifiedNoStorePaidSource = true,
      onClosedTestObservation: (generation) =>
          closedTestObservationGeneration = generation,
    );
    SubscriptionState currentStore() => _revalidateClosedTestObservation(
      ownerId,
      store,
      closedTestObservationGeneration,
    );
    CommunityOwnerOperation.checkCurrent();
    if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
    try {
      final grant = await client
          .rpc('bil_get_my_admin_subscription')
          .timeout(const Duration(seconds: 10));
      CommunityOwnerOperation.checkCurrent();
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      final independentAdmin = composeAdminSubscriptionAccess(
        store: FreePlan.createState(),
        grant: grant,
        ownerId: ownerId,
        now: _now(),
      );
      _adminSessionCache.remember(
        ownerId: ownerId,
        // This cache is exclusively the independent admin authority. A store
        // period must never reappear here after a later store revocation.
        state: independentAdmin,
        now: _now(),
      );
      await _adminContinuityStore.remember(
        ownerId: ownerId,
        state: independentAdmin,
        now: _now(),
      );
      // Neither encrypted storage nor the independent admin lookup may pin
      // an older closed-test snapshot across a later successful revocation.
      final effectiveStore = currentStore();
      return grant == null &&
              verifiedNoStorePaidSource &&
              effectiveStore.plan == CommercePlan.free
          ? _verifiedFree(verifiedAt: _now())
          : composeAdminSubscriptionAccess(
              store: effectiveStore,
              grant: grant,
              ownerId: ownerId,
              now: _now(),
            );
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } on Object {
      // A transient RPC failure must not visibly switch a currently verified
      // admin lease between Premium and Free. Continuity is owner-scoped,
      // bounded to the exact server lease, and cannot cross owners. Secure
      // continuity also survives a process restart during that same lease.
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      final inMemory = _adminSessionCache.fallbackFor(
        ownerId: ownerId,
        now: _now(),
      );
      if (inMemory != null) {
        return _withAdminContinuity(currentStore(), inMemory);
      }
      try {
        final persisted = await _adminContinuityStore.read(
          ownerId: ownerId,
          now: _now(),
        );
        CommunityOwnerOperation.checkCurrent();
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
        if (persisted != null) {
          _adminSessionCache.remember(
            ownerId: ownerId,
            state: persisted,
            now: _now(),
          );
          return _withAdminContinuity(currentStore(), persisted);
        }
      } on CommunityOwnerOperationCancelled {
        rethrow;
      } on Object {
        // Secure storage is continuity only. Store authority still determines
        // access when the local encrypted slot is unavailable.
      }
      return currentStore();
    }
  }

  Future<SubscriptionState> _storeCurrent({
    void Function()? onVerifiedNoStorePaidSource,
    void Function(int generation)? onClosedTestObservation,
  }) async {
    CommunityOwnerOperation.checkCurrent();
    if (!AppEnvironment.supabaseRuntimeReady) {
      return FreePlan.createState();
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      final now = _now();
      var closedTestReadFailed = false;
      final closedTestReadGeneration = ++_closedTestReadGeneration;
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
      CommunityOwnerOperation.checkCurrent();
      if (client.auth.currentUser?.id != user.id) return FreePlan.createState();
      if (!closedTestReadFailed) {
        if (closedTestReadGeneration < _settledClosedTestReadGeneration) {
          // A retired response cannot restore a grant after newer revocation,
          // or clear a newer verified grant. Its own observation is unknown.
          closedTestReadFailed = true;
          closedTestRows = const [];
        } else {
          _settledClosedTestReadGeneration = closedTestReadGeneration;
        }
      }
      onClosedTestObservation?.call(_settledClosedTestReadGeneration);
      final closedTestExpiresAt = closedTestRows.isEmpty
          ? null
          : DateTime.tryParse('${closedTestRows.first['expires_at']}')?.toUtc();
      final closedTestActive =
          closedTestRows.isNotEmpty &&
          closedTestRows.first['active'] == true &&
          closedTestExpiresAt != null &&
          closedTestExpiresAt.isAfter(now);
      if (closedTestActive) {
        final continuityBoundary = now.add(_closedTestSessionCache.maximumAge);
        _closedTestSessionCache.remember(
          ownerId: user.id,
          state: _closedTestState(
            now: now,
            expiresAt: closedTestExpiresAt.isBefore(continuityBoundary)
                ? closedTestExpiresAt
                : continuityBoundary,
          ),
          now: now,
        );
        final remembered = await _remember(
          user.id,
          _closedTestState(now: now, expiresAt: closedTestExpiresAt),
          now,
        );
        return _revalidateClosedTestObservation(
          user.id,
          remembered,
          closedTestReadGeneration,
        );
      }
      if (!closedTestReadFailed) {
        // A successful absent, inactive or expired grant retires its proof
        // immediately, even if the separate store lookup later fails.
        _closedTestSessionCache.remember(
          ownerId: user.id,
          state: FreePlan.createState(),
          now: now,
        );
      }
      final rows = await client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (rows.isEmpty) {
        // An empty store mirror can briefly follow a successful purchase.
        // Preserve an existing, still-valid paid continuity lease. Only a
        // successful closed-test read AND a successful admin RPC with a null
        // grant can later establish verified Free. A failed read stays
        // unverified, so the premium gate never mistakes network failure for
        // a real revocation.
        final previous = await _transientFallback(user.id, now);
        if (!closedTestReadFailed &&
            previous.authority == EntitlementAuthority.localDefault &&
            previous.plan == CommercePlan.free) {
          onVerifiedNoStorePaidSource?.call();
        }
        return previous;
      }
      final row = rows.first;
      if (row['owner_id'] != user.id) {
        _sessionCache.discardPendingPeriods(ownerId: user.id);
        return await _transientFallback(user.id, now);
      }
      final providerValue = row['provider']?.toString().trim().toLowerCase();
      final originalTransaction = row['original_transaction_id'];
      final lineage =
          originalTransaction is String && originalTransaction.isNotEmpty
          ? originalTransaction
          : null;
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
      final rawRevision = row['revision'];
      final revision = rawRevision is int && rawRevision > 0
          ? rawRevision
          : null;
      if (plan == CommercePlan.free) {
        _recordStoreVersion(
          user.id,
          verifiedAt!,
          revision,
          providerValue,
          lineage,
        );
        final denied = await _remember(
          user.id,
          _verifiedFree(verifiedAt: verifiedAt),
          now,
        );
        return closedTestReadFailed
            ? _withClosedTestContinuity(user.id, FreePlan.createState())
            : denied;
      }
      final lifecycle = _lifecycleOrNull('${row['lifecycle']}');
      if (lifecycle == null) return await _transientFallback(user.id, now);
      if (!lifecycle.mayGrantPaidAccess) {
        // A verified terminal response always retires scheduled activation,
        // including when an independent grant cannot currently be read.
        _recordStoreVersion(
          user.id,
          verifiedAt!,
          revision,
          providerValue,
          lineage,
        );
        await _remember(user.id, _verifiedFree(verifiedAt: verifiedAt), now);
      }
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
      final startedAt = DateTime.tryParse('${row['started_at']}')?.toUtc();
      if (lifecycle.mayGrantPaidAccess &&
          ((row['started_at'] != null && startedAt == null) ||
              (startedAt != null &&
                  accessBoundary != null &&
                  !accessBoundary.isAfter(startedAt)))) {
        _sessionCache.discardPendingPeriods(ownerId: user.id);
        return await _transientFallback(user.id, now);
      }
      if (lifecycle.mayGrantPaidAccess && accessBoundary == null) {
        // A paid lifecycle without its boundary is malformed, not a verified
        // cancellation. Treat it like a transient read so the last valid
        // entitlement can carry the UI through replication/schema lag.
        return await _transientFallback(user.id, now);
      }
      if (lifecycle.mayGrantPaidAccess && !accessBoundary!.isAfter(now)) {
        // An expired store receipt does not prove that an unreadable separate
        // closed-test grant is revoked. Keep verification unresolved.
        _recordStoreVersion(
          user.id,
          verifiedAt!,
          revision,
          providerValue,
          lineage,
        );
        final denied = await _remember(
          user.id,
          _verifiedFree(verifiedAt: verifiedAt),
          now,
        );
        return closedTestReadFailed
            ? _withClosedTestContinuity(user.id, FreePlan.createState())
            : denied;
      }
      final latest = _latestStoreVersions[user.id];
      if (lifecycle.mayGrantPaidAccess &&
          ((rawRevision != null && revision == null) ||
              (latest != null &&
                  (revision != null && latest.revision != null
                      ? revision < latest.revision!
                      : lineage != null &&
                            lineage == latest.lineage &&
                            providerValue == latest.provider &&
                            verifiedAt!.isBefore(latest.verifiedAt))))) {
        _sessionCache.discardPendingPeriods(ownerId: user.id);
        return await _transientFallback(user.id, now);
      }
      final record = SubscriptionRecord(
        plan: plan,
        lifecycle: lifecycle,
        authorityVerified: true,
        provider: provider,
        startedAt: startedAt,
        currentPeriodEndsAt: expiresAt,
        trialEndsAt: lifecycle == SubscriptionLifecycle.trial
            ? expiresAt
            : null,
        gracePeriodEndsAt: gracePeriodEndsAt,
        verifiedAt: verifiedAt,
        serverRevision: revision,
        storeOriginalTransactionId: lineage,
      );
      final resolved = _resolver.resolve(record: record, now: now);
      // The resolver can still fail closed for a future-dated/malformed
      // snapshot. Preserve the last valid paid state instead of converting
      // that unreadable response into a visible Free flicker.
      if (lifecycle.mayGrantPaidAccess && resolved.plan == CommercePlan.free) {
        final previous = await _transientFallback(user.id, now);
        final start = record.startedAt?.toUtc();
        final oldEnd = verifiedSubscriptionBoundary(previous)?.toUtc();
        // The row is valid future proof, rather than permission to extend the
        // old interval. Preserve it only for the same provider and contiguous
        // coverage; a gap, stale version or missing previous proof grants
        // nothing and must be read again once the new period has begun.
        if (start != null &&
            start.isAfter(now) &&
            accessBoundary != null &&
            accessBoundary.isAfter(start) &&
            previous.authority == EntitlementAuthority.verifiedServer &&
            previous.plan != CommercePlan.free &&
            previous.provider == provider &&
            oldEnd != null &&
            !start.isAfter(oldEnd) &&
            (previous.serverRevision != null && revision != null
                ? revision >= previous.serverRevision!
                : previous.storeOriginalTransactionId != lineage ||
                      previous.verifiedAt == null ||
                      !verifiedAt!.isBefore(previous.verifiedAt!))) {
          final next = _resolver.resolve(record: record, now: start);
          _recordStoreVersion(
            user.id,
            verifiedAt!,
            revision,
            providerValue,
            lineage,
          );
          return await _remember(
            user.id,
            previous.withVerifiedNextPeriod(next),
            now,
          );
        }
        _sessionCache.discardPendingPeriods(ownerId: user.id);
        return previous.withVerifiedNextPeriod(null);
      }
      if (closedTestReadFailed && resolved.plan == CommercePlan.free) {
        // Never resurrect a terminal store receipt. Only the independently
        // verified, bounded closed-test proof can survive its own read outage.
        return _withClosedTestContinuity(user.id, FreePlan.createState());
      }
      _recordStoreVersion(
        user.id,
        verifiedAt!,
        revision,
        providerValue,
        lineage,
      );
      final remembered = await _remember(user.id, resolved, now);
      return _withClosedTestContinuity(user.id, remembered);
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } on Object {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      return await _transientFallback(user.id, _now());
    }
  }

  void _recordStoreVersion(
    String ownerId,
    DateTime verifiedAt,
    int? revision,
    String? provider,
    String? lineage,
  ) {
    final previous = _latestStoreVersions[ownerId];
    if (previous?.revision != null &&
        (revision == null || previous!.revision! > revision)) {
      return;
    }
    _latestStoreVersions[ownerId] = (
      verifiedAt: verifiedAt,
      revision: revision,
      provider: provider,
      lineage: lineage,
    );
  }

  void _rememberRestoredStoreVersion(String ownerId, SubscriptionState state) {
    final verifiedAt = state.verifiedAt;
    if (verifiedAt == null || state.provider == null) return;
    _recordStoreVersion(
      ownerId,
      verifiedAt,
      state.serverRevision,
      state.provider!.name,
      state.storeOriginalTransactionId,
    );
  }

  SubscriptionState _withAdminContinuity(
    SubscriptionState store,
    SubscriptionState admin,
  ) {
    final boundary = verifiedSubscriptionBoundary(store);
    if (store.authority == EntitlementAuthority.verifiedServer &&
        store.plan != CommercePlan.free &&
        boundary != null &&
        !(store.startedAt?.isAfter(_now()) ?? false) &&
        boundary.isAfter(_now()) &&
        PaidPlanCatalog.entryFor(store.plan).rank >=
            PaidPlanCatalog.entryFor(admin.plan).rank) {
      return store;
    }
    return admin;
  }

  Future<SubscriptionState> _remember(
    String ownerId,
    SubscriptionState state,
    DateTime now,
  ) async {
    CommunityOwnerOperation.checkCurrent();
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
