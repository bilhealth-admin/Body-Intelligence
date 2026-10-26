import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../../community/services/community_owner_operation.dart';
import 'store_account_visit.dart';
import 'store_purchase_trace.dart';
import 'store_native_purchase_completion.dart';
import '../domain/store_benefit_delivery.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/subscription_term.dart';
import '../repositories/server_entitlement_repository.dart'
    show isAcceptableServerVerificationTimestamp;

part 'verified_store_purchase_support.dart';
part 'verified_store_purchase_processing.dart';
part 'verified_store_receipt_verification.dart';
part 'verified_store_purchase_checkout.dart';
part 'verified_store_purchase_restore.dart';
part 'verified_store_purchase_owned.dart';
part 'verified_store_purchase_pending.dart';
part 'verified_store_purchase_completion.dart';

class VerifiedStorePurchaseService extends ChangeNotifier {
  VerifiedStorePurchaseService({
    InAppPurchase? purchase,
    this._appleStoreSync,
    this.pendingTimeout = const Duration(seconds: 90),
    this.handlesBoost = true,
  }) : _purchaseInstance = purchase;

  InAppPurchase? _purchaseInstance;
  final Future<void> Function()? _appleStoreSync;
  final Duration pendingTimeout;
  final bool handlesBoost;
  late final StoreAccountVisit _storeVisit = StoreAccountVisit(
    readOwner: _currentStoreOwnerId,
    changes: storeAccountOwnerChanges(),
    onChanged: _retireStoreOwner,
  );
  int verifiedBenefitRevision = 0;
  String? benefitOwnerId;
  String? benefitStoreSource;
  DateTime? get verifiedInactiveAt =>
      _serverVerifiedInactiveOwnerId == benefitOwnerId &&
          _serverVerifiedInactiveFallbackExpiresAt == null &&
          isAcceptableServerVerificationTimestamp(
            verifiedAt: _serverVerifiedInactiveAt,
            now: DateTime.now().toUtc(),
          )
      ? _serverVerifiedInactiveAt
      : null;
  StoreBenefitDelivery? lastDelivery;
  final _deliveries = <String, StoreBenefitDelivery>{};
  bool deliveryIsActive(String key) =>
      !_disposed &&
      benefitOwnerId != null &&
      _isCurrentStoreOwner(benefitOwnerId!) &&
      _deliveries[key]?.active == true;
  void _acceptDelivery(StoreBenefitDelivery? event) {
    lastDelivery = event;
    if (event == null) return;
    if (_deliveries.length >= 128) _deliveries.remove(_deliveries.keys.first);
    _deliveries[event.eventKey] = event;
  }

  bool lastDeliveryIsUserPurchase = false;
  // UI continuations belong to the durable service zone, not the temporary
  // authenticated HTTP-operation zone that retires after verification.
  final Zone _notificationZone = Zone.current;
  StorePurchaseTrace? checkoutTrace;
  final Set<String> _publishedBenefits = {};
  InAppPurchase get _purchase => _purchaseInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  VerifiedStoreState state = VerifiedStoreState.loading;
  Map<String, ProductDetails> products = const {};
  VerifiedStoreEntitlement? entitlement;
  String? messageCode;
  String? ownershipConflictProductId;
  String? lastVerifiedProductId;
  GooglePlayPurchaseDetails? _activeGooglePurchase;
  Future<void>? _initialization;
  Future<void> _purchaseUpdates = Future<void>.value();
  int _queuedPurchaseUpdates = 0;
  int _purchaseEventGeneration = 0;
  bool _restoring = false;
  Future<void>? _nativeRestoreOperation;
  bool _restoreOwnershipConflict = false;
  bool _checkoutPreflightInFlight = false;
  bool _disposed = false;
  int _entitlementRefreshGeneration = 0;
  bool _purchaseInitiatedByThisService = false;
  String? _purchaseInitiatedProductId;
  Timer? _purchaseWatchdog;
  bool _storeStartupFaultBeforeCatalog = false;
  bool _appleDuplicateRetryInFlight = false;
  Completer<void>? _restoreEventObserved;
  String? _entitlementOwnerId;
  // A server-verified inactive lifecycle is authoritative over a briefly
  // stale subscription-row read. The marker is owner-scoped and is cleared
  // by a later server-verified active receipt or a newer canonical row.
  String? _serverVerifiedInactiveOwnerId;
  DateTime? _serverVerifiedInactiveAt;
  DateTime? _serverVerifiedInactiveFallbackExpiresAt;
  final Set<String> _queuedTransactionKeys = <String>{};
  final Set<String> _explicitRestoreTransactionKeys = <String>{};
  final Map<String, PurchaseDetails> _pendingVerifiedFinishes = {};
  Future<void>? _verifiedFinishRetry;

