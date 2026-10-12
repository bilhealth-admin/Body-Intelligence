part of 'verified_store_purchase_service.dart';

extension VerifiedStorePurchasePending on VerifiedStorePurchaseService {
  Future<void> continueVerification() {
    if (_disposed) return Future<void>.value();
    final running = _verifiedFinishRetry;
    if (running != null) return running;
    if (busy) return Future<void>.value();
    late final Future<void> operation;
    operation = _continueVerification().whenComplete(() {
      if (identical(_verifiedFinishRetry, operation)) {
        _verifiedFinishRetry = null;
      }
    });
    _verifiedFinishRetry = operation;
    return operation;
  }

  Future<void> _continueVerification() async {
    if (_pendingVerifiedFinishes.isEmpty) {
      final uncertain = messageCode == 'purchase_status_unknown';
      final visit = _storeVisit.capture();
      await restore();
      if (uncertain &&
          _storeVisit.isCurrent(visit) &&
          messageCode == 'no_restorable_purchases') {
        state = VerifiedStoreState.failed;
        messageCode = 'purchase_status_unknown';
        notifyListeners();
      }
      return;
    }
    final visit = _storeVisit.capture();
    for (final entry in _pendingVerifiedFinishes.entries.toList()) {
      try {
        await completeVerifiedNativePurchase(
          _purchase,
          entry.value,
        ).timeout(const Duration(seconds: 12));
        if (!_storeVisit.isCurrent(visit)) return;
        _pendingVerifiedFinishes.remove(entry.key);
      } on Object {
        /* Keep this native acknowledgement available for retry. */
      }
    }
    if (!_disposed &&
        _pendingVerifiedFinishes.isEmpty &&
        state == VerifiedStoreState.verified) {
      messageCode = lastVerifiedProductId == StoreCatalogConfiguration.aiBoost
          ? 'ai_boost_verified'
          : 'subscription_verified';
      notifyListeners();
    }
  }

  void _armPurchaseWatchdog(int generation) {
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = Timer(pendingTimeout, () {
      if (_disposed ||
          generation != _purchaseEventGeneration ||
          !_purchaseInitiatedByThisService ||
          state != VerifiedStoreState.purchasePending) {
        return;
      }
      // No callback is not proof of cancellation. Reconcile this transaction
      // without enabling another charge or granting access.
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_status_unknown';
      _purchaseWatchdog = null;
      notifyListeners();
    });
  }
}
