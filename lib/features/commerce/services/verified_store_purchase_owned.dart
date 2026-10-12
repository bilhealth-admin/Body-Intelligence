part of 'verified_store_purchase_service.dart';

extension _OwnedStorePurchase on VerifiedStorePurchaseService {
  void _retireStoreOwner() {
    if (_disposed) return;
    _purchaseEventGeneration++;
    _entitlementRefreshGeneration++;
    _clearEntitlement();
    _clearPurchaseInitiation();
    _pendingVerifiedFinishes.clear();
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
}
