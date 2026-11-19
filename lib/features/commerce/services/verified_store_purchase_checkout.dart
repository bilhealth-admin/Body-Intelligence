part of 'verified_store_purchase_service.dart';

/// Store checkout freshness and platform reconciliation.
///
/// Keeping catalog/transaction preflight separate from the core lifecycle
/// service makes the high-risk purchase boundary reviewable without growing
/// either the service or receipt-processing unit beyond the architecture cap.
extension _VerifiedStorePurchaseCheckout on VerifiedStorePurchaseService {
  // Never recapture a visit/generation after a notifying or async boundary.
  bool _canLaunchCheckout(
    String owner,
    StoreAccountSnapshot visit,
    int generation,
  ) =>
      isCurrentCatalogVisit(visit) &&
      _isCurrentStoreOwner(owner) &&
      generation == _purchaseEventGeneration &&
      !_restoring &&
      !_subscriptionRecoveryInFlight &&
      _queuedPurchaseUpdates == 0 &&
      _unresolvedVerificationReceipts.isEmpty &&
      !_unresolvedReceiptOverflow &&
      !verificationBackedOff;

  Future<bool> _checkAndroidReadiness(
    String owner,
    String productId,
    StoreAccountSnapshot visit,
    int generation,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    bool current() =>
        isCurrentCatalogVisit(visit) &&
        generation == _purchaseEventGeneration &&
        _isCurrentStoreOwner(owner) &&
        _unresolvedVerificationReceipts.isEmpty &&
        !_unresolvedReceiptOverflow &&
        _queuedPurchaseUpdates == 0 &&
        !verificationBackedOff;
    _checkoutPreflightInFlight = true;
    state = VerifiedStoreState.loading;
    messageCode = null;
    notifyListeners();
    try {
      final result = await _androidReadiness.check(
        ownerId: owner,
        productId: productId,
        isCurrent: current,
      );
      if (!current()) return false;
      if (result == AndroidPurchaseReadiness.ready) return true;
      state = VerifiedStoreState.ready;
      messageCode = result.messageCode ?? 'play_readiness_unavailable';
      return false;
    } finally {
      _checkoutPreflightInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<ProductDetails?> _freshCheckoutProduct(
    ProductDetails displayed, {
    required String ownerId,
    required int generation,
    String? expectedStoreCountryCode,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return displayed;
    }
    _checkoutPreflightInFlight = true;
    final visit = _storeVisit.capture();
    bool isCurrent() =>
        isCurrentCatalogVisit(visit) &&
        generation == _purchaseEventGeneration &&
        Supabase.instance.client.auth.currentUser?.id == ownerId;
    ProductDetails? changedCatalog() {
      if (isCurrent()) {
        state = VerifiedStoreState.ready;
        messageCode = 'store_catalog_changed';
      }
      return null;
    }

    try {
      final country = await readStorefrontCountry();
      if (!isCurrent()) return null;
      final expected =
          StorefrontMarketPolicy.normalizeCountry(expectedStoreCountryCode) ??
          catalogStoreCountryCode;
      final catalogPlans = products.keys
          .map((id) => StoreCatalogConfiguration.bindingForProduct(id)?.plan)
          .toSet();
      final ambiguousUnknownCountry =
          country == null &&
          catalogPlans.contains(CommercePlan.premium) &&
          catalogPlans.contains(CommercePlan.premiumAiCoach);
      final unknownAndroidSubscription =
          defaultTargetPlatform == TargetPlatform.android &&
          country == null &&
          StoreCatalogConfiguration.bindingForProduct(displayed.id) != null;
      if ((expected != null && expected != country) ||
          unknownAndroidSubscription ||
          ambiguousUnknownCountry ||
          !StorefrontMarketPolicy.allowsProduct(displayed.id, country)) {
        return changedCatalog();
      }
      final response = await _purchase
          .queryProductDetails({displayed.id})
          .timeout(const Duration(seconds: 10));
      if (!isCurrent()) return null;
      final afterCountry = await readStorefrontCountry();
      if (!isCurrent()) return null;
      if (afterCountry != country ||
          !StorefrontMarketPolicy.allowsProduct(displayed.id, afterCountry)) {
        return changedCatalog();
      }
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
    final preflightVisit = _storeVisit.capture();
    final preflightGeneration = _purchaseEventGeneration;
    bool current() =>
        !_disposed &&
        _storeVisit.isCurrent(preflightVisit) &&
        preflightGeneration == _purchaseEventGeneration;
    try {
      final unfinished = await SK2Transaction.unfinishedTransactions().timeout(
        const Duration(seconds: 4),
      );
      if (!current() || hasPendingVerifiedFinish) return false;
      final matching = unfinished
          .where((transaction) => transaction.productId == productId)
          .toList(growable: false);
      if (matching.isEmpty) return true;

      // Reconcile the exact unfinished StoreKit 2 transaction before asking
      // Apple to create another transaction for the same subscription. The
      // signed JWS still goes through BIL's normal server verification and
      // ownership binding; only a verified active/inactive receipt may finish.
      for (final transaction in matching) {
        if (!current()) return false;
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
        // Use the same exact-owner receipt reservation as observer callbacks.
        // Only verified native finish may remember its settled replay key.
        final attempt = _transactionAttemptFor(details);
        if (attempt == null) {
          state = VerifiedStoreState.failed;
          messageCode = 'reconciliation_verification_failed';
          notifyListeners();
          return false;
        }
        switch (_reserveTransactionAttempt(attempt)) {
          case _StoreTransactionReservation.accepted:
            break;
          case _StoreTransactionReservation.alreadySettled:
            continue;
          case _StoreTransactionReservation.alreadyQueued:
            // The existing receipt/finish lane owns this unresolved outcome.
            // Never duplicate verification or open another native checkout.
            return false;
          case _StoreTransactionReservation.cooledDown:
            _retainUnresolvedReceipt(details);
            _reportCooledDownReplay();
            return false;
        }
        try {
          await _handleVerifiedPurchase(
            details,
            origin: _StorePurchaseEventOrigin.reconciliation,
            transactionAttempt: attempt,
            expectedVisit: preflightVisit,
            waitForNativeFinish: true,
          );
        } finally {
          // Normal finish/failure removes the reservation itself. If owner
          // retirement cancels before action, release only this old reservation
          // without ever publishing an acknowledged/settled receipt.
          _finishTransactionAttempt(attempt, settled: false);
        }
        if (!current() ||
            hasPendingVerifiedFinish ||
            state == VerifiedStoreState.purchasePending ||
            state == VerifiedStoreState.failed ||
            state == VerifiedStoreState.verified) {
          return false;
        }
      }

      final after = await SK2Transaction.unfinishedTransactions().timeout(
        const Duration(seconds: 4),
      );
      if (!current() || hasPendingVerifiedFinish) return false;
      if (after.any((transaction) => transaction.productId == productId)) {
        state = VerifiedStoreState.failed;
        messageCode = 'reconciliation_verification_failed';
        notifyListeners();
        return false;
      }
      return true;
    } on Object {
      if (!current() ||
          hasPendingVerifiedFinish ||
          state == VerifiedStoreState.purchasePending ||
          state == VerifiedStoreState.failed ||
          state == VerifiedStoreState.verified) {
        return false;
      }
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

  Future<ProductDetails?> _freshLegacyBoostQuote(
    ProductDetails displayed,
    String owner,
    StoreAccountSnapshot visit,
    int generation,
    String? offerToken,
  ) async {
    bool current() =>
        isCurrentCatalogVisit(visit) &&
        _isCurrentStoreOwner(owner) &&
        generation == _purchaseEventGeneration &&
        _queuedPurchaseUpdates == 0 &&
        _unresolvedVerificationReceipts.isEmpty &&
        !_unresolvedReceiptOverflow &&
        !verificationBackedOff;
    _checkoutPreflightInFlight = true;
    try {
      final response = await _purchase
          .queryProductDetails({displayed.id})
          .timeout(const Duration(seconds: 10));
      if (!current()) return null;
      final fresh = response.productDetails
          .where((p) => p.id == displayed.id)
          .firstOrNull;
      final previous = googlePlayOneTimeDiscountMetadata(displayed);
      final discount = fresh == null
          ? null
          : googlePlayOneTimeDiscountMetadata(fresh);
      if (fresh != null) {
        products = Map.unmodifiable({...products, displayed.id: fresh});
      }
      if (response.error == null &&
          !response.notFoundIDs.contains(displayed.id) &&
          fresh != null &&
          displayed.currencyCode == fresh.currencyCode &&
          displayed.rawPrice == fresh.rawPrice &&
          (previous?.localizedPrice ?? displayed.price) ==
              (discount?.localizedPrice ?? fresh.price) &&
          (offerToken ?? previous?.offerToken) == discount?.offerToken) {
        return fresh;
      }
      state = VerifiedStoreState.ready;
      messageCode = 'store_catalog_changed';
      return null;
    } on Object {
      if (current()) {
        state = VerifiedStoreState.ready;
        messageCode = 'store_catalog_changed';
      }
      return null;
    } finally {
      _checkoutPreflightInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _purchaseBoost({String? offerToken}) async {
    if (_disposed ||
        busy ||
        verificationBackedOff ||
        _unresolvedVerificationReceipts.isNotEmpty ||
        _unresolvedReceiptOverflow) {
      return;
    }
    if (const {
      'purchase_status_unknown',
      'store_finish_pending',
      'purchase_owned_by_another_account',
    }.contains(messageCode)) {
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    var product = products[StoreCatalogConfiguration.aiBoost];
    if (user == null ||
        product == null ||
        !canStartStorePurchase(
          state: state,
          productAvailable: true,
          messageCode: messageCode,
        )) {
      messageCode = 'purchase_unavailable';
      notifyListeners();
      return;
    }
    final readinessVisit = _storeVisit.capture();
    final readinessGeneration = _purchaseEventGeneration;
    bool current() =>
        _canLaunchCheckout(user.id, readinessVisit, readinessGeneration);
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await _checkAndroidReadiness(
            user.id,
            product.id,
            readinessVisit,
            readinessGeneration,
          ) ||
          !current()) {
        return;
      }
      product = await _freshLegacyBoostQuote(
        product,
        user.id,
        readinessVisit,
        readinessGeneration,
        offerToken,
      );
      if (product == null || !current()) return;
    }
    if (!current()) return;
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    if (!current()) return;
    final accountHash = storeAccountIdentifier(
      ownerId: user.id,
      platform: defaultTargetPlatform,
    );
    final purchaseParam = verifiedBoostPurchaseParam(
      product: product,
      accountHash: accountHash,
      platform: defaultTargetPlatform,
      offerToken: offerToken,
    );
    _armAndroidCheckout(readinessVisit, readinessGeneration, product.id);
    try {
      if (!current()) return;
      _purchaseInitiatedByThisService = true;
      _purchaseInitiatedProductId = product.id;
      final started = await _purchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
      if (!current() || started) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      _clearPurchaseInitiation();
      notifyListeners();
    } on Object {
      if (!current()) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_status_unknown';
      notifyListeners();
    }
  }
}
