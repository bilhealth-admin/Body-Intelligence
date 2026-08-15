import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';

enum StoreConnectionState {
  loading,
  ready,
  unavailable,
  purchasePending,
  verified,
  failed,
}

@Deprecated('Use StoreCatalogConfiguration and VerifiedStorePurchaseService.')
class StoreProductIds {
  static const proMonthly = String.fromEnvironment(
    'BIL_STORE_PRO_MONTHLY',
    defaultValue: '',
  );
  static const proAnnual = String.fromEnvironment(
    'BIL_STORE_PRO_ANNUAL',
    defaultValue: '',
  );
  static const coachMonthly = String.fromEnvironment(
    'BIL_STORE_COACH_MONTHLY',
    defaultValue: '',
  );
  static const coachAnnual = String.fromEnvironment(
    'BIL_STORE_COACH_ANNUAL',
    defaultValue: '',
  );

  static Set<String> get all => <String>[
    proMonthly,
    proAnnual,
  ].where((id) => id.isNotEmpty).toSet();

  static String? forPlan(String plan, {required bool annual}) => switch (plan) {
    'BIL Pro' => annual ? proAnnual : proMonthly,
    _ => null,
  };
}

@Deprecated('Use VerifiedStorePurchaseService. This adapter is not routed.')
class AppStorePurchaseService extends ChangeNotifier {
  AppStorePurchaseService({InAppPurchase? purchase})
    : _purchase = purchase ?? InAppPurchase.instance;

  final InAppPurchase _purchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  StoreConnectionState state = StoreConnectionState.loading;
  Map<String, ProductDetails> products = const {};
  String? message;

  Future<void> initialize() async {
    if (!AppEnvironment.commerceConfigured ||
        !AppEnvironment.cloudConfigured ||
        Supabase.instance.client.auth.currentUser == null) {
      state = StoreConnectionState.unavailable;
      message = 'Store connection or signed-in account is unavailable.';
      notifyListeners();
      return;
    }
    _subscription = _purchase.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        state = StoreConnectionState.failed;
        message = error.toString();
        notifyListeners();
      },
    );
    if (!await _purchase.isAvailable()) {
      state = StoreConnectionState.unavailable;
      message = 'The device store is unavailable.';
      notifyListeners();
      return;
    }
    final response = await _purchase.queryProductDetails(StoreProductIds.all);
    products = {
      for (final product in response.productDetails) product.id: product,
    };
    state = products.isEmpty
        ? StoreConnectionState.unavailable
        : StoreConnectionState.ready;
    message = response.error?.message;
    notifyListeners();
  }

  ProductDetails? productFor(String plan, {required bool annual}) {
    final id = StoreProductIds.forPlan(plan, annual: annual);
    return id == null ? null : products[id];
  }

  Future<void> purchasePlan(String plan, {required bool annual}) async {
    final product = productFor(plan, annual: annual);
    if (product == null || state != StoreConnectionState.ready) return;
    state = StoreConnectionState.purchasePending;
    message = null;
    notifyListeners();
    final started = await _purchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      state = StoreConnectionState.failed;
      message = 'The store did not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    state = StoreConnectionState.purchasePending;
    notifyListeners();
    await _purchase.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        state = StoreConnectionState.purchasePending;
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        state = StoreConnectionState.failed;
        message = purchase.error?.message ?? 'Purchase canceled.';
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyOnServer(purchase);
        if (verified && purchase.pendingCompletePurchase) {
          await _purchase.completePurchase(purchase);
        }
        state = verified
            ? StoreConnectionState.verified
            : StoreConnectionState.failed;
        message = verified
            ? 'Subscription verified by BIL.'
            : 'The receipt could not be verified. No entitlement was granted.';
        notifyListeners();
      }
    }
  }

  Future<bool> _verifyOnServer(PurchaseDetails purchase) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-store-purchase',
        body: {
          'product_id': purchase.productID,
          'purchase_id': purchase.purchaseID,
          'source': purchase.verificationData.source,
          'verification_data': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      return response.status == 200 &&
          data is Map &&
          data['verified'] == true &&
          data['entitlement_active'] == true;
    } on Object {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
