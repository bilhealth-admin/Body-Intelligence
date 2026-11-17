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
import 'store_verification_request_policy.dart';
import 'store_subscription_blocker_recovery.dart';
import 'store_native_purchase_completion.dart';
import '../domain/store_benefit_delivery.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/storefront_market_policy.dart';
import '../domain/subscription_term.dart';
import '../domain/subscription_state.dart';
import '../repositories/server_entitlement_repository.dart'
    show ServerEntitlementRepository, isAcceptableServerVerificationTimestamp;

part 'verified_store_purchase_support.dart';
part 'verified_store_purchase_processing.dart';
part 'verified_store_receipt_verification.dart';
part 'verified_store_purchase_checkout.dart';
part 'verified_store_purchase_restore.dart';
part 'verified_store_restore_diagnostics.dart';
part 'verified_store_purchase_owned.dart';
part 'verified_store_purchase_pending.dart';
part 'verified_store_subscription_recovery.dart';
part 'verified_store_purchase_completion.dart';
part 'verified_store_purchase_initialization.dart';

class VerifiedStorePurchaseService extends ChangeNotifier {
  VerifiedStorePurchaseService({
    InAppPurchase? purchase,
    this._appleStoreSync,
    this._subscriptionInventoryReader,
    this._freshRecoveryEntitlementReader,
    this.pendingTimeout = const Duration(seconds: 90),
    this.handlesBoost = true,
  }) : _purchaseInstance = purchase;

  InAppPurchase? _purchaseInstance;
  final Future<void> Function()? _appleStoreSync;
  final StoreSubscriptionInventoryReader? _subscriptionInventoryReader;
  final Future<SubscriptionState> Function()? _freshRecoveryEntitlementReader;
  bool _subscriptionRecoveryInFlight = false;
  String? _failedSubscriptionProductId;
  final Map<String, PurchaseDetails> _unresolvedVerificationReceipts = {};
  bool _unresolvedReceiptOverflow = false;
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
  // Ephemeral catalog metadata only; never stored with the account or ads.
  String? _catalogStoreCountryCode;
  String? get catalogStoreCountryCode => _catalogStoreCountryCode;
  StoreAccountSnapshot captureCatalogVisit() => _storeVisit.capture();
  bool isCurrentCatalogVisit(StoreAccountSnapshot visit) =>
      !_disposed && _storeVisit.isCurrent(visit);
  Future<String?> readStorefrontCountry() async {
    try {
      return StorefrontMarketPolicy.normalizeCountry(
        await _purchase.countryCode().timeout(const Duration(seconds: 4)),
      );
    } on Object {
      return null;
    }
  }

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
  _StoreRestoreAttempt? _restoreAttempt;
  String? get restoreSupportCode => _currentRestoreSupportCode();
  bool _checkoutPreflightInFlight = false;
  bool _disposed = false;
  int _entitlementRefreshGeneration = 0;
  bool _purchaseInitiatedByThisService = false;
  String? _purchaseInitiatedProductId;
  Timer? _purchaseWatchdog;
  bool _storeStartupFaultBeforeCatalog = false;
  ({StoreAccountSnapshot visit, int generation, int benefitRevision})?
  _settledInactiveCatalogRecovery;
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
    StoreVerificationRequestPolicy.shared.resetForTesting();
  }

  bool get configured => AppEnvironment.commerceConfigured;
  bool get hasPendingVerifiedFinish => _pendingVerifiedFinishes.isNotEmpty;
  bool get isRestoring => _restoring;
  bool get isRecoveringSubscription => _subscriptionRecoveryInFlight;
  bool get busy =>
      _restoring ||
      _subscriptionRecoveryInFlight ||
      _checkoutPreflightInFlight ||
      _queuedPurchaseUpdates > 0 ||
      state == VerifiedStoreState.purchasePending;

  /// Busy includes the background receipt lane for duplicate-charge safety.
  /// Only an explicit checkout/restore may animate purchase progress in UI.
  bool get userOperationInProgress =>
      _restoring ||
      _subscriptionRecoveryInFlight ||
      _checkoutPreflightInFlight ||
      (_purchaseInitiatedByThisService &&
          messageCode != 'purchase_status_unknown') ||
      (state == VerifiedStoreState.purchasePending &&
          messageCode != 'reconciliation_pending');
  bool get verificationBackedOff =>
      StoreVerificationRequestPolicy.shared.isBackedOff(_currentStoreOwnerId());
  bool get canStartPurchase =>
      !busy &&
      !verificationBackedOff &&
      _unresolvedVerificationReceipts.isEmpty &&
      !_unresolvedReceiptOverflow &&
      _nativeRestoreOperation == null &&
      canStartStorePurchase(
        state: state,
        productAvailable: products.isNotEmpty,
        messageCode: messageCode,
      );

  bool _restoreCatalogAfterSettledInactiveReceipt() {
    final settled = _settledInactiveCatalogRecovery;
    if (settled == null ||
        _disposed ||
        products.isEmpty ||
        state != VerifiedStoreState.unavailable ||
        messageCode != 'no_restorable_purchases' ||
        hasPendingVerifiedFinish ||
        settled.generation != _purchaseEventGeneration ||
        settled.benefitRevision != verifiedBenefitRevision ||
        !_storeVisit.isCurrent(settled.visit)) {
      return false;
    }
    _settledInactiveCatalogRecovery = null;
    state = VerifiedStoreState.ready;
    return true;
  }

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
    String? expectedStoreCountryCode,
  }) async {
    // The button and service both guard this boundary. Keeping the service
    // idempotent prevents a second UI event from overwriting the truthful
    // pending state while the native sheet is opening.
    if (_disposed ||
        busy ||
        _nativeRestoreOperation != null ||
        _unresolvedVerificationReceipts.isNotEmpty ||
        _unresolvedReceiptOverflow) {
      return;
    }
    if (const {
      'purchase_status_unknown',
      'store_finish_pending',
      'purchase_owned_by_another_account',
    }.contains(messageCode)) {
      return;
    }
    if (verificationBackedOff) {
      state = VerifiedStoreState.failed;
      messageCode = 'verification_failed';
      notifyListeners();
      return;
    }
    final checkoutVisit = _storeVisit.capture();
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
            !isCurrentCatalogVisit(checkoutVisit) ||
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
        expectedStoreCountryCode: expectedStoreCountryCode,
      );
      if (product == null ||
          _disposed ||
          purchaseGeneration != _purchaseEventGeneration) {
        return;
      }
    }
    if (verificationBackedOff ||
        _unresolvedVerificationReceipts.isNotEmpty ||
        _unresolvedReceiptOverflow) {
      state = VerifiedStoreState.failed;
      messageCode = 'verification_failed';
      notifyListeners();
      return;
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
              expectedStoreCountryCode: expectedStoreCountryCode,
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
    _clearRestoreDiagnostic();
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
    if (!_restoring && messageCode != 'restore_failed') {
      _clearRestoreDiagnostic();
    }
    if (!_disposed) _notificationZone.run(super.notifyListeners);
  }
}
