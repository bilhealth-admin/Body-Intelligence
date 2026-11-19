part of 'verified_store_purchase_service.dart';

extension VerifiedAndroidCheckoutRecovery on VerifiedStorePurchaseService {
  bool get hasAndroidCheckoutFailure {
    final attempt = _androidCheckoutAttempt;
    return attempt?.witnessed == true &&
        !_disposed &&
        _storeVisit.isCurrent(attempt!.visit) &&
        attempt.generation == _purchaseEventGeneration &&
        messageCode == 'purchase_status_unknown';
  }

  String? get presentationMessageCode =>
      hasAndroidCheckoutFailure ? 'purchase_failed' : messageCode;

  void _armAndroidCheckout(
    StoreAccountSnapshot visit,
    int generation,
    String productId,
  ) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _androidCheckoutAttempt = AndroidCheckoutFailureAttempt(
        visit,
        generation,
        productId,
      );
    }
  }

  bool _observeUnscopedAndroidCheckout(PurchaseDetails purchase) {
    final response = unscopedAndroidCheckoutResponse(purchase);
    final attempt = _androidCheckoutAttempt;
    if (response == null ||
        attempt == null ||
        _disposed ||
        !_storeVisit.isCurrent(attempt.visit) ||
        attempt.generation != _purchaseEventGeneration ||
        !_purchaseInitiatedByThisService ||
        _purchaseInitiatedProductId != attempt.productId ||
        _restoring ||
        _nativeRestoreOperation != null ||
        _queuedPurchaseUpdates != 0 ||
        _unresolvedVerificationReceipts.isNotEmpty ||
        _unresolvedReceiptOverflow ||
        hasPendingVerifiedFinish ||
        (state != VerifiedStoreState.purchasePending &&
            !(state == VerifiedStoreState.failed &&
                messageCode == 'purchase_status_unknown'))) {
      return false;
    }
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = null;
    _androidCheckoutAttempt = attempt.withResponse(
      response,
      ++_purchaseEventGeneration,
    );
    checkoutTrace?.mark(StorePurchaseStage.nativeCallback);
    state = VerifiedStoreState.failed;
    messageCode = 'purchase_status_unknown';
    notifyListeners();
    return true;
  }

  Future<void> _recoverUnscopedAndroidCheckout() async {
    final attempt = _androidCheckoutAttempt;
    if (!hasAndroidCheckoutFailure || attempt == null) return;
    final revision = verifiedBenefitRevision;
    final receiptEpoch = _androidReceiptObservationEpoch;
    bool current() =>
        !_disposed &&
        identical(_androidCheckoutAttempt, attempt) &&
        _storeVisit.isCurrent(attempt.visit) &&
        attempt.generation == _purchaseEventGeneration &&
        verifiedBenefitRevision == revision &&
        _androidReceiptObservationEpoch == receiptEpoch &&
        _purchaseInitiatedByThisService &&
        _purchaseInitiatedProductId == attempt.productId &&
        state == VerifiedStoreState.failed &&
        messageCode == 'purchase_status_unknown' &&
        _queuedPurchaseUpdates == 0 &&
        !_restoring &&
        _nativeRestoreOperation == null &&
        !_checkoutPreflightInFlight &&
        _unresolvedVerificationReceipts.isEmpty &&
        !_unresolvedReceiptOverflow &&
        !hasPendingVerifiedFinish &&
        ownershipConflictProductId == null &&
        !verificationBackedOff;
    if (!current()) return;
    _subscriptionRecoveryInFlight = true;
    notifyListeners();
    try {
      final proven = await _androidCheckoutRecovery.assess(
        purchase: _purchase,
        current: current,
      );
      if (!proven || !current()) return;
      _clearPurchaseInitiation();
      state = entitlement?.grantsPaidAccess == true
          ? VerifiedStoreState.verified
          : products.isEmpty
          ? VerifiedStoreState.unavailable
          : VerifiedStoreState.ready;
      messageCode = attempt.cancelled
          ? 'purchase_cancelled'
          : 'purchase_not_started';
    } finally {
      _subscriptionRecoveryInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }
}
