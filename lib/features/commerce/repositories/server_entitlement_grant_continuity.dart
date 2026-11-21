part of 'server_entitlement_repository.dart';

// Continuity filtering and its existing state constructors share the
// original library, owner fences and storage. No new authority is added.
extension _ServerGrantContinuity on ServerEntitlementRepository {
  Future<SubscriptionState> _transientFallback(
    String ownerId,
    DateTime now,
  ) async {
    CommunityOwnerOperation.checkCurrent();
    if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
      return FreePlan.createState();
    }
    final inMemory = ServerEntitlementRepository._sessionCache.fallbackFor(
      ownerId: ownerId,
      now: now,
    );
    if (inMemory != null &&
        inMemory.provider != null &&
        _storeProofSurvivesDenial(ownerId, inMemory) &&
        _storeObservationIsCurrent(
          ownerId,
          inMemory,
          allowIndependentPriorLease: true,
        )) {
      return _withClosedTestContinuity(ownerId, inMemory);
    }
    try {
      final persisted = await _subscriptionStore.read(
        ownerId: ownerId,
        now: now,
      );
      CommunityOwnerOperation.checkCurrent();
      if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
        return FreePlan.createState();
      }
      final restored = _restoreStoreProof(ownerId, persisted);
      if (restored != null) {
        return _withClosedTestContinuity(ownerId, restored);
      }
    } on CommunityOwnerOperationCancelled {
      rethrow;
    } on Object {
      // A failed secure read cannot create access.
    }
    return _withClosedTestContinuity(ownerId, FreePlan.createState());
  }

  SubscriptionState _withClosedTestContinuity(
    String ownerId,
    SubscriptionState store, {
    bool allowContinuity = true,
    SubscriptionState? overrideGrant,
  }) {
    final effectiveNow = _now();
    final grant =
        overrideGrant ??
        (allowContinuity
            ? ServerEntitlementRepository._closedTestSessionCache.fallbackFor(
                ownerId: ownerId,
                now: effectiveNow,
              )
            : null);
    if (grant == null) return store;
    final storeBoundary = verifiedSubscriptionBoundary(store)?.toUtc();
    if (store.authority == EntitlementAuthority.verifiedServer &&
        store.plan != CommercePlan.free &&
        storeBoundary != null &&
        storeBoundary.isAfter(effectiveNow) &&
        !(store.startedAt?.toUtc().isAfter(effectiveNow) ?? false) &&
        PaidPlanCatalog.entryFor(store.plan).rank >=
            PaidPlanCatalog.entryFor(grant.plan).rank) {
      return store;
    }
    return grant;
  }

  SubscriptionState _revalidateClosedTestObservation(
    String ownerId,
    SubscriptionState state,
    int? observationGeneration, {
    bool allowContinuity = true,
  }) {
    CommunityOwnerOperation.checkCurrent();
    if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
      return FreePlan.createState();
    }
    // Store receipts remain independent. Only provider-null states from this
    // store read can represent the closed-test overlay; admin is composed
    // separately after this check.
    if (state.provider != null) {
      // Admin and optional persistence add awaits after the store read. Recheck
      // its strict publication version, denial floor and own interval now.
      final now = _now();
      final effective = verifiedSubscriptionPeriodAt(state, now);
      final boundary = verifiedSubscriptionBoundary(effective)?.toUtc();
      if (_storeProofSurvivesDenial(ownerId, state) &&
          (effective.plan == CommercePlan.free
              ? _storeNegativeObservationIsCurrent(ownerId, effective)
              : _storeObservationIsCurrent(ownerId, state) &&
                    effective.authority ==
                        EntitlementAuthority.verifiedServer &&
                    boundary != null &&
                    boundary.isAfter(now) &&
                    !(effective.startedAt?.toUtc().isAfter(now) ?? false))) {
        return allowContinuity
            ? _withClosedTestContinuity(ownerId, effective)
            : effective;
      }
      return allowContinuity
          ? _withClosedTestContinuity(ownerId, _survivingStoreProof(ownerId))
          : FreePlan.createState();
    }
    final boundary = verifiedSubscriptionBoundary(state)?.toUtc();
    if (observationGeneration ==
            ServerEntitlementRepository._settledClosedTestReadGeneration &&
        (state.plan == CommercePlan.free ||
            (boundary != null && boundary.isAfter(_now())))) {
      return state;
    }
    // Retired or expired responses may use only the latest independent,
    // bounded same-owner proof. A fallback never renews that proof's lease.
    return _withClosedTestContinuity(
      ownerId,
      allowContinuity ? _survivingStoreProof(ownerId) : FreePlan.createState(),
      allowContinuity: allowContinuity,
    );
  }

  SubscriptionState _verifiedFree({
    DateTime? verifiedAt,
    int? serverRevision,
    StoreRenewalObservation? storeRenewal,
    bool storeDefinitive = true,
  }) => SubscriptionState(
    storeRenewalObservation: storeRenewal,
    storeRenewalDefinitivelyInactive: storeDefinitive,
    verifiedAt: verifiedAt,
    serverRevision: serverRevision,
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

  SubscriptionState _withStoreRenewalObservation(
    SubscriptionState state,
    StoreRenewalObservation? observation, {
    bool definitiveInactive = false,
  }) => observation == null && !definitiveInactive
      ? state
      : SubscriptionState(
          plan: state.plan,
          entitlements: state.entitlements,
          authority: state.authority,
          lifecycle: state.lifecycle,
          provider: state.provider,
          startedAt: state.startedAt,
          currentPeriodEndsAt: state.currentPeriodEndsAt,
          trialEndsAt: state.trialEndsAt,
          gracePeriodEndsAt: state.gracePeriodEndsAt,
          verifiedAt: state.verifiedAt,
          serverRevision: state.serverRevision,
          storeOriginalTransactionId: state.storeOriginalTransactionId,
          verifiedNextPeriod: state.verifiedNextPeriod,
          isPurchasable: state.isPurchasable,
          canRestorePurchases: state.canRestorePurchases,
          storeRenewalObservation: observation,
          storeRenewalDefinitivelyInactive: definitiveInactive,
        );
}
