part of 'server_entitlement_repository.dart';

extension _ServerStoreContinuity on ServerEntitlementRepository {
  void _recordStoreVersion(
    String ownerId,
    DateTime verifiedAt,
    int? revision,
    String? provider,
    String? lineage, {
    bool denied = false,
  }) {
    if (denied) _recordStoreDenial(ownerId, verifiedAt, revision);
    final previous = ServerEntitlementRepository._latestStoreVersions[ownerId];
    if (previous?.revision != null &&
        (revision == null || previous!.revision! > revision)) {
      return;
    }
    ServerEntitlementRepository._latestStoreVersions[ownerId] = (
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

  void _recordStoreDenial(String ownerId, DateTime verifiedAt, int? revision) {
    final previous = ServerEntitlementRepository._storeDenials[ownerId];
    if (previous != null &&
        (previous.revision != null &&
                (revision == null || revision < previous.revision!) ||
            revision == previous.revision &&
                verifiedAt.isBefore(previous.verifiedAt))) {
      return;
    }
    ServerEntitlementRepository._storeDenials[ownerId] = (
      verifiedAt: verifiedAt.toUtc(),
      revision: revision,
    );
  }

  bool _storeProofSurvivesDenial(String ownerId, SubscriptionState state) {
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.plan == CommercePlan.free ||
        state.provider == null) {
      return true;
    }
    final denied = ServerEntitlementRepository._storeDenials[ownerId];
    if (denied == null) return true;
    if (denied.revision != null) {
      return state.serverRevision != null &&
          state.serverRevision! > denied.revision!;
    }
    return state.verifiedAt?.toUtc().isAfter(denied.verifiedAt) == true;
  }

  bool _storeObservationIsCurrent(String ownerId, SubscriptionState state) {
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.provider == null && state.plan != CommercePlan.free) {
      return true;
    }
    final latest = ServerEntitlementRepository._latestStoreVersions[ownerId];
    if (latest == null) return true;
    // A contiguous future period is part of this same remembered proof.
    final revision =
        state.verifiedNextPeriod?.serverRevision ?? state.serverRevision;
    if (latest.revision != null) {
      return revision != null && revision >= latest.revision!;
    }
    final verifiedAt = state.verifiedNextPeriod?.verifiedAt ?? state.verifiedAt;
    return verifiedAt == null ||
        !verifiedAt.toUtc().isBefore(latest.verifiedAt);
  }

  SubscriptionState _survivingStoreProof(String ownerId) {
    final current = ServerEntitlementRepository._sessionCache.fallbackFor(
      ownerId: ownerId,
      now: _now(),
    );
    return current != null &&
            current.provider != null &&
            _storeProofSurvivesDenial(ownerId, current) &&
            _storeObservationIsCurrent(ownerId, current)
        ? current
        : FreePlan.createState();
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
    if (!_storeProofSurvivesDenial(ownerId, state) ||
        !_storeObservationIsCurrent(ownerId, state)) {
      return _survivingStoreProof(ownerId);
    }
    ServerEntitlementRepository._sessionCache.remember(
      ownerId: ownerId,
      state: state,
      now: now,
    );
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
    // A newer denial may have arrived while this optional write was held.
    if (!_storeProofSurvivesDenial(ownerId, state) ||
        !_storeObservationIsCurrent(ownerId, state)) {
      // Do not erase a newer repurchase which settled during this write.
      return _survivingStoreProof(ownerId);
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
