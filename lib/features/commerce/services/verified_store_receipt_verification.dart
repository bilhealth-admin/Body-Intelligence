part of 'verified_store_purchase_service.dart';

extension _VerifiedStoreReceiptVerification on VerifiedStorePurchaseService {
  Future<_StoreReceiptVerificationResult> _verifyOnServer(
    PurchaseDetails purchase, {
    required String ownerId,
  }) async {
    if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) ==
        null) {
      return _StoreReceiptVerificationResult.failed;
    }
    try {
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final body = <String, Object?>{
        'action': 'verify_purchase',
        'delivery_version': 2,
        'product_id': purchase.productID,
        'purchase_id': purchase.purchaseID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_purchase', payload: body)
          .timeout(const Duration(seconds: 12));
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (!_isCurrentStoreOwner(ownerId) ||
          response.status != 200 ||
          data is! Map ||
          data['verified'] != true) {
        return _verificationFailure(data);
      }
      _acceptDelivery(
        StoreBenefitDelivery.parse(
          data['delivery'],
          ownerId: ownerId,
          productId: purchase.productID,
          source: purchase.verificationData.source,
        ),
      );
      checkoutTrace?.mark(StorePurchaseStage.serverProof);
      if (lastDelivery != null) {
        StorePurchaseTraceRegistry.bind(lastDelivery!.eventKey, checkoutTrace);
      }
      final entitlementActive = data['entitlement_active'];
      if (entitlementActive == true) {
        // If a prior receipt was authoritatively inactive, retain its
        // watermark until the canonical active row proves it is newer. This
        // preserves fail-closed behavior during read-replica lag.
        // The verification function persists first, but the read replica can
        // briefly lag. Retry the read a few times before reporting a false
        // verification failure to the native purchase queue.
        for (var attempt = 0; attempt < 3; attempt++) {
          if (!_isCurrentStoreOwner(ownerId)) {
            return _StoreReceiptVerificationResult.failed;
          }
          await refreshEntitlement();
          if (!_isCurrentStoreOwner(ownerId)) {
            return _StoreReceiptVerificationResult.failed;
          }
          if (entitlement?.grantsPaidAccess == true) {
            checkoutTrace?.mark(StorePurchaseStage.canonicalRead);
            break;
          }
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: attempt == 0 ? 150 : 300),
            );
          }
        }
        // An active response without a durable, access-granting canonical row
        // stays fail-closed. Completing it would discard the StoreKit evidence
        // before BIL can prove the entitlement.
        return entitlement?.grantsPaidAccess == true
            ? _StoreReceiptVerificationResult.verifiedActive
            : _StoreReceiptVerificationResult.failed;
      }
      if (entitlementActive == false) {
        // The server has verified and persisted an inactive lifecycle. Clear
        // any stale local paid snapshot first: a read failure must not retain
        // access after the server explicitly says it is inactive.
        _markServerVerifiedInactive(
          ownerId,
          verifiedAt: DateTime.tryParse('${data['verified_at']}')?.toUtc(),
        );
        await refreshEntitlement();
        if (!_isCurrentStoreOwner(ownerId)) {
          return _StoreReceiptVerificationResult.failed;
        }
        // The marker rejects only older replica rows. If the canonical read
        // already observes a newer active verification, publish that current
        // entitlement instead of reporting an obsolete empty restore.
        return entitlement?.grantsPaidAccess == true
            ? _StoreReceiptVerificationResult.verifiedActive
            : _StoreReceiptVerificationResult.verifiedInactive;
      }
      return _StoreReceiptVerificationResult.failed;
    } on FunctionException catch (error) {
      return _verificationFailure(error.details);
    } on Object {
      return _StoreReceiptVerificationResult.failed;
    }
  }

  Future<_StoreReceiptVerificationResult> _verifyBoostOnServer(
    PurchaseDetails purchase, {
    required String ownerId,
  }) async {
    if (purchase.productID != StoreCatalogConfiguration.aiBoost) {
      return _StoreReceiptVerificationResult.failed;
    }
    try {
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final body = <String, Object?>{
        'action': 'verify_ai_boost',
        'product_id': purchase.productID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_ai_boost', payload: body)
          .timeout(const Duration(seconds: 12));
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      return response.status == 200 && data is Map && data['verified'] == true
          ? _StoreReceiptVerificationResult.verifiedActive
          : _verificationFailure(data);
    } on FunctionException catch (error) {
      return _verificationFailure(error.details);
    } on Object {
      return _StoreReceiptVerificationResult.failed;
    }
  }

  _StoreReceiptVerificationResult _verificationFailure(Object? data) {
    // Allowlist the server's public code; never render raw error/receipt data
    // or the identity of the other account in the storefront.
    return data is Map && data['error'] == 'purchase_owned_by_another_account'
        ? _StoreReceiptVerificationResult.ownershipConflict
        : _StoreReceiptVerificationResult.failed;
  }
}
