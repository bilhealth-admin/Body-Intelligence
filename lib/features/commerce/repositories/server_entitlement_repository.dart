import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../community/services/community_owner_operation.dart';
import '../../auth/retryable_auth_session.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_renewal_observation.dart';
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
part 'server_entitlement_row_decoding.dart';
part 'server_entitlement_checkout_recovery.dart';

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

  Future<SubscriptionState> current() => _current();

  /// Fresh proof for an explicit checkout presentation recovery, never UI continuity.
  Future<SubscriptionState> currentForExplicitCheckoutRecovery() =>
      _currentForExplicitCheckoutRecovery();

  /// An explicit store-recovery action needs a new complete network read.
  /// Startup continuity and an unreadable independent grant cannot certify
  /// Free for the purpose of retiring an old checkout presentation blocker.
  Future<SubscriptionState> currentForExplicitStoreRecovery() =>
      _current(requireFreshFreeProof: true);

  Future<SubscriptionState> _current({
    bool requireFreshFreeProof = false,
  }) async {
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
      retainSessionOnRetryableAuthReadError: !requireFreshFreeProof,
      action: (_) => _currentOwned(
        client,
        ownerId,
        requireFreshFreeProof: requireFreshFreeProof,
      ),
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
      onError: (Object error, StackTrace _) {
        if (isSameOwnerRetryableAuthReadFailure(
          error,
          auth: client.auth,
          previousOwnerId: _activeOwnerId,
        )) {
          return;
        }
        _sessionCache.discardPendingPeriods();
      },
    );
  }

  Future<SubscriptionState> _storeCurrent({
    void Function()? onVerifiedNoStorePaidSource,
    void Function(int generation)? onClosedTestObservation,
    _ExplicitCheckoutCanonicalRead? explicitCheckoutRead,
  }) async {
    SubscriptionState? freshClosedTest;
    Future<SubscriptionState> fallback(String ownerId, DateTime now) =>
        explicitCheckoutRead == null
        ? _transientFallback(ownerId, now)
        : Future.value(explicitCheckoutRead.unresolved());
    Future<SubscriptionState> remember(
      String ownerId,
      SubscriptionState state,
      DateTime now,
    ) => explicitCheckoutRead == null
        ? _remember(ownerId, state, now)
        : Future.value(state);
    void recordVersion(
      String ownerId,
      DateTime verifiedAt,
      int? revision,
      String? provider,
      String? lineage,
    ) {
      if (explicitCheckoutRead == null) {
        _recordStoreVersion(ownerId, verifiedAt, revision, provider, lineage);
      }
    }

    void clearPending(String ownerId) {
      if (explicitCheckoutRead == null) {
        _sessionCache.discardPendingPeriods(ownerId: ownerId);
      }
    }

    SubscriptionState withClosed(String ownerId, SubscriptionState state) =>
        _withClosedTestContinuity(
          ownerId,
          state,
          allowContinuity: explicitCheckoutRead == null,
          overrideGrant: freshClosedTest,
        );
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
        explicitCheckoutRead?.unresolved();
        closedTestRows = const [];
      }
      CommunityOwnerOperation.checkCurrent();
      if (client.auth.currentUser?.id != user.id) return FreePlan.createState();
      if (!closedTestReadFailed && explicitCheckoutRead != null) {
        explicitCheckoutRead.observeClosedTestRows(closedTestRows);
        if (!explicitCheckoutRead.closedTestReadComplete) {
          closedTestReadFailed = true;
        }
      }
      if (!closedTestReadFailed) {
        if (closedTestReadGeneration < _settledClosedTestReadGeneration) {
          // A retired response cannot restore a grant after newer revocation,
          // or clear a newer verified grant. Its own observation is unknown.
          closedTestReadFailed = true;
          explicitCheckoutRead?.unresolved();
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
        if (explicitCheckoutRead != null) {
          // A positive grant is fresh, but strict recovery still reads the
          // separate store source before certifying a complete snapshot.
          freshClosedTest = _closedTestState(
            now: now,
            expiresAt: closedTestExpiresAt,
          );
        } else {
          final continuityBoundary = now.add(
            _closedTestSessionCache.maximumAge,
          );
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
      }
      if (!closedTestReadFailed && explicitCheckoutRead == null) {
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
      if (explicitCheckoutRead != null && rows.length > 1) {
        return explicitCheckoutRead.unresolved();
      }
      if (rows.isEmpty) {
        // An empty store mirror can briefly follow a successful purchase.
        // Preserve an existing, still-valid paid continuity lease. Only a
        // successful closed-test read AND a successful admin RPC with a null
        // grant can later establish verified Free. A failed read stays
        // unverified, so the premium gate never mistakes network failure for
        // a real revocation.
        if (explicitCheckoutRead != null) {
          explicitCheckoutRead.storeReadComplete = true;
        }
        final previous = explicitCheckoutRead == null
            ? await fallback(user.id, now)
            : withClosed(user.id, FreePlan.createState());
        if (!closedTestReadFailed &&
            previous.authority == EntitlementAuthority.localDefault &&
            previous.plan == CommercePlan.free) {
          onVerifiedNoStorePaidSource?.call();
        }
        return previous;
      }
      final row = rows.first;
      if (row['owner_id'] != user.id) {
        clearPending(user.id);
        return await fallback(user.id, now);
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
        return await fallback(user.id, now);
      }
      final plan = _planOrNull('${row['plan_id']}');
      if (plan == null) return await fallback(user.id, now);
      final rawRevision = row['revision'];
      final revision = rawRevision is int && rawRevision > 0
          ? rawRevision
          : null;
      if (explicitCheckoutRead != null &&
          (providerValue != 'apple' && providerValue != 'google' ||
              _lifecycleOrNull('${row['lifecycle']}') == null ||
              revision == null ||
              const ['started_at', 'expires_at', 'grace_period_ends_at'].any(
                (key) =>
                    row[key] != null &&
                    (row[key] is! String ||
                        DateTime.tryParse(row[key] as String) == null),
              ))) {
        return explicitCheckoutRead.unresolved();
      }
      if (plan == CommercePlan.free) {
        if (explicitCheckoutRead != null) {
          explicitCheckoutRead.storeReadComplete = true;
        }
        recordVersion(user.id, verifiedAt!, revision, providerValue, lineage);
        final denied = explicitCheckoutRead == null
            ? await _remember(
                user.id,
                _verifiedFree(
                  verifiedAt: verifiedAt,
                  storeDefinitive:
                      providerValue == 'google' || providerValue == 'apple',
                ),
                now,
              )
            : _verifiedFree(
                verifiedAt: verifiedAt,
                storeDefinitive:
                    providerValue == 'google' || providerValue == 'apple',
              );
        return closedTestReadFailed
            ? withClosed(user.id, FreePlan.createState())
            : explicitCheckoutRead == null
            ? denied
            : withClosed(user.id, denied);
      }
      final lifecycle = _lifecycleOrNull('${row['lifecycle']}');
      if (lifecycle == null) return await fallback(user.id, now);
      if (!lifecycle.mayGrantPaidAccess) {
        // A verified terminal response always retires scheduled activation,
        // including when an independent grant cannot currently be read.
        recordVersion(user.id, verifiedAt!, revision, providerValue, lineage);
        await remember(user.id, _verifiedFree(verifiedAt: verifiedAt), now);
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
      if (provider == null) return await fallback(user.id, now);
      final accessBoundary = lifecycle == SubscriptionLifecycle.gracePeriod
          ? gracePeriodEndsAt
          : expiresAt;
      final startedAt = DateTime.tryParse('${row['started_at']}')?.toUtc();
      if (lifecycle.mayGrantPaidAccess &&
          ((row['started_at'] != null && startedAt == null) ||
              (startedAt != null &&
                  accessBoundary != null &&
                  !accessBoundary.isAfter(startedAt)))) {
        clearPending(user.id);
        return await fallback(user.id, now);
      }
      if (lifecycle.mayGrantPaidAccess && accessBoundary == null) {
        // A paid lifecycle without its boundary is malformed, not a verified
        // cancellation. Treat it like a transient read so the last valid
        // entitlement can carry the UI through replication/schema lag.
        return await fallback(user.id, now);
      }
      final storeDefinitive =
          (provider == SubscriptionProvider.google ||
              provider == SubscriptionProvider.apple) &&
          (storeRenewalTerminalLifecycle(lifecycle.name, row['auto_renews']) ||
              (accessBoundary != null &&
                  !accessBoundary.isAfter(now) &&
                  (row['auto_renews'] == false ||
                      lifecycle == SubscriptionLifecycle.cancelled)));
      final storeRenewal = StoreRenewalObservation.fromCanonicalRow(
        row,
        ownerId: user.id,
      );
      if (lifecycle.mayGrantPaidAccess && !accessBoundary!.isAfter(now)) {
        if (explicitCheckoutRead != null) {
          explicitCheckoutRead.storeReadComplete = true;
        }
        // An expired store receipt does not prove that an unreadable separate
        // closed-test grant is revoked. Keep verification unresolved.
        recordVersion(user.id, verifiedAt!, revision, providerValue, lineage);
        final denied = explicitCheckoutRead == null
            ? await _remember(
                user.id,
                _verifiedFree(
                  verifiedAt: verifiedAt,
                  storeRenewal: storeRenewal,
                  storeDefinitive: storeDefinitive,
                ),
                now,
              )
            : _verifiedFree(
                verifiedAt: verifiedAt,
                storeRenewal: storeRenewal,
                storeDefinitive: storeDefinitive,
              );
        return closedTestReadFailed
            ? withClosed(user.id, FreePlan.createState())
            : explicitCheckoutRead == null
            ? denied
            : withClosed(user.id, denied);
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
        clearPending(user.id);
        return await fallback(user.id, now);
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
      final resolved = _withStoreRenewalObservation(
        _resolver.resolve(record: record, now: now),
        storeRenewal,
        definitiveInactive: storeDefinitive,
      );
      // The resolver can still fail closed for a future-dated/malformed
      // snapshot. Preserve the last valid paid state instead of converting
      // that unreadable response into a visible Free flicker.
      if (lifecycle.mayGrantPaidAccess && resolved.plan == CommercePlan.free) {
        final previous = await fallback(user.id, now);
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
          recordVersion(user.id, verifiedAt!, revision, providerValue, lineage);
          return await remember(
            user.id,
            previous.withVerifiedNextPeriod(next),
            now,
          );
        }
        clearPending(user.id);
        return _withStoreRenewalObservation(
          previous.withVerifiedNextPeriod(null),
          storeRenewal,
        );
      }
      if (closedTestReadFailed && resolved.plan == CommercePlan.free) {
        // Never resurrect a terminal store receipt. Only the independently
        // verified, bounded closed-test proof can survive its own read outage.
        return withClosed(user.id, FreePlan.createState());
      }
      if (explicitCheckoutRead != null) {
        explicitCheckoutRead.storeReadComplete = true;
      }
      recordVersion(user.id, verifiedAt!, revision, providerValue, lineage);
      final remembered = await remember(user.id, resolved, now);
      return withClosed(user.id, remembered);
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } on Object {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return FreePlan.createState();
      return await fallback(user.id, _now());
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