  /// Retrying an acknowledgement never opens another purchase sheet or
  /// changes a server-confirmed benefit. Native unfinished transactions also
  /// replay after restart; receipts remain server-idempotent.
  // The authenticated app owns this service. Keep only failed
  // transaction fingerprints process-local so reopening that page cannot turn
  // one unfinished StoreKit transaction into a verification storm. Keys are
  // owner-scoped hashes; no entitlement or raw receipt is cached here.
  static const _failedTransactionReplayCooldown = Duration(minutes: 5);
  // StoreKit may publish a purchase update after the native purchase call
  // returns. Never leave the Plans button permanently disabled if that
  // callback is lost or the platform sheet stops responding.
  static const _maximumFailedTransactionCooldowns = 256;
  static final Map<String, DateTime> _failedTransactionCooldowns =
      <String, DateTime>{};

  @visibleForTesting
  static void resetTransactionReplayProtectionForTesting() {
    _failedTransactionCooldowns.clear();
  }

  bool get configured => AppEnvironment.commerceConfigured;
  bool get hasPendingVerifiedFinish => _pendingVerifiedFinishes.isNotEmpty;
  bool get isRestoring => _restoring;
  bool get busy =>
      _restoring ||
      _checkoutPreflightInFlight ||
      _queuedPurchaseUpdates > 0 ||
      state == VerifiedStoreState.purchasePending;
  bool get canStartPurchase =>
      !busy &&
      _nativeRestoreOperation == null &&
      canStartStorePurchase(
        state: state,
        productAvailable: products.isNotEmpty,
        messageCode: messageCode,
      );

