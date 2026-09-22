part of 'verified_store_purchase_service.dart';

// Explicit restore is isolated from checkout and receipt verification so the
// release-critical service remains reviewable by responsibility.
extension VerifiedStorePurchaseRestore on VerifiedStorePurchaseService {
  Future<void> restore() async {
    if (_disposed || !configured || busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      state = VerifiedStoreState.unavailable;
      messageCode = 'authentication_required';
      notifyListeners();
      return;
    }
    final restoreOwnerId = _currentStoreOwnerId()!;
    _restoring = true;
    _restoreOwnershipConflict = false;
    _explicitRestoreTransactionKeys.clear();
    final restoreEventObserved = Completer<void>();
    _restoreEventObserved = restoreEventObserved;
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    try {
      // StoreKit 2's generic restore reads current entitlements but does not
      // itself force a server sync. This is an explicit Restore tap, which is
      // the only appropriate time to ask App Store to synchronize.
      await _syncAppleStoreForExplicitRestore();
      await _purchase.restorePurchases();
      // StoreKit may complete AppStore.sync just before it publishes its
      // restored transaction to the stream. Wait briefly for that callback
      // instead of falsely reporting an empty history; a later callback still
      // remains safely queued and is never treated as a new purchase.
      await Future.any<void>([
        restoreEventObserved.future,
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
      // A restored callback may be verifying while the native restore Future
      // completes. Do not announce "nothing to restore" before it settles.
      while (_queuedPurchaseUpdates > 0) {
        await _purchaseUpdates;
      }
      if (_disposed || !_isCurrentStoreOwner(restoreOwnerId)) return;
      await refreshEntitlement();
      if (_disposed || !_isCurrentStoreOwner(restoreOwnerId)) return;
      if (_restoreOwnershipConflict) {
        state = VerifiedStoreState.failed;
        messageCode = 'purchase_owned_by_another_account';
        notifyListeners();
        return;
      }
      if (state == VerifiedStoreState.purchasePending) {
        state = entitlement?.grantsPaidAccess == true
            ? VerifiedStoreState.verified
            : products.isEmpty
            ? VerifiedStoreState.unavailable
            : VerifiedStoreState.ready;
        messageCode = entitlement?.grantsPaidAccess == true
            ? 'subscription_verified'
            : 'no_restorable_purchases';
        notifyListeners();
      }
    } on Object {
      if (_disposed || !_isCurrentStoreOwner(restoreOwnerId)) return;
      state = VerifiedStoreState.failed;
      messageCode = 'restore_failed';
      notifyListeners();
    } finally {
      if (identical(_restoreEventObserved, restoreEventObserved)) {
        _restoreEventObserved = null;
      }
      _explicitRestoreTransactionKeys.clear();
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> _syncAppleStoreForExplicitRestore() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final injectedSync = _appleStoreSync;
    if (injectedSync != null) {
      await injectedSync();
      return;
    }
    final addition = _purchase
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await addition.sync();
  }
}
