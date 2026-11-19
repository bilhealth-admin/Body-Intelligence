part of 'ai_boost_purchase_service.dart';

extension AiBoostAndroidCheckoutRecovery on AiBoostPurchaseService {
  bool get hasAndroidCheckoutFailure {
    final attempt = _androidCheckoutAttempt;
    return attempt?.witnessed == true &&
        !_disposed &&
        _accountVisit.isCurrent(attempt!.visit) &&
        attempt.generation == _generation &&
        errorCode == 'purchase_status_unknown';
  }

  String? get presentationErrorCode =>
      hasAndroidCheckoutFailure ? 'purchase_failed' : errorCode;

  bool _observeUnscopedAndroidCheckout(PurchaseDetails purchase) {
    final response = unscopedAndroidCheckoutResponse(purchase);
    final attempt = _androidCheckoutAttempt;
    if (response == null ||
        attempt == null ||
        _disposed ||
        !_accountVisit.isCurrent(attempt.visit) ||
        attempt.generation != _generation ||
        _owner() != _catalogOwner ||
        _userInitiatedProduct != AiBoostPurchaseService.productId ||
        _queued != 0 ||
        _reconciling ||
        _unresolved != null ||
        (state != AiBoostPurchaseState.pending &&
            !(state == AiBoostPurchaseState.failed &&
                errorCode == 'purchase_status_unknown'))) {
      return false;
    }
    _watchdog?.cancel();
    _androidCheckoutAttempt = attempt.withResponse(response, ++_generation);
    checkoutTrace?.mark(StorePurchaseStage.nativeCallback);
    _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
    return true;
  }

  Future<void> _recoverUnscopedAndroidCheckout() async {
    final attempt = _androidCheckoutAttempt;
    if (!hasAndroidCheckoutFailure || attempt == null) return;
    final revision = verifiedCreditsRevision;
    final receiptEpoch = _androidReceiptObservationEpoch;
    bool current() =>
        !_disposed &&
        identical(_androidCheckoutAttempt, attempt) &&
        _accountVisit.isCurrent(attempt.visit) &&
        attempt.generation == _generation &&
        _owner() == _catalogOwner &&
        _owner() == attempt.visit.ownerId &&
        verifiedCreditsRevision == revision &&
        _queued == 0 &&
        _unresolved == null &&
        _androidReceiptObservationEpoch == receiptEpoch &&
        state == AiBoostPurchaseState.failed &&
        errorCode == 'purchase_status_unknown' &&
        !StoreVerificationRequestPolicy.shared.isBackedOff(_owner());
    if (!current()) return;
    _reconciling = true;
    notifyListeners();
    try {
      final proven = await _androidCheckoutRecovery.assess(
        purchase: _purchase,
        current: current,
      );
      if (!proven || !current()) return;
      _androidCheckoutAttempt = null;
      _publish(
        AiBoostPurchaseState.ready,
        attempt.cancelled ? 'purchase_cancelled' : 'purchase_not_started',
      );
    } finally {
      _reconciling = false;
      if (!_disposed) notifyListeners();
    }
  }
}
