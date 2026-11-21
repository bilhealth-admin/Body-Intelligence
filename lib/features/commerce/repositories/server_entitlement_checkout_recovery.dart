part of 'server_entitlement_repository.dart';

extension _ServerCheckoutRecovery on ServerEntitlementRepository {
  Future<SubscriptionState> _currentForExplicitCheckoutRecovery() async {
    try {
      if (!AppEnvironment.supabaseRuntimeReady) return FreePlan.createState();
      final client = Supabase.instance.client;
      final ownerId = client.auth.currentUser?.id;
      if (ownerId == null) return FreePlan.createState();
      final proof = _ExplicitCheckoutCanonicalRead();
      // This read is proof-only: no startup lease, cache initialization,
      // entitlement publication, receipt completion or Boost credit changes.
      return await CommunityOwnerOperation.run(
        client: client,
        ownerId: ownerId,
        action: (_) => _currentOwned(
          client,
          ownerId,
          requireFreshFreeProof: true,
          explicitCheckoutRead: proof,
        ),
      );
    } on CommunityOwnerOperationCancelled {
      return FreePlan.createState();
    } on Object {
      return FreePlan.createState();
    }
  }

  Future<SubscriptionState> _currentOwned(
    SupabaseClient client,
    String ownerId, {
    bool requireFreshFreeProof = false,
    _ExplicitCheckoutCanonicalRead? explicitCheckoutRead,
  }) async {
    // On a cold process, render a still-valid server lease from encrypted
    // storage before waiting for network timeouts. Consume this shortcut once
    // per owner so the observed provider's next scheduled refresh reaches the
    // server and renews or revokes the lease normally.
    if (!requireFreshFreeProof &&
        ServerEntitlementRepository._startupContinuityConsumed.add(ownerId)) {
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
          ServerEntitlementRepository._adminSessionCache.remember(
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
        final restored = _restoreStoreProof(ownerId, persistedSubscription);
        if (restored != null) {
          return persistedAdmin == null
              ? restored
              : _withAdminContinuity(restored, persistedAdmin);
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
      explicitCheckoutRead: explicitCheckoutRead,
      onVerifiedNoStorePaidSource: () => verifiedNoStorePaidSource = true,
      onClosedTestObservation: (generation) =>
          closedTestObservationGeneration = generation,
    );
    SubscriptionState currentStore() => _revalidateClosedTestObservation(
      ownerId,
      store,
      closedTestObservationGeneration,
      allowContinuity: explicitCheckoutRead == null,
    );
    CommunityOwnerOperation.checkCurrent();
    if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
    if (explicitCheckoutRead != null && !explicitCheckoutRead.complete) {
      return FreePlan.createState();
    }
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
      if (explicitCheckoutRead != null) {
        // Every store-source attempt advances the started generation, even
        // if its independent closed-test lookup fails. Do not resurrect a
        // snapshot superseded while this admin request was waiting.
        if (closedTestObservationGeneration !=
                ServerEntitlementRepository._closedTestReadGeneration ||
            closedTestObservationGeneration !=
                ServerEntitlementRepository._settledClosedTestReadGeneration ||
            (grant != null &&
                independentAdmin.authority !=
                    EntitlementAuthority.verifiedServer)) {
          return FreePlan.createState();
        }
      } else {
        ServerEntitlementRepository._adminSessionCache.remember(
          ownerId: ownerId,
          // This cache is exclusively the independent admin authority. A store
          // period must never reappear here after a later store revocation.
          state: independentAdmin,
          now: _now(),
        );
        try {
          await _adminContinuityStore.remember(
            ownerId: ownerId,
            state: independentAdmin,
            now: _now(),
          );
        } on CommunityOwnerOperationCancelled {
          rethrow;
        } on Object {
          // Optional continuity persistence cannot erase a fresh server proof.
        }
        CommunityOwnerOperation.checkCurrent();
        if (client.auth.currentUser?.id != ownerId) {
          return FreePlan.createState();
        }
      }
      // Neither encrypted storage nor the independent admin lookup may pin
      // an older closed-test snapshot across a later successful revocation.
      final effectiveStore = currentStore();
      if (explicitCheckoutRead != null) {
        final checkedAt = _now();
        final completeNegativeStore =
            verifiedNoStorePaidSource &&
            explicitCheckoutRead.complete &&
            effectiveStore.plan == CommercePlan.free;
        if (!completeNegativeStore &&
            !_explicitCheckoutSnapshotCurrent(effectiveStore, checkedAt)) {
          return FreePlan.createState();
        }
        final result =
            grant == null &&
                verifiedNoStorePaidSource &&
                effectiveStore.plan == CommercePlan.free
            ? _verifiedFree(verifiedAt: checkedAt)
            : composeAdminSubscriptionAccess(
                store: effectiveStore,
                grant: grant,
                ownerId: ownerId,
                now: checkedAt,
              );
        return _explicitCheckoutSnapshotCurrent(result, checkedAt)
            ? result
            : FreePlan.createState();
      }
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
    } on Object catch (error) {
      if (isVerifiedCommerceSessionInvalid(error)) rethrow;
      if (requireFreshFreeProof) return FreePlan.createState();
      // A transient RPC failure must not visibly switch a currently verified
      // admin lease between Premium and Free. Continuity is owner-scoped,
      // bounded to the exact server lease, and cannot cross owners. Secure
      // continuity also survives a process restart during that same lease.
      if (client.auth.currentUser?.id != ownerId) return FreePlan.createState();
      final inMemory = ServerEntitlementRepository._adminSessionCache
          .fallbackFor(ownerId: ownerId, now: _now());
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
          ServerEntitlementRepository._adminSessionCache.remember(
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
}

/// Fresh network provenance is independent from the row's verified_at. A valid
/// active server period may have an old verified_at and still be read freshly.
final class _ExplicitCheckoutCanonicalRead {
  bool closedTestReadComplete = false;
  bool storeReadComplete = false;
  bool _failed = false;
  bool get complete => !_failed && closedTestReadComplete && storeReadComplete;

  SubscriptionState unresolved() {
    _failed = true;
    return FreePlan.createState();
  }

  void observeClosedTestRows(List<Map<String, dynamic>> rows) {
    if (rows.length > 1) {
      unresolved();
      return;
    }
    if (rows.isNotEmpty) {
      final row = rows.single;
      final active = row['active'];
      final rawExpiry = row['expires_at'];
      final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
      // Source schema requires expires_at even after a grant is inactive.
      if (active is! bool || rawExpiry is! String || expiry == null) {
        unresolved();
        return;
      }
    }
    closedTestReadComplete = true;
  }
}

bool _explicitCheckoutSnapshotCurrent(SubscriptionState state, DateTime now) {
  if (state.authority != EntitlementAuthority.verifiedServer) return false;
  if (state.plan == CommercePlan.free) return true;
  final boundary = verifiedSubscriptionBoundary(state)?.toUtc();
  return boundary != null &&
      boundary.isAfter(now.toUtc()) &&
      !(state.startedAt?.toUtc().isAfter(now.toUtc()) ?? false);
}
