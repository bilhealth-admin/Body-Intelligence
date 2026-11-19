part of 'verified_store_purchase_service.dart';

extension _VerifiedStorePurchaseInitialization on VerifiedStorePurchaseService {
  bool _restoreCatalogAfterSettledInactiveReceipt() {
    final settled = _settledInactiveCatalogRecovery;
    if (settled == null ||
        _disposed ||
        products.isEmpty ||
        state != VerifiedStoreState.unavailable ||
        messageCode != 'no_restorable_purchases' ||
        hasPendingVerifiedFinish ||
        settled.generation != _purchaseEventGeneration ||
        settled.benefitRevision != verifiedBenefitRevision ||
        !_storeVisit.isCurrent(settled.visit)) {
      return false;
    }
    _settledInactiveCatalogRecovery = null;
    state = VerifiedStoreState.ready;
    return true;
  }

  Future<void> _initialize() async {
    final purchaseGeneration = _purchaseEventGeneration;
    final catalogVisit = _storeVisit.capture();
    // Catalog prices are independent of a newer same-owner receipt outcome.
    // The visit still retires owner changes, A -> B -> A and disposal.
    bool currentCatalog() => isCurrentCatalogVisit(catalogVisit);
    _storeStartupFaultBeforeCatalog = false;
    state = VerifiedStoreState.loading;
    messageCode = null;
    notifyListeners();
    final user = AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (!configured || user == null) {
      state = VerifiedStoreState.unavailable;
      messageCode = 'configuration_required';
      notifyListeners();
      return;
    }
    _subscription ??= _purchase.purchaseStream.listen(
      (purchases) => unawaited(_enqueuePurchaseUpdates(purchases)),
      onError: (_) {
        // A receipt already being verified owns its outcome. A stream error
        // while merely waiting for a native transaction must still leave a
        // recoverable, non-retryable failure instead of a permanent spinner.
        // StoreKit can deliver the stream error after the receipt callback has
        // completed. In that ordering the queue count is already zero, but
        // the verified entitlement is still the authoritative result and a
        // stale stream fault must not downgrade it to a catalog-ready state.
        if (_disposed ||
            _queuedPurchaseUpdates > 0 ||
            state == VerifiedStoreState.verified) {
          return;
        }
        final passivePending =
            messageCode == 'reconciliation_pending' &&
            !_purchaseInitiatedByThisService &&
            !_restoring;
        final outcome = storePurchaseStreamFailureOutcome(
          productsAvailable: products.isNotEmpty,
          initiatedByCurrentService: _purchaseInitiatedByThisService,
          purchasePending: state == VerifiedStoreState.purchasePending,
        );
        if (products.isEmpty &&
            !_purchaseInitiatedByThisService &&
            state != VerifiedStoreState.purchasePending) {
          // StoreKit can report a transient stream fault before the first
          // product query has populated [products].  Keep that fault local to
          // startup: a valid catalog arriving moments later must be actionable.
          _storeStartupFaultBeforeCatalog = true;
        }
        _clearPurchaseInitiation();
        if (outcome.state == VerifiedStoreState.failed) {
          _purchaseEventGeneration++;
        }
        state = outcome.state;
        messageCode = passivePending
            ? 'reconciliation_verification_failed'
            : outcome.messageCode;
        notifyListeners();
      },
    );
    // Independent read-only work: a slow entitlement lookup must not delay
    // asking the native store for prices. Both still settle before initialize.
    final entitlementRefresh = refreshEntitlement();
    try {
      if (!await _purchase.isAvailable().timeout(const Duration(seconds: 8))) {
        if (_disposed ||
            busy ||
            purchaseGeneration != _purchaseEventGeneration) {
          return;
        }
        state = VerifiedStoreState.unavailable;
        messageCode = 'store_unavailable';
        notifyListeners();
        return;
      }
      final country = await readStorefrontCountry();
      if (!currentCatalog()) return;
      final response = await _purchase
          .queryProductDetails(
            StorefrontMarketPolicy.productIds(
              StoreCatalogConfiguration.storefrontProductIds,
              country,
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (!currentCatalog()) return;
      final afterCountry = await readStorefrontCountry();
      if (!currentCatalog()) return;
      if (afterCountry != country) {
        products = const {};
        if (purchaseGeneration == _purchaseEventGeneration) {
          state = VerifiedStoreState.unavailable;
          messageCode = 'store_catalog_changed';
        }
        notifyListeners();
        return;
      }
      final loaded = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        if (!StorefrontMarketPolicy.allowsProduct(product.id, country)) {
          continue;
        }
        final existing = loaded[product.id];
        final selected = preferredStoreProduct(existing, product);
        if (selected == null) {
          loaded.remove(product.id);
        } else {
          loaded[product.id] = selected;
        }
      }
      // Regional availability deliberately returns a partial catalog: a
      // profitable market exposes Premium AI Coach, while a localized market
      // exposes Premium. Treating the other tier as "missing" would make the
      // whole paywall unusable in every correctly configured country.
      if (response.error != null || loaded.isEmpty) {
        if (busy || purchaseGeneration != _purchaseEventGeneration) return;
        products = const {};
        state = VerifiedStoreState.unavailable;
        messageCode = 'prices_unavailable';
        notifyListeners();
        return;
      }
      products = Map.unmodifiable(loaded);
      _catalogStoreCountryCode = country;
      if (state == VerifiedStoreState.loading ||
          (_storeStartupFaultBeforeCatalog &&
              state == VerifiedStoreState.unavailable &&
              messageCode == null &&
              !busy)) {
        state = VerifiedStoreState.ready;
        messageCode = null;
        _storeStartupFaultBeforeCatalog = false;
      }
      _restoreCatalogAfterSettledInactiveReceipt();
      notifyListeners();
      await _queryCompletedAndroidPurchases();
    } on Object {
      if (_disposed || busy || purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
      state = VerifiedStoreState.offline;
      messageCode = 'store_network_failed';
      notifyListeners();
    } finally {
      await entitlementRefresh;
    }
  }
}
