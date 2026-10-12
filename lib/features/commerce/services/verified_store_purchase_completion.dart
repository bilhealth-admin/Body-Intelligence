part of 'verified_store_purchase_service.dart';

extension _VerifiedNativeStoreCompletion on VerifiedStorePurchaseService {
  Future<void> _finishVerifiedNativeReceipt(
    PurchaseDetails purchase, {
    required StoreAccountSnapshot visit,
    required int generation,
    required int benefitRevision,
    required bool active,
    required StorePurchaseTrace? trace,
    required _StoreTransactionAttempt? transactionAttempt,
  }) async {
    bool current() => !_disposed && _storeVisit.isCurrent(visit);
    bool currentPresentation() =>
        current() &&
        generation == _purchaseEventGeneration &&
        benefitRevision == verifiedBenefitRevision;
    final boost = purchase.productID == StoreCatalogConfiguration.aiBoost;
    final key = _transactionFingerprint(purchase) ?? purchase.productID;
    try {
      if (!current()) return;
      // Android consumables were consumed by the server after durable credit.
      // Pending/unverified receipts never reach this acknowledgement lane.
      if (purchase.pendingCompletePurchase) {
        trace?.mark(StorePurchaseStage.finishStarted);
        if (!boost || defaultTargetPlatform != TargetPlatform.android) {
          await completeVerifiedNativePurchase(
            _purchase,
            purchase,
          ).timeout(const Duration(seconds: 12));
        }
      }
      if (current()) {
        _pendingVerifiedFinishes.remove(key);
        trace?.mark(StorePurchaseStage.finishCompleted);
      }
    } on Object {
      if (!current()) return;
      var recovered = false;
      try {
        recovered = await _recoverVerifiedStoreKit2Completion(purchase);
      } on Object {
        // A native read failure is unresolved acknowledgement, not lost credit.
      }
      if (!current()) return;
      if (recovered) {
        trace?.mark(StorePurchaseStage.finishCompleted);
        return;
      }
      _pendingVerifiedFinishes[key] = purchase;
      // Preserve retry state, but an older acknowledgement cannot replace a
      // newer receipt's pending/success/error presentation or clear its launch.
      if (currentPresentation()) {
        state = active ? VerifiedStoreState.verified : VerifiedStoreState.ready;
        messageCode = 'store_finish_pending';
      }
      notifyListeners();
    } finally {
      if (transactionAttempt != null) {
        _finishTransactionAttempt(transactionAttempt, settled: true);
      }
    }
  }
}
