part of 'verified_store_purchase_service.dart';

extension VerifiedStoreSubscriptionRecovery on VerifiedStorePurchaseService {
  bool get canRecoverSubscriptionBlocker =>
      !_disposed &&
      !busy &&
      !verificationBackedOff &&
      _nativeRestoreOperation == null &&
      _pendingVerifiedFinishes.isEmpty &&
      ownershipConflictProductId == null &&
      _failedSubscriptionProductId != null &&
      StoreCatalogConfiguration.bindingForProduct(
            _failedSubscriptionProductId!,
          ) !=
          null &&
      const {
        'verification_failed',
        'restore_verification_failed',
        'reconciliation_verification_failed',
      }.contains(messageCode) &&
      !_unresolvedReceiptOverflow &&
      !_unresolvedVerificationReceipts.values.any(
        (receipt) =>
            StoreCatalogConfiguration.bindingForProduct(receipt.productID) ==
            null,
      );

  /// Explicit recovery only. It never launches checkout or weakens receipt
  /// verification. A successful empty proof retires only this UI blocker;
  /// starting a purchase still needs a separate user action and its own guards.
  Future<void> recoverSubscriptionBlocker() async {
    if (!canRecoverSubscriptionBlocker) return;
    final visit = _storeVisit.capture();
    if (visit.ownerId == null) return;
    final generation = _purchaseEventGeneration;
    final revision = verifiedBenefitRevision;
    final originalMessage = messageCode;
    final failedProduct = _failedSubscriptionProductId;
    _subscriptionRecoveryInFlight = true;
    notifyListeners();
    try {
      if (_unresolvedVerificationReceipts.isNotEmpty) {
        // Retry the exact retained receipt in the existing serialized lane.
        // Explicit retry may bypass its short failed-event replay delay, but
        // never the owner's server cooldown, ownership fence or native finish.
        _restoring = true;
        _explicitRestoreTransactionKeys.clear();
        await _enqueuePurchaseUpdates(
          _unresolvedVerificationReceipts.values.toList(growable: false),
        );
        return;
      }
      StoreSubscriptionBlockerRecoveryContext context() =>
          StoreSubscriptionBlockerRecoveryContext(
            failedSubscriptionProductId: _failedSubscriptionProductId,
            hasUnresolvedReceipt:
                _unresolvedVerificationReceipts.isNotEmpty ||
                _unresolvedReceiptOverflow,
            hasPendingVerifiedFinish: hasPendingVerifiedFinish,
            hasQueuedUpdates: _queuedPurchaseUpdates > 0,
            hasUnknownPurchase: messageCode == 'purchase_status_unknown',
            hasOwnershipConflict:
                ownershipConflictProductId != null ||
                messageCode == 'purchase_owned_by_another_account',
            hasConsumableFailure: _unresolvedVerificationReceipts.values.any(
              (receipt) =>
                  receipt.productID == StoreCatalogConfiguration.aiBoost,
            ),
            isBackedOff: verificationBackedOff,
            hasNativeActivity:
                _disposed ||
                _restoring ||
                _nativeRestoreOperation != null ||
                _checkoutPreflightInFlight ||
                _purchaseInitiatedByThisService ||
                state != VerifiedStoreState.failed ||
                generation != _purchaseEventGeneration ||
                revision != verifiedBenefitRevision ||
                messageCode != originalMessage,
          );
      final result =
          await StoreSubscriptionBlockerRecovery(
            nativeReader:
                _subscriptionInventoryReader ??
                const NativeStoreSubscriptionInventoryReader(),
            freshCanonicalReader:
                _freshRecoveryEntitlementReader ??
                const ServerEntitlementRepository()
                    .currentForExplicitStoreRecovery,
          ).assess(
            currentContext: context,
            expectedVisit: visit,
            visitIsCurrent: (candidate) =>
                !_disposed && _storeVisit.isCurrent(candidate),
          );
      if (result != StoreSubscriptionBlockerRecoveryResult.eligible ||
          _disposed ||
          !_storeVisit.isCurrent(visit) ||
          generation != _purchaseEventGeneration ||
          revision != verifiedBenefitRevision ||
          messageCode != originalMessage ||
          !context().permitsReadOnlyProof ||
          _failedSubscriptionProductId != failedProduct) {
        return;
      }
      // No entitlement, receipt, native acknowledgement, credit or failed-event
      // payload is changed here. The proof allows only a truthful ready UI.
      state = products.isEmpty
          ? VerifiedStoreState.unavailable
          : VerifiedStoreState.ready;
      messageCode = 'no_restorable_purchases';
    } on Object {
      // Native/transport/auth/unsupported failure preserves the old blocker.
    } finally {
      _explicitRestoreTransactionKeys.clear();
      _restoring = false;
      _subscriptionRecoveryInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }
}
