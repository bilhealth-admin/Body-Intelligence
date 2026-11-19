part of 'ai_boost_purchase_service.dart';

extension AiBoostPlayLicenseRecovery on AiBoostPurchaseService {
  bool get canRecoverPlayLicense =>
      !_disposed &&
      !_licenseRepairInFlight &&
      !_checkoutInFlight &&
      !_reconciling &&
      _queued == 0 &&
      _owner() == _catalogOwner &&
      _catalogOwner != null &&
      defaultTargetPlatform == TargetPlatform.android &&
      state != AiBoostPurchaseState.pending &&
      errorCode == 'license_unlicensed';

  /// Explicit repair only, including an unresolved receipt. Never opens Billing
  /// or verifies/retries/finishes that receipt, and never clears its blocker.
  Future<void> recoverPlayLicense() async {
    if (!canRecoverPlayLicense) return;
    final owner = _catalogOwner!;
    final generation = _generation;
    final visit = _accountVisit.capture();
    _licenseRepairInFlight = true;
    notifyListeners();
    try {
      final result = await _androidReadiness.check(
        ownerId: owner,
        productId: AiBoostPurchaseService.productId,
        isCurrent: () =>
            _current(owner, generation) &&
            _accountVisit.isCurrent(visit) &&
            _queued == 0,
      );
      if (!_current(owner, generation) || !_accountVisit.isCurrent(visit)) {
        return;
      }
      if (result == AndroidPurchaseReadiness.ready ||
          result == AndroidPurchaseReadiness.reviewRequired) {
        _publish(
          _unresolved == null
              ? AiBoostPurchaseState.ready
              : AiBoostPurchaseState.failed,
          _unresolved == null
              ? 'play_license_recovered'
              : 'play_license_recovered_pending',
        );
      } else if (result != AndroidPurchaseReadiness.retired) {
        _publish(AiBoostPurchaseState.failed, 'license_unlicensed');
      }
    } finally {
      _licenseRepairInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }
}

extension _AiBoostFreshQuote on AiBoostPurchaseService {
  Future<ProductDetails?> _freshBoostQuote(
    ProductDetails displayed,
    String owner,
    int generation,
    StoreAccountSnapshot visit,
  ) async {
    bool current() =>
        _checkoutInFlight &&
        _current(owner, generation) &&
        _accountVisit.isCurrent(visit) &&
        _unresolved == null &&
        _queued == 0 &&
        !StoreVerificationRequestPolicy.shared.isBackedOff(owner);
    try {
      final response = await _purchase
          .queryProductDetails({AiBoostPurchaseService.productId})
          .timeout(launchTimeout);
      if (!current()) return null;
      final fresh = response.productDetails
          .where((p) => p.id == AiBoostPurchaseService.productId)
          .firstOrNull;
      if (response.error != null ||
          response.notFoundIDs.contains(AiBoostPurchaseService.productId) ||
          fresh == null) {
        _publish(AiBoostPurchaseState.ready, 'store_catalog_changed');
        return null;
      }
      final discount = googlePlayOneTimeDiscountMetadata(fresh);
      final freshPrice = discount?.localizedPrice ?? fresh.price;
      final freshToken = discount?.offerToken;
      final unchanged =
          displayed.currencyCode == fresh.currencyCode &&
          displayed.rawPrice == fresh.rawPrice &&
          displayPrice == freshPrice &&
          _purchaseOfferToken == freshToken;
      product = fresh;
      displayPrice = freshPrice;
      _purchaseOfferToken = freshToken;
      if (!unchanged) {
        _publish(AiBoostPurchaseState.ready, 'store_catalog_changed');
        return null;
      }
      return fresh;
    } on Object {
      if (current()) {
        _publish(AiBoostPurchaseState.ready, 'store_catalog_changed');
      }
      return null;
    }
  }
}
