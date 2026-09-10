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
import '../../../app/security/bil_mobile_integrity_service.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/subscription_term.dart';

part 'verified_store_purchase_support.dart';

class VerifiedStorePurchaseService extends ChangeNotifier {
  VerifiedStorePurchaseService({InAppPurchase? purchase})
    : _purchaseInstance = purchase;

  InAppPurchase? _purchaseInstance;
  InAppPurchase get _purchase => _purchaseInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  VerifiedStoreState state = VerifiedStoreState.loading;
  Map<String, ProductDetails> products = const {};
  VerifiedStoreEntitlement? entitlement;
  String? messageCode;
  GooglePlayPurchaseDetails? _activeGooglePurchase;
  Future<void>? _initialization;
  Future<void> _purchaseUpdates = Future<void>.value();
  int _queuedPurchaseUpdates = 0;
  int _purchaseEventGeneration = 0;
  bool _restoring = false;
  bool _disposed = false;
  int _entitlementRefreshGeneration = 0;

  bool get configured => AppEnvironment.commerceConfigured;
  bool get busy =>
      _restoring ||
      _queuedPurchaseUpdates > 0 ||
      state == VerifiedStoreState.purchasePending;
  bool get canStartPurchase =>
      !busy &&
      canStartStorePurchase(
        state: state,
        productAvailable: products.isNotEmpty,
        messageCode: messageCode,
      );

  Future<void> initialize() {
    if (_disposed || busy) return Future<void>.value();
    // The page timeout/resume path can call again while native StoreKit/Play
    // is still answering. Reuse that work rather than launching another query.
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    final purchaseGeneration = _purchaseEventGeneration;
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
        if (_disposed || _queuedPurchaseUpdates > 0) return;
        _purchaseEventGeneration++;
        state = VerifiedStoreState.failed;
        messageCode = 'store_stream_failed';
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
      final response = await _purchase
          .queryProductDetails(StoreCatalogConfiguration.storefrontProductIds)
          .timeout(const Duration(seconds: 10));
      if (_disposed) return;
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
        if (busy || purchaseGeneration != _purchaseEventGeneration) return;
        products = const {};
        state = VerifiedStoreState.unavailable;
        messageCode = 'prices_unavailable';
        notifyListeners();
        return;
      }
      products = Map.unmodifiable(loaded);
      if (state == VerifiedStoreState.loading) state = VerifiedStoreState.ready;
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
    // The button and service both guard this boundary. Keeping the service
    // idempotent prevents a second UI event from overwriting the truthful
    // pending state while the native sheet is opening.
    if (_disposed || busy) return;
    final user = Supabase.instance.client.auth.currentUser;
    final product = productFor(plan, term: term);
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
    final purchaseGeneration = _purchaseEventGeneration;
    try {
      final started = await _purchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (_disposed ||
          started ||
          purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      notifyListeners();
    } on Object {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<void> purchaseBoost({String? offerToken}) async {
    if (_disposed || busy) return;
    final user = Supabase.instance.client.auth.currentUser;
    final product = products[StoreCatalogConfiguration.aiBoost];
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
    final purchaseGeneration = _purchaseEventGeneration;
    try {
      final started = await _purchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
      if (_disposed ||
          started ||
          purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      notifyListeners();
    } on Object {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (_disposed || !configured || busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      state = VerifiedStoreState.unavailable;
      messageCode = 'authentication_required';
      notifyListeners();
      return;
    }
    _restoring = true;
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    try {
      // On Apple this is the explicit user action that invokes AppStore.sync.
      await _purchase.restorePurchases();
      // A restored callback may be verifying while the native restore Future
      // completes. Do not announce "nothing to restore" before it settles.
      while (_queuedPurchaseUpdates > 0) {
        await _purchaseUpdates;
      }
      if (_disposed) return;
      await refreshEntitlement();
      if (_disposed) return;
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
      if (_disposed) return;
      state = VerifiedStoreState.failed;
      messageCode = 'restore_failed';
      notifyListeners();
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> refreshEntitlement() async {
    if (_disposed) return;
    final generation = ++_entitlementRefreshGeneration;
    final user = AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user == null) {
      entitlement = null;
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (_disposed || generation != _entitlementRefreshGeneration) return;
      if (Supabase.instance.client.auth.currentUser?.id != user.id) {
        entitlement = null;
        return;
      }
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
      if (!_disposed && generation == _entitlementRefreshGeneration) {
        entitlement = null;
      }
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
      final response = await addition.queryPastPurchases().timeout(
        const Duration(seconds: 8),
      );
      if (response.error == null) {
        for (final purchase in response.pastPurchases) {
          if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) !=
              null) {
            _activeGooglePurchase = purchase;
            break;
          }
        }
        await _enqueuePurchaseUpdates(response.pastPurchases);
      }
    } on Object {
      // Server refresh remains authoritative while Play is offline.
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
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
          // A StoreKit/Play cancellation is neither a failed receipt nor an
          // entitlement. Return to the already loaded catalog immediately so
          // the member can choose another term (for example annual -> monthly)
          // without reopening the Plans route or being told that access failed.
          state = products.isEmpty
              ? VerifiedStoreState.unavailable
              : VerifiedStoreState.ready;
          messageCode = null;
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final boost = purchase.productID == StoreCatalogConfiguration.aiBoost;
          final verified = boost
              ? await _verifyBoostOnServer(purchase)
              : await _verifyOnServer(purchase);
          if (_disposed) return;
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
          if (_disposed) return;
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
      if (_disposed) return;
      state = VerifiedStoreState.failed;
      // Receipt delivery/acknowledgement may already follow a charge. This is
      // not a safe pre-launch retry and must never enable a second purchase.
      messageCode = 'verification_failed';
      notifyListeners();
    }
  }

  Future<void> _enqueuePurchaseUpdates(List<PurchaseDetails> purchases) {
    if (_disposed || purchases.isEmpty) return Future<void>.value();
    // Store callbacks own transaction outcomes. An older price/launch Future
    // must not publish a stale failure after any newer native transaction event.
    _purchaseEventGeneration++;
    _queuedPurchaseUpdates++;
    notifyListeners();
    // Native callbacks may overlap server verification. Preserve arrival order
    // and never acknowledge a pending or unverified transaction.
    return _purchaseUpdates = _purchaseUpdates.then((_) async {
      try {
        if (!_disposed) await _consumePurchaseUpdates(purchases);
      } finally {
        _queuedPurchaseUpdates--;
        notifyListeners();
      }
    });
  }

  Future<bool> _verifyOnServer(PurchaseDetails purchase) async {
    if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) ==
        null) {
      return false;
    }
    try {
      final body = <String, Object?>{
        'action': 'verify_purchase',
        'product_id': purchase.productID,
        'purchase_id': purchase.purchaseID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_purchase', payload: body)
          .timeout(const Duration(seconds: 12));
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
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
      final body = <String, Object?>{
        'action': 'verify_ai_boost',
        'product_id': purchase.productID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_ai_boost', payload: body)
          .timeout(const Duration(seconds: 12));
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
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
    _disposed = true;
    _entitlementRefreshGeneration++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
