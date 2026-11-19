import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../domain/subscription_state.dart';
import '../repositories/server_entitlement_repository.dart';
import 'store_account_visit.dart';

/// No SKU or receipt is synthesized from a plugin-wide checkout result.
final class AndroidCheckoutFailureAttempt {
  const AndroidCheckoutFailureAttempt(
    this.visit,
    this.generation,
    this.productId, {
    this.response,
  });
  final StoreAccountSnapshot visit;
  final int generation;
  final String productId;
  final BillingResponse? response;
  bool get witnessed => response != null;
  bool get cancelled => response == BillingResponse.userCanceled;

  AndroidCheckoutFailureAttempt withResponse(BillingResponse value, int next) =>
      AndroidCheckoutFailureAttempt(visit, next, productId, response: value);
}

/// These are the exact empty-purchase events emitted by the installed official
/// Android plugin. Unknown/receipt-bearing or other-provider events stay on
/// their existing paths. The result is presentation evidence, never a receipt.
BillingResponse? unscopedAndroidCheckoutResponse(PurchaseDetails purchase) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      purchase.productID.isNotEmpty ||
      purchase.purchaseID?.isNotEmpty == true ||
      purchase.transactionDate != null ||
      purchase.verificationData.source != 'google_play' ||
      purchase.verificationData.serverVerificationData.isNotEmpty ||
      purchase.verificationData.localVerificationData.isNotEmpty ||
      purchase.error?.source != 'google_play' ||
      purchase.error?.code != 'purchase_error') {
    return null;
  }
  final response = BillingResponse.values
      .where((value) => value.toString() == purchase.error?.message)
      .firstOrNull;
  if (response == null || response == BillingResponse.ok) return null;
  if (purchase.status == PurchaseStatus.canceled) {
    return response == BillingResponse.userCanceled ? response : null;
  }
  return purchase.status == PurchaseStatus.error &&
          response != BillingResponse.userCanceled
      ? response
      : null;
}

/// Only explicit recovery invokes this read-only proof. Both official native
/// queries must succeed twice, with a fresh canonical owner read in between.
/// It changes no entitlement, credit, receipt, native finish or account state.
final class AndroidCheckoutFailureRecovery {
  const AndroidCheckoutFailureRecovery({
    this.inventoryReader,
    this.canonicalReader,
  });
  final Future<QueryPurchaseDetailsResponse> Function(InAppPurchase)?
  inventoryReader;
  final Future<SubscriptionState> Function()? canonicalReader;

  Future<bool> assess({
    required InAppPurchase purchase,
    required bool Function() current,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !current()) {
      return false;
    }
    Future<QueryPurchaseDetailsResponse> inventory() =>
        (inventoryReader?.call(purchase) ??
                purchase
                    .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                    .queryPastPurchases())
            .timeout(const Duration(seconds: 8));
    bool empty(QueryPurchaseDetailsResponse response) =>
        response.error == null && response.pastPurchases.isEmpty;
    try {
      final first = await inventory();
      if (!current() || !empty(first)) return false;
      final canonical =
          await (canonicalReader?.call() ??
                  const ServerEntitlementRepository()
                      .currentForExplicitCheckoutRecovery())
              .timeout(const Duration(seconds: 12));
      if (!current() ||
          canonical.authority != EntitlementAuthority.verifiedServer) {
        return false;
      }
      final second = await inventory();
      return current() && empty(second);
    } on Object {
      return false;
    }
  }
}

// Even a foreign/other-lane receipt retires an in-flight negative inventory
// proof. This observation never consumes or verifies that item in this lane.
bool isAndroidReceiptObservation(PurchaseDetails purchase) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  if (const {
    PurchaseStatus.pending,
    PurchaseStatus.purchased,
    PurchaseStatus.restored,
  }.contains(purchase.status)) {
    return true;
  }
  final bearsReceipt =
      purchase.purchaseID?.trim().isNotEmpty == true ||
      purchase.verificationData.serverVerificationData.trim().isNotEmpty ||
      purchase.verificationData.localVerificationData.trim().isNotEmpty;
  return bearsReceipt &&
      const {
        PurchaseStatus.canceled,
        PurchaseStatus.error,
      }.contains(purchase.status);
}
