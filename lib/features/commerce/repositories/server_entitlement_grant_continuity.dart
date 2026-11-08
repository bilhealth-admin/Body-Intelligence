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
    if (inMemory != null && inMemory.provider != null) {
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
      if (persisted != null && persisted.provider != null) {
        _rememberRestoredStoreVersion(ownerId, persisted);
        ServerEntitlementRepository._sessionCache.remember(
          ownerId: ownerId,
          state: persisted,
          now: now,
        );
        return _withClosedTestContinuity(ownerId, persisted);
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
    SubscriptionState store,
  ) {
    final effectiveNow = _now();
    final grant = ServerEntitlementRepository._closedTestSessionCache
        .fallbackFor(ownerId: ownerId, now: effectiveNow);
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
    int? observationGeneration,
  ) {
    CommunityOwnerOperation.checkCurrent();
    if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
      return FreePlan.createState();
    }
    // Store receipts remain independent. Only provider-null states from this
    // store read can represent the closed-test overlay; admin is composed
    // separately after this check.
    if (state.provider != null) return state;
    final boundary = verifiedSubscriptionBoundary(state)?.toUtc();
    if (observationGeneration ==
            ServerEntitlementRepository._settledClosedTestReadGeneration &&
        (state.plan == CommercePlan.free ||
            (boundary != null && boundary.isAfter(_now())))) {
      return state;
    }
    // Retired or expired responses may use only the latest independent,
    // bounded same-owner proof. A fallback never renews that proof's lease.
    return _withClosedTestContinuity(ownerId, FreePlan.createState());
  }

  SubscriptionState _verifiedFree({DateTime? verifiedAt}) => SubscriptionState(
    verifiedAt: verifiedAt,
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
}
