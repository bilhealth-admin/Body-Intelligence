import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/subscription_term.dart';

part 'verified_store_purchase_support.dart';

class VerifiedStorePurchaseService extends ChangeNotifier {
  VerifiedStorePurchaseService({InAppPurchase? purchase})
    : _purchase = purchase ?? InAppPurchase.instance;

  final InAppPurchase _purchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  VerifiedStoreState state = VerifiedStoreState.loading;
  Map<String, ProductDetails> products = const {};
  VerifiedStoreEntitlement? entitlement;
  String? messageCode;
  GooglePlayPurchaseDetails? _activeGooglePurchase;

  bool get configured => AppEnvironment.commerceConfigured;
  bool get busy => state == VerifiedStoreState.purchasePending;

  Future<void> initialize() async {
    state = VerifiedStoreState.loading;
    messageCode = null;
    notifyListeners();
    final user = AppEnvironment.cloudConfigured
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (!configured || user == null) {
      state = VerifiedStoreState.unavailable;
      messageCode = 'configuration_required';
      notifyListeners();
      return;
    }
    _subscription ??= _purchase.purchaseStream.listen(
      (purchases) => unawaited(_consumePurchaseUpdates(purchases)),
      onError: (_) {
        state = VerifiedStoreState.failed;
        messageCode = 'store_stream_failed';
        notifyListeners();
      },
    );
    await refreshEntitlement();
    try {
      if (!await _purchase.isAvailable()) {
        state = VerifiedStoreState.unavailable;
        messageCode = 'store_unavailable';
        notifyListeners();
        return;
      }
      final response = await _purchase.queryProductDetails(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      final loaded = <String, ProductDetails>{};
      for (final product in response.productDetails) {
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
        products = const {};
        state = VerifiedStoreState.unavailable;
        messageCode = 'prices_unavailable';
        notifyListeners();
        return;
      }
      products = Map.unmodifiable(loaded);
      state = VerifiedStoreState.ready;
      notifyListeners();
      await _queryCompletedAndroidPurchases();
    } on Object {
      state = VerifiedStoreState.offline;
      messageCode = 'store_network_failed';
      notifyListeners();
    }
  }

  ProductDetails? productFor(
    CommercePlan plan, {
    required SubscriptionTerm term,
  }) {
    final binding = StoreCatalogConfiguration.bindingFor(
      plan: plan,
      term: term,
    );
    return binding == null ? null : products[binding.productId];
  }

  Future<void> purchasePlan(
    CommercePlan plan, {
    required SubscriptionTerm term,
    GooglePlayPurchaseDetails? replacesGooglePurchase,
    bool downgradeAtRenewal = false,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final product = productFor(plan, term: term);
    if (user == null || product == null || state != VerifiedStoreState.ready) {
      messageCode = 'purchase_unavailable';
      notifyListeners();
      return;
    }
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    final accountHash = storeAccountIdentifier(
      ownerId: user.id,
      platform: defaultTargetPlatform,
    );
    final PurchaseParam purchaseParam;
    if (defaultTargetPlatform == TargetPlatform.android &&
        product is GooglePlayProductDetails) {
      final previousPurchase = replacesGooglePurchase ?? _activeGooglePurchase;
      final isDowngrade = downgradeAtRenewal;
      // The platform wrapper already selects the exact base plan/offer used
      // to construct this ProductDetails instance. Reusing its token avoids
      // accidentally purchasing the first unrelated offer.
      final offerToken = product.offerToken;
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: accountHash,
        obfuscatedProfileId: accountHash,
        offerToken: offerToken,
        changeSubscriptionParam: previousPurchase == null
            ? null
            : ChangeSubscriptionParam(
                oldPurchaseDetails: previousPurchase,
                replacementMode: isDowngrade
                    ? ReplacementMode.deferred
                    : ReplacementMode.withTimeProration,
              ),
      );
    } else {
      purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: accountHash,
      );
    }
    try {
      final started = await _purchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (started) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      notifyListeners();
    } on Object {
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<void> purchaseBoost({String? offerToken}) async {
    final user = Supabase.instance.client.auth.currentUser;
    final product = products[StoreCatalogConfiguration.aiBoost];
    if (user == null || product == null || state != VerifiedStoreState.ready) {
      messageCode = 'purchase_unavailable';
      notifyListeners();
      return;
    }
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
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
    try {
      final started = await _purchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
      if (started) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      notifyListeners();
    } on Object {
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!configured || busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      state = VerifiedStoreState.unavailable;
      messageCode = 'authentication_required';
      notifyListeners();
      return;
    }
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    try {
      // On Apple this is the explicit user action that invokes AppStore.sync.
      await _purchase.restorePurchases();
      await refreshEntitlement();
      if (state == VerifiedStoreState.purchasePending) {
        state = entitlement?.grantsPaidAccess == true
            ? VerifiedStoreState.verified
            : products.isEmpty
            ? VerifiedStoreState.unavailable
            : VerifiedStoreState.ready;
        messageCode = entitlement?.grantsPaidAccess == true
            ? 'subscription_verified'
            : 'no_restorable_purchases';
        notifyListeners();
      }
    } on Object {
      state = VerifiedStoreState.failed;
      messageCode = 'restore_failed';
      notifyListeners();
    }
  }

  Future<void> refreshEntitlement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (!AppEnvironment.cloudConfigured || user == null) {
      entitlement = null;
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1);
      if (rows.isEmpty) {
        entitlement = null;
        return;
      }
      final row = rows.first;
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (verifiedAt == null) {
        entitlement = null;
        return;
      }
      entitlement = VerifiedStoreEntitlement(
        plan: _planFromId('${row['plan_id']}'),
        lifecycle: '${row['lifecycle']}',
        verifiedAt: verifiedAt,
        renewsOrExpiresAt: DateTime.tryParse('${row['expires_at']}')?.toUtc(),
        gracePeriodEndsAt: DateTime.tryParse(
          '${row['grace_period_ends_at']}',
        )?.toUtc(),
        provider: row['provider']?.toString(),
      );
    } on Object {
      // Never turn an unverifiable local label into paid access.
      entitlement = null;
    }
  }

