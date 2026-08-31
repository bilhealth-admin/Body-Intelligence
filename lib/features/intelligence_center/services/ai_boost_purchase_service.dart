import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../commerce/domain/store_catalog_configuration.dart';
import '../../commerce/services/verified_store_catalog_adapter.dart';
import '../../commerce/services/verified_store_purchase_service.dart';

enum AiBoostPurchaseState {
  loading,
  ready,
  pending,
  verified,
  unavailable,
  failed,
}

/// Repeatable consumable purchase transport. A store callback never grants
/// credit locally; only the verified server response can change balances.
final class AiBoostPurchaseService extends ChangeNotifier {
  AiBoostPurchaseService({InAppPurchase? purchase})
    : _purchase = purchase ?? InAppPurchase.instance;

  static const productId = StoreCatalogConfiguration.aiBoost;
  final InAppPurchase _purchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;
  String? displayPrice;
  String? _purchaseOfferToken;
  AiBoostPurchaseState state = AiBoostPurchaseState.loading;
  String? errorCode;

  Future<void> initialize() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !await _purchase.isAvailable()) {
      state = AiBoostPurchaseState.unavailable;
      notifyListeners();
      return;
    }
    _subscription ??= _purchase.purchaseStream.listen(
      (items) => unawaited(_handle(items)),
      onError: (_) {
        state = AiBoostPurchaseState.failed;
        errorCode = 'store_stream_failed';
        notifyListeners();
      },
    );
    final response = await _purchase.queryProductDetails({productId});
    product = response.productDetails
        .where((item) => item.id == productId)
        .firstOrNull;
    final discount = product == null
        ? null
        : googlePlayOneTimeDiscountMetadata(product!);
    displayPrice = discount?.localizedPrice ?? product?.price;
    _purchaseOfferToken = discount?.offerToken;
    state = response.error == null && product != null
        ? AiBoostPurchaseState.ready
        : AiBoostPurchaseState.unavailable;
    errorCode = product == null ? 'product_not_available' : null;
    notifyListeners();
  }

  Future<void> purchaseBoost() async {
    final user = Supabase.instance.client.auth.currentUser;
    final selected = product;
    if (user == null ||
        selected == null ||
        state != AiBoostPurchaseState.ready) {
      return;
    }
    state = AiBoostPurchaseState.pending;
    errorCode = null;
    notifyListeners();
    final accountHash = storeAccountIdentifier(
      ownerId: user.id,
      platform: defaultTargetPlatform,
    );
    final started = await _purchase.buyConsumable(
      purchaseParam: verifiedBoostPurchaseParam(
        product: selected,
        accountHash: accountHash,
        platform: defaultTargetPlatform,
        offerToken: _purchaseOfferToken,
      ),
      autoConsume: false,
    );
    if (!started) {
      state = AiBoostPurchaseState.failed;
      errorCode = 'purchase_not_started';
      notifyListeners();
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases.where(
      (item) => item.productID == productId,
    )) {
      if (purchase.status == PurchaseStatus.pending) {
        state = AiBoostPurchaseState.pending;
        notifyListeners();
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        state = AiBoostPurchaseState.failed;
        errorCode = 'purchase_failed';
        notifyListeners();
        continue;
      }
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'verify-store-purchase',
          body: <String, Object?>{
            'action': 'verify_ai_boost',
            'product_id': productId,
            'source': purchase.verificationData.source,
            'verification_data':
                purchase.verificationData.serverVerificationData,
          },
        );
        final data = response.data;
        final verified =
            response.status == 200 && data is Map && data['verified'] == true;
        if (!verified) throw StateError('verification_failed');
        // Google is consumed by the server after durable idempotent credit.
        // Apple transactions still need StoreKit completion on-device.
        if (defaultTargetPlatform != TargetPlatform.android &&
            purchase.pendingCompletePurchase) {
          await _purchase.completePurchase(purchase);
        }
        state = AiBoostPurchaseState.verified;
        errorCode = null;
      } on Object {
        state = AiBoostPurchaseState.failed;
        errorCode = 'verification_failed';
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
