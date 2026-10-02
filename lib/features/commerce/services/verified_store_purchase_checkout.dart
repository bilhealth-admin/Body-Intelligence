part of 'verified_store_purchase_service.dart';

/// Store checkout freshness and platform reconciliation.
///
/// Keeping catalog/transaction preflight separate from the core lifecycle
/// service makes the high-risk purchase boundary reviewable without growing
/// either the service or receipt-processing unit beyond the architecture cap.
extension _VerifiedStorePurchaseCheckout on VerifiedStorePurchaseService {
  Future<ProductDetails?> _freshCheckoutProduct(
    ProductDetails displayed, {
    required String ownerId,
    required int generation,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return displayed;
    }
    _checkoutPreflightInFlight = true;
    try {
      final response = await _purchase
          .queryProductDetails({displayed.id})
          .timeout(const Duration(seconds: 10));
      if (_disposed || generation != _purchaseEventGeneration) return null;
      if (Supabase.instance.client.auth.currentUser?.id != ownerId) {
        state = VerifiedStoreState.unavailable;
        messageCode = 'authentication_required';
        return null;
      }
      if (response.error != null ||
          response.notFoundIDs.contains(displayed.id)) {
        throw StateError('catalog_refresh_failed');
      }

      ProductDetails? refreshed;
      if (defaultTargetPlatform == TargetPlatform.android) {
        ProductDetails? preferred;
        ProductDetails? matching;
        for (final candidate in response.productDetails) {
          if (candidate.id != displayed.id ||
              candidate is! GooglePlayProductDetails ||
              !releaseEligibleStoreProduct(candidate)) {
            continue;
          }
          preferred = preferredStoreProduct(preferred, candidate);
          if (sameGooglePlayCheckoutTerms(displayed, candidate)) {
            matching ??= candidate;
          }
        }
        refreshed = matching ?? preferred;
        products = Map.unmodifiable({
          for (final entry in products.entries)
            if (entry.key != displayed.id) entry.key: entry.value,
          displayed.id: ?refreshed,
        });
        if (matching != null) return matching;
      } else {
        for (final candidate in response.productDetails) {
          if (candidate.id == displayed.id &&
              releaseEligibleStoreProduct(candidate)) {
            refreshed = candidate;
            break;
          }
        }
        products = Map.unmodifiable({
          for (final entry in products.entries)
            if (entry.key != displayed.id) entry.key: entry.value,
          displayed.id: ?refreshed,
        });
        if (refreshed != null &&
            refreshed.currencyCode == displayed.currencyCode &&
            (refreshed.rawPrice - displayed.rawPrice).abs() < 0.000001) {
          return refreshed;
        }
      }

      state = products.isEmpty
          ? VerifiedStoreState.unavailable
          : VerifiedStoreState.ready;
      messageCode = 'store_catalog_changed';
      return null;
    } on Object {
      if (!_disposed && generation == _purchaseEventGeneration) {
        state = VerifiedStoreState.failed;
        messageCode = 'store_catalog_refresh_failed';
      }
      return null;
    } finally {
      _checkoutPreflightInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> _reconcileAppleUnfinishedBeforePurchase(String productId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      final unfinished = await SK2Transaction.unfinishedTransactions().timeout(
        const Duration(seconds: 4),
      );
      final matching = unfinished
          .where((transaction) => transaction.productId == productId)
          .toList(growable: false);
      if (matching.isEmpty) return true;

      // Reconcile the exact unfinished StoreKit 2 transaction before asking
      // Apple to create another transaction for the same subscription. The
      // signed JWS still goes through BIL's normal server verification and
      // ownership binding; only a verified active/inactive receipt may finish.
      for (final transaction in matching) {
        final receipt = transaction.receiptData?.trim() ?? '';
        if (receipt.isEmpty) {
          state = VerifiedStoreState.failed;
          messageCode = 'reconciliation_verification_failed';
          notifyListeners();
          return false;
        }
        final details = SK2PurchaseDetails(
          productID: transaction.productId,
          purchaseID: transaction.id,
          verificationData: PurchaseVerificationData(
            localVerificationData: transaction.jsonRepresentation ?? '',
            serverVerificationData: receipt,
            source: 'app_store',
          ),
          transactionDate: transaction.purchaseDate,
          status: PurchaseStatus.purchased,
          appAccountToken: transaction.appAccountToken,
        );
        await _handleVerifiedPurchase(
          details,
          origin: _StorePurchaseEventOrigin.reconciliation,
          transactionAttempt: null,
        );
        if (_disposed ||
            state == VerifiedStoreState.failed ||
            state == VerifiedStoreState.verified) {
          return false;
        }
      }

      final after = await SK2Transaction.unfinishedTransactions().timeout(
        const Duration(seconds: 4),
      );
      if (after.any((transaction) => transaction.productId == productId)) {
        state = VerifiedStoreState.failed;
        messageCode = 'reconciliation_verification_failed';
        notifyListeners();
        return false;
      }
      return true;
    } on Object {
      // Enumeration is diagnostic before checkout. If StoreKit cannot expose
      // unfinished state, let the actual purchase call return the native
      // result; the duplicate-product catch below performs one final recovery.
      return true;
    }
  }
  Future<bool> _recoverVerifiedStoreKit2Completion(
    PurchaseDetails purchase,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        purchase is! SK2PurchaseDetails) {
      return false;
    }
    final purchaseId = purchase.purchaseID;
    final numericId = int.tryParse(purchaseId ?? '');
    if (purchaseId == null || numericId == null) return false;

    Future<List<SK2Transaction>> readUnfinished() =>
        SK2Transaction.unfinishedTransactions().timeout(
          const Duration(seconds: 4),
        );

    try {
      final before = await readUnfinished();
      if (!before.any((transaction) => transaction.id == purchaseId)) {
        // Native StoreKit already considers it finished; only the plugin
        // completion callback failed to settle.
        return true;
      }
      try {
        await SK2Transaction.finish(
          numericId,
        ).timeout(const Duration(seconds: 4));
      } on Object {
        // Re-read native state below. StoreKit may have completed the finish
        // even when the wrapper Future reported or timed out.
      }
      final after = await readUnfinished();
      return !after.any((transaction) => transaction.id == purchaseId);
    } on Object {
      return false;
    }
  }
}