  Future<void> manageSubscription({String? productId}) async {
    final Uri uri;
    if (defaultTargetPlatform == TargetPlatform.android) {
      uri = Uri.https('play.google.com', '/store/account/subscriptions', {
        'package': StoreCatalogConfiguration.packageName,
        if (productId != null && productId.isNotEmpty) 'sku': productId,
      });
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      messageCode = 'subscription_management_unavailable';
      notifyListeners();
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } on Object {
      // Expose a stable, localized failure rather than a platform exception.
    }
    messageCode = 'subscription_management_unavailable';
    notifyListeners();
  }

  Future<void> _queryCompletedAndroidPurchases() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final addition = _purchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error == null) {
        for (final purchase in response.pastPurchases) {
          if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) !=
              null) {
            _activeGooglePurchase = purchase;
            break;
          }
        }
        await _handlePurchases(response.pastPurchases);
      }
    } on Object {
      // Server refresh remains authoritative while Play is offline.
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = VerifiedStoreState.purchasePending;
          messageCode = 'purchase_pending';
          notifyListeners();
        case PurchaseStatus.error:
          state = VerifiedStoreState.failed;
          messageCode = 'purchase_failed';
          notifyListeners();
        case PurchaseStatus.canceled:
          state = VerifiedStoreState.cancelled;
          messageCode = 'purchase_cancelled';
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final boost = purchase.productID == StoreCatalogConfiguration.aiBoost;
          final verified = boost
              ? await _verifyBoostOnServer(purchase)
              : await _verifyOnServer(purchase);
          if (!boost && verified && purchase is GooglePlayPurchaseDetails) {
            _activeGooglePurchase = purchase;
          }
          // Google consumables are consumed by the server only after the
          // durable, idempotent credit succeeds. StoreKit still requires the
          // transaction to be completed on-device.
          if (verified && purchase.pendingCompletePurchase) {
            if (!boost || defaultTargetPlatform != TargetPlatform.android) {
              await _purchase.completePurchase(purchase);
            }
          }
          state = verified
              ? VerifiedStoreState.verified
              : VerifiedStoreState.failed;
          messageCode = verified
              ? boost
                    ? 'ai_boost_verified'
                    : 'subscription_verified'
              : 'verification_failed';
          notifyListeners();
      }
    }
  }

  Future<void> _consumePurchaseUpdates(List<PurchaseDetails> purchases) async {
    try {
      await _handlePurchases(purchases);
    } on Object {
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<bool> _verifyOnServer(PurchaseDetails purchase) async {
    if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) ==
        null) {
      return false;
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-store-purchase',
        body: <String, Object?>{
          'action': 'verify_purchase',
          'product_id': purchase.productID,
          'purchase_id': purchase.purchaseID,
          'source': purchase.verificationData.source,
          'verification_data': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      final verified =
          response.status == 200 &&
          data is Map &&
          data['verified'] == true &&
          data['entitlement_active'] == true;
      if (verified) await refreshEntitlement();
      return verified && entitlement?.grantsPaidAccess == true;
    } on Object {
      return false;
    }
  }

  Future<bool> _verifyBoostOnServer(PurchaseDetails purchase) async {
    if (purchase.productID != StoreCatalogConfiguration.aiBoost) return false;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-store-purchase',
        body: <String, Object?>{
          'action': 'verify_ai_boost',
          'product_id': purchase.productID,
          'source': purchase.verificationData.source,
          'verification_data': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      return response.status == 200 && data is Map && data['verified'] == true;
    } on Object {
      return false;
    }
  }

  CommercePlan _planFromId(String value) {
    return CommercePlan.values.firstWhere(
      (plan) => plan.id == value,
      orElse: () => CommercePlan.free,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
