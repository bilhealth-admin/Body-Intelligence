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
  bool _purchaseInitiatedByThisService = false;
  String? _purchaseInitiatedProductId;
  bool _storeStartupFaultBeforeCatalog = false;
  Completer<void>? _restoreEventObserved;
  String? _entitlementOwnerId;

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
        if (_disposed || _queuedPurchaseUpdates > 0) return;
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
        messageCode = outcome.messageCode;
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
      if (state == VerifiedStoreState.loading ||
          _storeStartupFaultBeforeCatalog) {
        state = VerifiedStoreState.ready;
        messageCode = null;
        _storeStartupFaultBeforeCatalog = false;
      }
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
      _purchaseInitiatedByThisService = true;
      _purchaseInitiatedProductId = product.id;
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
      _clearPurchaseInitiation();
      notifyListeners();
    } on Object {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      _clearPurchaseInitiation();
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
      _purchaseInitiatedByThisService = true;
      _purchaseInitiatedProductId = product.id;
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
      _clearPurchaseInitiation();
      notifyListeners();
    } on Object {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_failed';
      _clearPurchaseInitiation();
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
    final restoreEventObserved = Completer<void>();
    _restoreEventObserved = restoreEventObserved;
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    try {
      // On Apple this is the explicit user action that invokes AppStore.sync.
      await _purchase.restorePurchases();
      // StoreKit may complete AppStore.sync just before it publishes its
      // restored transaction to the stream.  Wait briefly for that callback
      // instead of falsely reporting an empty history; a later callback still
      // remains safely queued and is never treated as a new purchase.
      await Future.any<void>([
        restoreEventObserved.future,
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
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
      if (identical(_restoreEventObserved, restoreEventObserved)) {
        _restoreEventObserved = null;
      }
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
      _clearEntitlement();
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
        // Never carry one member's verified purchase into another member's
        // session, even if the original request finishes after auth changes.
        _clearEntitlement();
        return;
      }
      if (rows.isEmpty) {
        // A successful empty read is possible for a short period while the
        // verification function's write is replicating. Keep a still-valid,
        // server-verified entitlement for this owner instead of flashing the
        // paid surfaces back to Free.
        _retainEntitlementIfValid(user.id);
        return;
      }
      final row = rows.first;
      final verifiedAt = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      if (verifiedAt == null) {
        _retainEntitlementIfValid(user.id);
        return;
      }
      final plan = _planFromIdOrNull('${row['plan_id']}');
      final lifecycle = '${row['lifecycle']}'.trim().toLowerCase();
      final provider = row['provider']?.toString().trim().toLowerCase();
      final expiresAt = DateTime.tryParse('${row['expires_at']}')?.toUtc();
      final gracePeriodEndsAt = DateTime.tryParse(
        '${row['grace_period_ends_at']}',
      )?.toUtc();
      if (plan == null ||
          !_knownStoreLifecycles.contains(lifecycle) ||
          (provider != 'apple' && provider != 'google') ||
          (_accessLifecycles.contains(lifecycle) &&
              (lifecycle == 'grace_period'
                  ? gracePeriodEndsAt == null
                  : expiresAt == null))) {
        // Unknown/malformed rows are unreadable snapshots, not proof of a
        // revocation. Preserve the last valid entitlement only within its
        // own billing boundary.
        _retainEntitlementIfValid(user.id);
        return;
      }
      entitlement = VerifiedStoreEntitlement(
        plan: plan,
        lifecycle: lifecycle,
        verifiedAt: verifiedAt,
        renewsOrExpiresAt: expiresAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
        provider: provider,
      );
      _entitlementOwnerId = user.id;
    } on Object {
      // Never turn an unverifiable local label into paid access, but do not
      // erase a still-valid server-verified result for a transient failure.
      if (!_disposed && generation == _entitlementRefreshGeneration) {
        _retainEntitlementIfValid(user.id);
      }
    }
  }

  static const _knownStoreLifecycles = {
    'pending',
    'trial',
    'active',
    'grace_period',
    'billing_retry',
    'account_hold',
    'paused',
    'suspended',
    'deferred',
    'cancelled',
    'expired',
    'refunded',
    'revoked',
  };

  static const _accessLifecycles = {
    'trial',
    'active',
    'grace_period',
    'cancelled',
  };

  void _clearEntitlement() {
    entitlement = null;
    _entitlementOwnerId = null;
  }

  void _retainEntitlementIfValid(String ownerId) {
    final current = entitlement;
    if (_entitlementOwnerId != ownerId ||
        current == null ||
        !current.grantsPaidAccess) {
      _clearEntitlement();
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
      final origin = _purchaseEventOriginFor(purchase);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = VerifiedStoreState.purchasePending;
          messageCode = switch (origin) {
            _StorePurchaseEventOrigin.purchase => 'purchase_pending',
            _StorePurchaseEventOrigin.restore => 'restore_pending',
            _StorePurchaseEventOrigin.reconciliation =>
              'reconciliation_pending',
          };
          notifyListeners();
        case PurchaseStatus.error:
          if (origin == _StorePurchaseEventOrigin.reconciliation) {
            // A StoreKit error replayed while merely opening the Plans screen
            // is not a new checkout and does not represent a charge.  It is
            // safe to keep the loaded catalog actionable.
            if (products.isEmpty && state == VerifiedStoreState.loading) {
              // StoreKit can publish a historical error before the product
              // query settles.  Treat it like a startup transport fault: a
              // subsequent valid catalog must remain purchasable.
              _storeStartupFaultBeforeCatalog = true;
            }
            state = products.isEmpty
                ? VerifiedStoreState.unavailable
                : VerifiedStoreState.ready;
            messageCode = null;
          } else {
            state = VerifiedStoreState.failed;
            messageCode = origin == _StorePurchaseEventOrigin.restore
                ? 'restore_failed'
                : 'purchase_failed';
          }
          if (origin == _StorePurchaseEventOrigin.purchase) {
            _clearPurchaseInitiation();
          }
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
          if (origin == _StorePurchaseEventOrigin.purchase) {
            _clearPurchaseInitiation();
          }
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
              : switch (origin) {
                  _StorePurchaseEventOrigin.purchase => 'verification_failed',
                  _StorePurchaseEventOrigin.restore =>
                    'restore_verification_failed',
                  _StorePurchaseEventOrigin.reconciliation =>
                    'reconciliation_verification_failed',
                };
          if (origin == _StorePurchaseEventOrigin.purchase) {
            _clearPurchaseInitiation();
          }
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
    final restoreEventObserved = _restoreEventObserved;
    if (restoreEventObserved != null && !restoreEventObserved.isCompleted) {
      restoreEventObserved.complete();
    }
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
      if (verified) {
        // The verification function persists first, but the read replica can
        // briefly lag. Retry the read a few times before reporting a false
        // verification failure to the native purchase queue.
        for (var attempt = 0; attempt < 3; attempt++) {
          await refreshEntitlement();
          if (entitlement?.grantsPaidAccess == true) break;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: attempt == 0 ? 150 : 300),
            );
          }
        }
      }
      // Keep the explicit server-row check: the function response proves the
      // receipt, while the row is the durable entitlement consumed by every
      // paid surface. The bounded retries above only bridge read-replica lag.
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

  _StorePurchaseEventOrigin _purchaseEventOriginFor(
    PurchaseDetails purchase,
  ) {
    if (_restoring) return _StorePurchaseEventOrigin.restore;
    if (_purchaseInitiatedByThisService &&
        _purchaseInitiatedProductId == purchase.productID) {
      return _StorePurchaseEventOrigin.purchase;
    }
    return _StorePurchaseEventOrigin.reconciliation;
  }

  void _clearPurchaseInitiation() {
    _purchaseInitiatedByThisService = false;
    _purchaseInitiatedProductId = null;
  }

  CommercePlan _planFromId(String value) {
    return CommercePlan.values.firstWhere(
      (plan) => plan.id == value,
      orElse: () => CommercePlan.free,
    );
  }

  CommercePlan? _planFromIdOrNull(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'free') {
      return normalized == 'free' ? CommercePlan.free : null;
    }
    final plan = _planFromId(normalized);
    return plan == CommercePlan.free ? null : plan;
  }

  @override
  void dispose() {
    _disposed = true;
    _entitlementRefreshGeneration++;
    _clearEntitlement();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

enum _StorePurchaseEventOrigin { purchase, restore, reconciliation }
