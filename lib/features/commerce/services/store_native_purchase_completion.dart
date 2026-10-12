import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// Android's platform implementation returns a billing result, but the generic
/// `Future<void>` wrapper discards non-OK acknowledgement responses. Keep that
/// result at the native boundary so a committed benefit still has a finish retry.
Future<void> completeVerifiedNativePurchase(
  InAppPurchase store,
  PurchaseDetails purchase,
) async {
  if (defaultTargetPlatform == TargetPlatform.android &&
      purchase is GooglePlayPurchaseDetails) {
    final platform = InAppPurchasePlatform.instance;
    if (platform is! InAppPurchaseAndroidPlatform) {
      throw StateError('store_finish_unavailable');
    }
    final result = await platform.completePurchase(purchase);
    if (result.responseCode != BillingResponse.ok) {
      // A timed-out earlier acknowledgement can have succeeded in Play while
      // this callback's cached isAcknowledged is still false. Reconcile only
      // this exact owned, purchased subscription before retiring its retry.
      try {
        final fresh = await store
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .queryPastPurchases()
            .timeout(const Duration(seconds: 8));
        if (fresh.error == null &&
            fresh.pastPurchases.whereType<GooglePlayPurchaseDetails>().any((
              details,
            ) {
              final item = details.billingClientPurchase;
              return item.purchaseToken ==
                      purchase.verificationData.serverVerificationData &&
                  item.packageName ==
                      purchase.billingClientPurchase.packageName &&
                  item.products.contains(purchase.productID) &&
                  item.isAcknowledged &&
                  item.purchaseState == PurchaseStateWrapper.purchased;
            })) {
          return;
        }
      } on Object {
        // An unreadable/unknown native result remains the same finish retry.
      }
      // Do not log the token, billing debug message or receipt here.
      throw StateError('store_finish_pending');
    }
    return;
  }
  await store.completePurchase(purchase);
}
