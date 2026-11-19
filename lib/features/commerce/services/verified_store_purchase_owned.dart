part of 'verified_store_purchase_service.dart';

extension _OwnedStorePurchase on VerifiedStorePurchaseService {
  void _clearEntitlement() {
    entitlement = null;
    _entitlementOwnerId = null;
  }

  void _retainEntitlementIfValid(String ownerId) {
    final current = entitlement;
    if (_entitlementOwnerId != ownerId ||
        current == null ||
        !current.grantsPaidAccess) {
      _clearEntitlement();
    }
  }

  void _retireStoreOwner() {
    if (_disposed) return;
    _purchaseEventGeneration++;
    _clearRestoreDiagnostic();
    _entitlementRefreshGeneration++;
    _clearEntitlement();
    _clearPurchaseInitiation();
    _pendingVerifiedFinishes.clear();
    _unresolvedVerificationReceipts.clear();
    _unresolvedReceiptOverflow = false;
    _failedSubscriptionProductId = null;
    ownershipConflictProductId = null;
    _verifiedFinishRetry = null;
    _publishedBenefits.clear();
    benefitOwnerId = null;
    benefitStoreSource = null;
    lastDelivery = null;
    lastDeliveryIsUserPurchase = false;
    _deliveries.clear();
    lastVerifiedProductId = null;
    state = VerifiedStoreState.unavailable;
    messageCode = 'authentication_required';
    notifyListeners();
  }

  Future<void> _handleVerifiedPurchase(
    PurchaseDetails purchase, {
    required _StorePurchaseEventOrigin origin,
    required _StoreTransactionAttempt? transactionAttempt,
    StoreAccountSnapshot? expectedVisit,
    bool waitForNativeFinish = false,
  }) async {
    final visit = expectedVisit ?? _storeVisit.capture();
    if (visit.ownerId == null || !_storeVisit.isCurrent(visit) || _disposed) {
      if (transactionAttempt != null) {
        _finishTransactionAttempt(transactionAttempt, settled: false);
      }
      return;
    }
    try {
      await CommunityOwnerOperation.run(
        client: Supabase.instance.client,
        ownerId: visit.ownerId,
        isCurrentOwner: () => !_disposed && _storeVisit.isCurrent(visit),
        action: (_) => _handleOwnedVerifiedPurchase(
          purchase,
          origin: origin,
          transactionAttempt: transactionAttempt,
          waitForNativeFinish: waitForNativeFinish,
        ),
      );
    } on CommunityOwnerOperationCancelled {
      // A retired visit cannot publish or acknowledge for the next account.
    }
  }

  void _recordBenefit(
    PurchaseDetails purchase,
    String ownerId, {
    required bool active,
  }) {
    final fingerprint = _transactionFingerprint(purchase);
    if (fingerprint == null) return;
    final key = '$ownerId|$fingerprint|$active';
    if (!_publishedBenefits.add(key)) return;
    if (_publishedBenefits.length > 128) {
      _publishedBenefits.remove(_publishedBenefits.first);
    }
    benefitOwnerId = ownerId;
    benefitStoreSource = purchase.verificationData.source;
    verifiedBenefitRevision++;
  }

  Future<_CanonicalEntitlementRead> _refreshCanonicalEntitlement() async {
    if (_disposed) return _CanonicalEntitlementRead.unavailable;
    final visit = _storeVisit.capture();
    final generation = ++_entitlementRefreshGeneration;
    final user = AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user == null) {
      _clearEntitlement();
      return _CanonicalEntitlementRead.unavailable;
    }
    if (_hasServerVerifiedInactiveMarker(user.id)) {
      // Do not let a read replica briefly restore paid access after a receipt
      // was already verified as expired, revoked, or refunded on the server.
      _clearEntitlement();
    }
    try {
      final rows = await Supabase.instance.client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (_disposed ||
          generation != _entitlementRefreshGeneration ||
          !_storeVisit.isCurrent(visit)) {
        return _CanonicalEntitlementRead.unavailable;
      }
      if (Supabase.instance.client.auth.currentUser?.id != user.id) {
        // Never carry one member's verified purchase into another member's
        // session, even if the original request finishes after auth changes.
        _clearEntitlement();
        return _CanonicalEntitlementRead.unavailable;
      }
      if (rows.isEmpty) {
        // A successful empty read is possible for a short period while the
        // verification function's write is replicating. Keep a still-valid,
        // server-verified entitlement for this owner instead of flashing the
        // paid surfaces back to Free.
        _retainEntitlementIfValid(user.id);
        return _CanonicalEntitlementRead.empty;
      }
      final row = rows.first;
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (verifiedAt == null) {
        _retainEntitlementIfValid(user.id);
        return _CanonicalEntitlementRead.unavailable;
      }
      if (_entitlementOwnerId == user.id &&
          entitlement != null &&
          verifiedAt.isBefore(entitlement!.verifiedAt)) {
        return _CanonicalEntitlementRead.unavailable;
      }
      final plan = _planFromIdOrNull('${row['plan_id']}');
      final lifecycle = '${row['lifecycle']}'.trim().toLowerCase();
      final provider = row['provider']?.toString().trim().toLowerCase();
      final expiresAt = DateTime.tryParse('${row['expires_at']}')?.toUtc();
      final gracePeriodEndsAt = DateTime.tryParse(
        '${row['grace_period_ends_at']}',
      )?.toUtc();
      if (plan == null ||
          !VerifiedStorePurchaseService._knownStoreLifecycles.contains(
            lifecycle,
          ) ||
          (provider != 'apple' && provider != 'google') ||
          (VerifiedStorePurchaseService._accessLifecycles.contains(lifecycle) &&
              (lifecycle == 'grace_period'
                  ? gracePeriodEndsAt == null
                  : expiresAt == null))) {
        // Unknown/malformed rows are unreadable snapshots, not proof of a
        // revocation. Preserve the last valid entitlement only within its
        // own billing boundary.
        _retainEntitlementIfValid(user.id);
        return _CanonicalEntitlementRead.unavailable;
      }
      final refreshedEntitlement = VerifiedStoreEntitlement(
        plan: plan,
        lifecycle: lifecycle,
        verifiedAt: verifiedAt,
        renewsOrExpiresAt: expiresAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
        provider: provider,
      );
      if (_hasServerVerifiedInactiveMarker(user.id) &&
          refreshedEntitlement.grantsPaidAccess) {
        final inactiveAt = _serverVerifiedInactiveAt;
        if (inactiveAt == null ||
            !refreshedEntitlement.verifiedAt.isAfter(inactiveAt)) {
          // The verify response is newer and authoritative. Do not
          // momentarily unlock paid surfaces from an active row that has not
          // caught up yet.
          _clearEntitlement();
          return _CanonicalEntitlementRead.unavailable;
        }
        // A newer canonical verification is evidence of a real later active
        // subscription, not a replica of the inactive receipt's old row.
        _clearServerVerifiedInactiveOwner(user.id);
      }
      entitlement = refreshedEntitlement;
      _entitlementOwnerId = user.id;
      return _CanonicalEntitlementRead.observed;
    } on Object {
      // Never turn an unverifiable local label into paid access, but do not
      // erase a still-valid server-verified result for a transient failure.
      if (!_disposed &&
          generation == _entitlementRefreshGeneration &&
          _storeVisit.isCurrent(visit)) {
        _retainEntitlementIfValid(user.id);
      }
      return _CanonicalEntitlementRead.unavailable;
    }
  }
}

enum _CanonicalEntitlementRead { empty, observed, unavailable }