  Future<void> initialize() {
    if (_disposed || busy) return Future<void>.value();
    _storeVisit.capture();
    if (const {
      'purchase_status_unknown',
      'store_finish_pending',
      'verification_failed',
      'restore_verification_failed',
      'reconciliation_verification_failed',
      'purchase_owned_by_another_account',
    }.contains(messageCode)) {
      return Future<void>.value();
    }
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
        // StoreKit can deliver the stream error after the receipt callback has
        // completed. In that ordering the queue count is already zero, but
        // the verified entitlement is still the authoritative result and a
        // stale stream fault must not downgrade it to a catalog-ready state.
        if (_disposed ||
            _queuedPurchaseUpdates > 0 ||
            state == VerifiedStoreState.verified) {
          return;
        }
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

  /// Play ProductDetails/offer tokens may expire while the page stays open.
  /// Refresh on the explicit purchase tap and never silently substitute a
  /// different price, base plan or trial. This does not start a transaction.
  Future<void> purchasePlan(
    CommercePlan plan, {
    required SubscriptionTerm term,
    GooglePlayPurchaseDetails? replacesGooglePurchase,
    bool downgradeAtRenewal = false,
    String? expectedGoogleOfferToken,
  }) async {
    // The button and service both guard this boundary. Keeping the service
    // idempotent prevents a second UI event from overwriting the truthful
    // pending state while the native sheet is opening.
    if (_disposed || busy || _nativeRestoreOperation != null) return;
    final user = Supabase.instance.client.auth.currentUser;
    var product = productFor(plan, term: term);
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
    if (defaultTargetPlatform == TargetPlatform.android &&
        expectedGoogleOfferToken != null &&
        (product is! GooglePlayProductDetails ||
            product.offerToken != expectedGoogleOfferToken)) {
      messageCode = 'store_catalog_changed';
      notifyListeners();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _checkoutPreflightInFlight = true;
      notifyListeners();
      try {
        final reconciled = await _reconcileAppleUnfinishedBeforePurchase(
          product.id,
        );
        if (!reconciled ||
            _disposed ||
            Supabase.instance.client.auth.currentUser?.id != user.id) {
          return;
        }
        // Restore may refresh state and native catalog ownership. Re-read the
        // selected product before opening a new transaction.
        product = productFor(plan, term: term);
        if (product == null) {
          state = VerifiedStoreState.failed;
          messageCode = 'purchase_unavailable';
          notifyListeners();
          return;
        }
      } finally {
        _checkoutPreflightInFlight = false;
        if (!_disposed) notifyListeners();
      }
    }

    checkoutTrace = StorePurchaseTrace();
    final purchaseGeneration = _purchaseEventGeneration;
    state = VerifiedStoreState.purchasePending;
    messageCode = null;
    notifyListeners();
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      product = await _freshCheckoutProduct(
        product,
        ownerId: user.id,
        generation: purchaseGeneration,
      );
      if (product == null ||
          _disposed ||
          purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
    }
    final accountHash = storeAccountIdentifier(
      ownerId: user.id,
      platform: defaultTargetPlatform,
    );
    final PurchaseParam purchaseParam;
    if (defaultTargetPlatform == TargetPlatform.android &&
        product is GooglePlayProductDetails) {
      final previous = replacesGooglePurchase ?? _activeGooglePurchase;
      // Same-product checkout is not a cross-subscription replacement. Play
      // handles existing ownership; a replacement of itself is invalid.
      final previousPurchase = previous?.productID == product.id
          ? null
          : previous;
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
    _armPurchaseWatchdog(purchaseGeneration);
    try {
      _purchaseInitiatedByThisService = true;
      _purchaseInitiatedProductId = product.id;
      checkoutTrace?.mark(StorePurchaseStage.nativeLaunch);
      final started = await _purchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      checkoutTrace?.mark(StorePurchaseStage.nativeLaunchReturned);
      if (_disposed ||
          started ||
          purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_not_started';
      _clearPurchaseInitiation();
      notifyListeners();
    } on PlatformException catch (error) {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          error.code == 'storekit_duplicate_product_object') {
        _clearPurchaseInitiation();
        // StoreKit 2 refuses a second checkout while an older transaction for
        // this product is still unfinished. Reconcile that transaction instead
        // of leaving App Review at a generic purchase failure.
        state = products.isEmpty
            ? VerifiedStoreState.unavailable
            : VerifiedStoreState.ready;
        messageCode = 'purchase_reconciliation_pending';
        notifyListeners();
        final reconciled = await _reconcileAppleUnfinishedBeforePurchase(
          product.id,
        );
        if (!_disposed &&
            reconciled &&
            !_appleDuplicateRetryInFlight &&
            state != VerifiedStoreState.verified &&
            state != VerifiedStoreState.failed) {
          _appleDuplicateRetryInFlight = true;
          try {
            await purchasePlan(
              plan,
              term: term,
              replacesGooglePurchase: replacesGooglePurchase,
              downgradeAtRenewal: downgradeAtRenewal,
              expectedGoogleOfferToken: expectedGoogleOfferToken,
            );
          } finally {
            _appleDuplicateRetryInFlight = false;
          }
          return;
        }
        if (!_disposed &&
            state != VerifiedStoreState.verified &&
            state != VerifiedStoreState.failed) {
          state = VerifiedStoreState.failed;
          messageCode = 'reconciliation_verification_failed';
          notifyListeners();
        }
        return;
      }
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_status_unknown';
      notifyListeners();
    } on Object {
      if (_disposed || purchaseGeneration != _purchaseEventGeneration) return;
      state = VerifiedStoreState.failed;
      messageCode = 'purchase_status_unknown';
      notifyListeners();
    }
  }

  Future<void> purchaseBoost({String? offerToken}) =>
      _purchaseBoost(offerToken: offerToken);

  Future<void> refreshEntitlement() async {
    if (_disposed) return;
    final visit = _storeVisit.capture();
    final generation = ++_entitlementRefreshGeneration;
    final user = AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user == null) {
      _clearEntitlement();
      return;
    }
    if (_hasServerVerifiedInactiveMarker(user.id)) {
      // Do not let a read replica briefly restore paid access after a receipt
      // was already verified as expired, revoked, or refunded on the server.
      _clearEntitlement();
    }
    try {
      final rows = await Supabase.instance.client
          .from('bil_subscriptions')
          .select()
          .eq('owner_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (_disposed ||
          generation != _entitlementRefreshGeneration ||
          !_storeVisit.isCurrent(visit)) {
        return;
      }
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
      if (_entitlementOwnerId == user.id &&
          entitlement != null &&
          verifiedAt.isBefore(entitlement!.verifiedAt)) {
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
      final refreshedEntitlement = VerifiedStoreEntitlement(
        plan: plan,
        lifecycle: lifecycle,
        verifiedAt: verifiedAt,
        renewsOrExpiresAt: expiresAt,
        gracePeriodEndsAt: gracePeriodEndsAt,
        provider: provider,
      );
      if (_hasServerVerifiedInactiveMarker(user.id) &&
          refreshedEntitlement.grantsPaidAccess) {
        final inactiveAt = _serverVerifiedInactiveAt;
        if (inactiveAt == null ||
            !refreshedEntitlement.verifiedAt.isAfter(inactiveAt)) {
          // The verify response is newer and authoritative. Do not
          // momentarily unlock paid surfaces from an active row that has not
          // caught up yet.
          _clearEntitlement();
          return;
        }
        // A newer canonical verification is evidence of a real later active
        // subscription, not a replica of the inactive receipt's old row.
        _clearServerVerifiedInactiveOwner(user.id);
      }
      entitlement = refreshedEntitlement;
      _entitlementOwnerId = user.id;
    } on Object {
      // Never turn an unverifiable local label into paid access, but do not
      // erase a still-valid server-verified result for a transient failure.
      if (!_disposed &&
          generation == _entitlementRefreshGeneration &&
          _storeVisit.isCurrent(visit)) {
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _storeVisit.dispose();
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = null;
    _entitlementRefreshGeneration++;
    _clearEntitlement();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) _notificationZone.run(super.notifyListeners);
  }
}
