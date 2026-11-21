import '../../../shared/widgets/bil_page_heading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_state.dart';
import '../domain/market_offer_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../services/verified_store_catalog_adapter.dart';
import '../services/verified_store_purchase_service.dart';
import '../providers/commerce_providers.dart';
import '../providers/app_purchase_providers.dart';
import '../../intelligence_center/services/ai_boost_purchase_service.dart';
import 'bil_dynamic_store_offers.dart';
import 'bil_store_copy.dart';

part 'bil_store_plans_presentation.dart';

/// The production plan route. It no longer embeds legacy or synthetic prices.
class BilStorePlansPage extends ConsumerStatefulWidget {
  const BilStorePlansPage({
    super.key,
    this.store,
    this.catalog,
    this.connectToDeviceStore = true,
    this.productIds,
    this.initialFocus,
    this.openLegalUrl,
  });

  final VerifiedStorePurchaseService? store;
  final BilStoreCatalogGateway? catalog;
  final bool connectToDeviceStore;
  final Set<String>? productIds;
  final String? initialFocus;
  final Future<bool> Function(Uri)? openLegalUrl;

  @override
  ConsumerState<BilStorePlansPage> createState() => _BilStorePlansPageState();
}

class _BilStorePlansPageState extends ConsumerState<BilStorePlansPage>
    with WidgetsBindingObserver {
  VerifiedStorePurchaseService? _ownedStore;
  AiBoostPurchaseService? _sharedBoost;
  late final BilStoreCatalogGateway? _catalog;
  List<BilStoreOfferMetadata> _offers = const [];
  bool _loading = true;
  bool _loadInFlight = false;
  bool _restoring = false;
  bool _purchaseRequestInFlight = false;
  String? _purchaseFeedbackKey;
  bool _purchaseFeedbackIsError = false;
  VerifiedStoreState? _lastStoreState;
  String? _lastStoreMessage;
  int? _retriedPendingVisit;
  int? _requestedCheckoutVisit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.catalog != null) {
      _catalog = widget.catalog;
    } else if (widget.store != null) {
      _catalog = VerifiedStoreCatalogAdapter(widget.store!);
    } else if (widget.connectToDeviceStore) {
      _ownedStore = ref.read(appSubscriptionPurchaseProvider);
      final boost = ref.read(appBoostPurchaseProvider);
      boost.addListener(_onBoostChanged);
      _sharedBoost = boost;
      _catalog = VerifiedStoreCatalogAdapter(
        _ownedStore!,
        loadBoostCatalog: boost.initialize,
        boostProduct: () => boost.product,
        boostCheckout: (offer) async {
          await _sharedBoost!.initialize();
          await _sharedBoost!.purchaseBoost(
            expectedPrice: offer.localizedPrice,
            expectedCurrency: offer.currencyCode,
            expectedOfferToken: offer.purchaseOfferToken,
          );
        },
      );
    } else {
      _catalog = null;
    }
    (widget.store ?? _ownedStore)?.addListener(_onStoreChanged);
    _seedPendingPurchaseFeedback();
    _load();
  }

  void _seedPendingPurchaseFeedback() {
    final store = widget.store ?? _ownedStore;
    if (store != null &&
        (store.state == VerifiedStoreState.purchasePending ||
            const {
              'purchase_status_unknown',
              'verification_failed',
              'restore_verification_failed',
              'store_finish_pending',
              'purchase_owned_by_another_account',
            }.contains(store.messageCode))) {
      final feedback = _purchaseFeedbackFor(store);
      _purchaseFeedbackKey = feedback.$1;
      _purchaseFeedbackIsError = feedback.$2;
    }
    final boost = _sharedBoost;
    if (boost != null &&
        (boost.state == AiBoostPurchaseState.pending ||
            const {
              'purchase_status_unknown',
              'verification_failed',
              'store_finish_pending',
              'license_unlicensed',
              'play_license_recovered_pending',
            }.contains(boost.errorCode)) &&
        store?.messageCode != 'purchase_owned_by_another_account') {
      _onBoostChanged();
    }
    // Catalog initialization may intentionally emit no event for an existing
    // unresolved operation. Seed only actionable pending verification here;
    // historical reconciliation errors must not accuse a fresh Free visitor
    // of making a failed purchase merely by reopening Plans.
  }

  void _onBoostChanged() {
    if (!mounted || _sharedBoost == null) return;
    final boost = _sharedBoost!;
    if (!boost.hasUserInitiatedFeedback &&
        boost.errorCode != 'purchase_inactive' &&
        boost.errorCode != 'license_unlicensed' &&
        boost.errorCode != 'play_license_recovered_pending' &&
        !(boost.errorCode == 'store_finish_pending' &&
            boost.lastDelivery?.active == false)) {
      return;
    }
    setState(() {
      _purchaseFeedbackKey = switch (boost.presentationErrorCode) {
        'purchase_status_unknown' => 'purchase_confirmation_pending',
        'license_unlicensed' => 'license_unlicensed',
        'play_license_recovered' => 'play_license_recovered',
        'play_license_recovered_pending' => 'play_license_recovered_pending',
        'play_readiness_unavailable' => 'play_readiness_unavailable',
        'verification_failed' => 'purchase_verification_unavailable',
        'store_catalog_changed' => 'purchase_catalog_changed',
        'purchase_inactive' => 'purchase_inactive',
        'store_finish_pending' =>
          boost.lastDelivery?.active == false
              ? 'purchase_inactive'
              : 'purchase_verified',
        _ => switch (boost.state) {
          AiBoostPurchaseState.pending => 'purchase_in_progress',
          AiBoostPurchaseState.verified => 'purchase_verified',
          AiBoostPurchaseState.failed => 'purchase_error',
          _ => null,
        },
      };
      _purchaseFeedbackIsError =
          _purchaseFeedbackKey == 'purchase_error' ||
          boost.errorCode == 'verification_failed';
    });
    if (boost.errorCode == 'store_catalog_changed' && !_loadInFlight) {
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // StoreKit and Play Billing can become ready after account/store dialogs
    // or after returning from the background. Retry only an empty catalog;
    // verified prices already on screen remain untouched.
    if (state == AppLifecycleState.resumed && _offers.isEmpty) {
      unawaited(_load());
    }
  }

  void _onStoreChanged() {
    final store = widget.store ?? _ownedStore;
    if (store == null || !mounted) return;
    final verifiedTransition =
        store.state == VerifiedStoreState.verified &&
        _lastStoreState != VerifiedStoreState.verified;
    final settledRestore =
        store.messageCode == 'no_restorable_purchases' &&
        _lastStoreMessage != 'no_restorable_purchases';
    // An authentic inactive receipt is settled without a paid grant. Refresh
    // mounted surfaces immediately, not only after an active purchase. Empty
    // store history also uses this message: it triggers a read, never a local
    // revocation of an independently verified account entitlement.
    if (widget.store != null && (verifiedTransition || settledRestore)) {
      ref.invalidate(verifiedSubscriptionStateProvider);
      ref.invalidate(aiCoachCreditAccessProvider);
      ref
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
    }
    _lastStoreState = store.state;
    _lastStoreMessage = store.messageCode;
    _syncOwnershipConflict(store);
    if (store.messageCode == 'reconciliation_pending' ||
        store.messageCode == 'reconciliation_verification_failed') {
      // Do not replace an explicit operation's existing feedback, and do not
      // manufacture new feedback from a passive transaction replay.
      setState(() {});
      return;
    }
    final feedback = _purchaseFeedbackFor(store);
    setState(() {
      _purchaseFeedbackKey = feedback.$1;
      _purchaseFeedbackIsError = feedback.$2;
    });
  }

  void _syncOwnershipConflict(VerifiedStorePurchaseService store) {
    PurchaseOwnershipConflictStore conflict;
    try {
      conflict = ref.read(purchaseOwnershipConflictStoreProvider);
    } on StateError {
      // Isolated previews may intentionally render without ProviderScope.
      return;
    }
    if (store.messageCode == 'purchase_owned_by_another_account') {
      conflict.recordConflict(store.ownershipConflictProductId);
    } else if (const {
      'subscription_verified',
      'ai_boost_verified',
      'no_restorable_purchases',
    }.contains(store.messageCode)) {
      conflict.clearAfterVerifiedOwnership(store.lastVerifiedProductId);
    }
  }

  void _onOfferSelected(BilStoreOfferMetadata _) {
    // Choosing another term is not a new purchase attempt. Clear only
    // retryable launch/cancellation feedback so an old bottom-banner error
    // cannot follow the member between monthly and annual offers. A pending
    // operation and a receipt verification failure deliberately remain visible
    // and fail-closed until the native transaction is resolved or restored.
    final feedback = _purchaseFeedbackKey;
    if (!mounted ||
        _restoring ||
        (widget.store ?? _ownedStore)?.isRestoring == true ||
        feedback == null ||
        feedback == 'purchase_awaiting_approval' ||
        feedback == 'purchase_in_progress' ||
        feedback == 'purchase_verification_unavailable' ||
        feedback == 'purchase_confirmation_pending' ||
        feedback == 'purchase_reconciliation_pending' ||
        feedback == 'purchase_reconciliation_failed' ||
        feedback == 'purchase_owned_by_another_account' ||
        feedback == 'restore_verification_failed') {
      return;
    }
    setState(() {
      _purchaseFeedbackKey = null;
      _purchaseFeedbackIsError = false;
    });
  }

  bool get _purchaseInProgress =>
      _purchaseRequestInFlight ||
      ((widget.store ?? _ownedStore)?.userOperationInProgress == true &&
          (widget.store ?? _ownedStore)?.isRecoveringSubscription != true) ||
      _sharedBoost?.userOperationInProgress == true;

  Future<void> _load() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    if (mounted) setState(() => _loading = true);
    try {
      final catalog = _catalog;
      final productIds =
          widget.productIds ?? StoreCatalogConfiguration.storefrontProductIds;
      if (catalog == null || productIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      List<BilStoreOfferMetadata> offers;
      try {
        // Some device-store implementations never complete their product
        // query when Play Billing is unavailable (common on emulators and
        // offline devices). The plans surface must settle into its truthful
        // unavailable state instead of displaying an endless loading claim.
        offers = await catalog
            .loadOffers(productIds)
            .timeout(BilStoreCatalogGateway.loadTimeout);
      } on TimeoutException {
        offers = const [];
      } catch (_) {
        offers = const [];
      }
      // Canonicalize at the page boundary too. Malformed provider entries
      // must leave the catalog retryable on the next tap or app resume.
      offers = MarketOfferPolicy.visibleOffers(offers);
      if (mounted) {
        setState(() {
          _offers = offers;
          _loading = false;
        });
      }
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _restorePurchases() async {
    final catalog = _catalog;
    final store = widget.store ?? _ownedStore;
    if (catalog == null || _restoring || store?.busy == true) return;
    setState(() {
      _restoring = true;
      _purchaseFeedbackKey = 'restore_checking';
      _purchaseFeedbackIsError = false;
    });
    var messageKey = 'restore_checked';
    try {
      final operation = catalog.restorePurchases();
      try {
        await operation.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        if (store?.isRestoring != true) rethrow;
        // The page's observation deadline cannot declare a still-running
        // native restore failed. Await this same operation; the service owns
        // its existing bounded deadline, owner fences and late callbacks.
        // Never invoke restore again or start a purchase here.
        await operation;
      }
      if (store != null) _syncOwnershipConflict(store);
      messageKey = switch (store?.messageCode) {
        'subscription_verified' => 'restore_verified',
        'no_restorable_purchases' => 'restore_none',
        'restore_cancelled' => 'restore_cancelled',
        'restore_unconfirmed' => 'restore_unconfirmed',
        'authentication_required' => 'restore_sign_in',
        'restore_failed' => 'restore_failed',
        'purchase_status_unknown' => 'purchase_confirmation_pending',
        'store_finish_pending' => 'purchase_verification_unavailable',
        'purchase_owned_by_another_account' =>
          'purchase_owned_by_another_account',
        'restore_verification_failed' ||
        'verification_failed' ||
        'reconciliation_verification_failed' => 'restore_verification_failed',
        _ when store?.state == VerifiedStoreState.failed => 'restore_failed',
        _ => 'restore_checked',
      };
    } on TimeoutException {
      messageKey = 'restore_timeout';
    } catch (_) {
      messageKey = 'restore_failed';
    }
    if (!mounted) return;
    setState(() {
      _restoring = false;
      // The routine completed check already has its existing SnackBar below.
      // Keep unresolved/verified transaction outcomes persistent, without
      // duplicating this transient acknowledgement above the purchase CTA.
      _purchaseFeedbackKey = messageKey == 'restore_checked'
          ? null
          : messageKey;
      _purchaseFeedbackIsError = const {
        'restore_failed',
        'restore_timeout',
        'restore_verification_failed',
        'purchase_owned_by_another_account',
      }.contains(messageKey);
    });
    final locale = Localizations.localeOf(context).toLanguageTag();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_purchaseFeedbackText(locale, messageKey))),
      );
  }

  Future<void> _requestPurchase(BilStoreOfferMetadata offer) async {
    final catalog = _catalog;
    final store = widget.store ?? _ownedStore;
    var ownershipBlocked = false;
    var subscriptionBlocked = false;
    try {
      ownershipBlocked = ref
          .read(purchaseOwnershipConflictStoreProvider)
          .blockedFor(offer.kind);
      if (offer.kind != BilStoreProductKind.aiBoostConsumable) {
        final plan = _verifiedPlan(
          ref.read(verifiedSubscriptionAccessProvider),
        );
        subscriptionBlocked =
            plan == null ||
            plan ==
                (offer.kind == BilStoreProductKind.premiumSubscription
                    ? CommercePlan.premium
                    : CommercePlan.premiumAiCoach);
      }
    } on StateError {
      // Production is always mounted below ProviderScope. Preview-only pages
      // have no authenticated owner state to retain.
    }
    if (catalog == null ||
        ownershipBlocked ||
        subscriptionBlocked ||
        _purchaseRequestInFlight ||
        store?.busy == true) {
      return;
    }
    setState(() {
      _purchaseRequestInFlight = true;
      _purchaseFeedbackKey = 'purchase_in_progress';
      _purchaseFeedbackIsError = false;
    });
    try {
      await catalog.requestPurchase(offer);
    } on Object {
      if (mounted) {
        setState(() {
          _purchaseFeedbackKey = 'purchase_error';
          _purchaseFeedbackIsError = true;
        });
      }
    } finally {
      if (mounted && store?.messageCode == 'store_catalog_changed') {
        await _load();
      }
      if (mounted) {
        setState(() {
          _purchaseRequestInFlight = false;
          // Injected preview/test catalogs have no native purchase stream.
          // Their completed callback must not leave a fictional pending sale.
          if (store == null && _purchaseFeedbackKey == 'purchase_in_progress') {
            _purchaseFeedbackKey = null;
          }
        });
      }
    }
  }

  void _explainBlockedPurchase(BilStoreOfferMetadata offer) {
    final store = widget.store ?? _ownedStore;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final copy = AppLocalizations(Localizations.localeOf(context));
    AsyncValue<SubscriptionState>? account;
    if (offer.kind != BilStoreProductKind.aiBoostConsumable) {
      try {
        account = ref.read(verifiedSubscriptionAccessProvider);
      } on StateError {
        // Isolated previews may intentionally render without ProviderScope.
      }
    }
    final unresolved =
        _sharedBoost?.canRetry == true ||
        store != null &&
            (store.busy ||
                store.verificationBackedOff ||
                const {
                  'reconciliation_verification_failed',
                  'verification_failed',
                  'restore_verification_failed',
                  'purchase_status_unknown',
                  'store_finish_pending',
                }.contains(store.messageCode));
    final ownershipBlocked =
        store?.ownershipConflictProductId == offer.productId;
    if (!ownershipBlocked && !unresolved && account?.isLoading == true) {
      final visit = ref.read(verifiedEntitlementOwnerVisitProvider);
      setState(() => _requestedCheckoutVisit = visit);
    }
    final message = ownershipBlocked
        ? BilStoreCopy.text(locale, 'purchase_owned_by_another_account')
        : unresolved
        ? BilStoreCopy.text(locale, 'purchase_reconciliation_failed')
        : copy.text(
            account?.isLoading == true
                ? 'Checking subscription'
                : 'Subscription check unavailable',
          );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: store?.canRecoverSubscriptionBlocker == true
              ? SnackBarAction(
                  label: BilStoreCopy.text(locale, 'continue_verification'),
                  onPressed: () =>
                      unawaited(store!.recoverSubscriptionBlocker()),
                )
              : !ownershipBlocked &&
                    !unresolved &&
                    account != null &&
                    !account.isLoading &&
                    _verifiedPlan(account) == null
              ? SnackBarAction(
                  label: copy.text('Try again'),
                  onPressed: () {
                    if (mounted) {
                      ref.invalidate(verifiedSubscriptionStateProvider);
                    }
                  },
                )
              : null,
        ),
      );
  }

  void _retrySlowRead(int generation, int visit) {
    if (_retriedPendingVisit == visit ||
        ref.read(verifiedEntitlementOwnerVisitProvider) != visit ||
        ref.read(verifiedSubscriptionReadWitnessProvider).generation !=
            generation ||
        !ref.read(verifiedSubscriptionAccessProvider).isLoading) {
      return;
    }
    // A manual recheck never enters the catalog or purchase service.
    setState(() {
      _requestedCheckoutVisit = visit;
      _retriedPendingVisit = visit;
    });
    ref.invalidate(verifiedSubscriptionStateProvider);
  }

  CommercePlan? _verifiedPlan(AsyncValue<SubscriptionState> snapshot) {
    final state = snapshot.asData?.value;
    return state?.authority == EntitlementAuthority.verifiedServer
        ? state!.plan
        : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    (widget.store ?? _ownedStore)?.removeListener(_onStoreChanged);
    _sharedBoost?.removeListener(_onBoostChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final pageBackground = scheme.brightness == Brightness.dark
        ? scheme.surface
        : Colors.white;
    final pageForeground = scheme.brightness == Brightness.dark
        ? scheme.onSurface
        : const Color(0xFF171717);
    // Only a completed server decision may name a current plan. Catalog
    // readiness says nothing about the signed-in account's existing access.
    AsyncValue<SubscriptionState>? accountAccess;
    CommercePlan? currentPlan;
    CommercePlan? authoritativePlan;
    var refreshingKnownFree = false;
    (int, int)? slowRead;
    try {
      final access = ref.watch(verifiedSubscriptionPresentationProvider);
      accountAccess = access;
      currentPlan = _verifiedPlan(access);
      final authority = ref.watch(verifiedSubscriptionAccessProvider);
      authoritativePlan = _verifiedPlan(authority);
      refreshingKnownFree =
          currentPlan == CommercePlan.free && authority.isLoading;
      if (!authority.isLoading) {
        _retriedPendingVisit = null;
        _requestedCheckoutVisit = null;
      } else if ((currentPlan == null || currentPlan == CommercePlan.free) &&
          ref.watch(verifiedEntitlementOwnerIdProvider) != null) {
        final generation = ref
            .read(verifiedSubscriptionReadWitnessProvider)
            .generation;
        final visit = ref.watch(verifiedEntitlementOwnerVisitProvider);
        final overdue = ref.watch(_plansReadDeadline(generation)).asData?.value;
        if (overdue == true && _requestedCheckoutVisit == visit) {
          slowRead = (generation, visit);
        }
      }
    } on StateError {
      // Standalone previews have no account authority or native checkout.
      currentPlan = CommercePlan.free;
      authoritativePlan = CommercePlan.free;
    }
    final store = widget.store ?? _ownedStore;
    PurchaseOwnershipConflictStore? ownershipConflict;
    try {
      ownershipConflict = ref.watch(purchaseOwnershipConflictStoreProvider);
    } on StateError {
      ownershipConflict = null;
    }
    final blockedPurchaseKinds =
        ownershipConflict?.blockedKinds ?? const <BilStoreProductKind>{};
    final purchaseFeedbackKey =
        _purchaseFeedbackKey == 'purchase_owned_by_another_account'
        ? null
        : _purchaseFeedbackKey;
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: pageForeground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _leavePlans,
          icon: const Icon(Icons.close_rounded),
        ),
        centerTitle: true,
        title: Text(
          BilStoreCopy.text(locale, 'plans'),
          style: bilPageHeadingStyle(context, color: pageForeground),
        ),
      ),
      body: Column(
        children: [
          if (slowRead != null)
            _slowAccessStatus(slowRead.$1, slowRead.$2)
          else if (accountAccess?.isLoading == true &&
              currentPlan == null &&
              ref.watch(verifiedEntitlementOwnerIdProvider) != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('store-request-account-refresh'),
                onPressed:
                    _retriedPendingVisit ==
                        ref.watch(verifiedEntitlementOwnerVisitProvider)
                    ? null
                    : () => _retrySlowRead(
                        ref
                            .read(verifiedSubscriptionReadWitnessProvider)
                            .generation,
                        ref.read(verifiedEntitlementOwnerVisitProvider),
                      ),
                child: Text(
                  AppLocalizations(
                    Localizations.localeOf(context),
                  ).text('Refresh access'),
                ),
              ),
            )
          else if (accountAccess != null &&
              currentPlan != CommercePlan.free &&
              (!accountAccess.isLoading || currentPlan != null))
            _accountAccessStatus(
              locale: locale,
              access: accountAccess,
              plan: currentPlan,
            ),
          Expanded(
            child: BilDynamicStoreOffers(
              locale: locale,
              offers: _offers,
              loading: _loading,
              purchaseInProgress: _purchaseInProgress,
              restoreInProgress:
                  _restoring || store?.isRecoveringSubscription == true,
              refreshingKnownFree:
                  refreshingKnownFree && (store?.canStartPurchase ?? true),
              purchaseEnabled:
                  authoritativePlan != null &&
                  (store?.canStartPurchase ?? true),
              purchaseAllowedForKind: (kind) =>
                  kind == BilStoreProductKind.aiBoostConsumable &&
                      _sharedBoost != null
                  ? _sharedBoost!.canPurchase
                  : (kind == BilStoreProductKind.aiBoostConsumable ||
                            authoritativePlan != null) &&
                        (store?.canStartPurchase ?? true),
              onContinueVerification:
                  (_sharedBoost?.canRecoverPlayLicense == true ||
                      _sharedBoost?.canRetry == true ||
                      (store != null &&
                          !store.busy &&
                          (store.hasPendingVerifiedFinish ||
                              const {
                                'purchase_status_unknown',
                                'store_finish_pending',
                              }.contains(store.messageCode))))
                  ? () async {
                      if (_sharedBoost?.canRecoverPlayLicense == true) {
                        await _sharedBoost!.recoverPlayLicense();
                      } else if (_sharedBoost?.canRetry == true) {
                        await _sharedBoost!.retryPendingTransaction();
                      } else {
                        await store!.continueVerification();
                      }
                    }
                  : null,
              continueVerificationLabel: BilStoreCopy.text(
                locale,
                _sharedBoost?.canRecoverPlayLicense == true
                    ? 'fix_play_license'
                    : 'continue_verification',
              ),
              blockedPurchaseKinds: blockedPurchaseKinds,
              blockedPurchaseMessage: BilStoreCopy.text(
                locale,
                'purchase_owned_by_another_account',
              ),
              purchaseStatusMessage: purchaseFeedbackKey == null
                  ? null
                  : _purchaseFeedbackText(locale, purchaseFeedbackKey),
              purchaseStatusIsError:
                  blockedPurchaseKinds.isNotEmpty || _purchaseFeedbackIsError,
              currentPlan: currentPlan,
              initialFocus: widget.initialFocus,
              initialSelectedProductId: _ownedActiveProductHint(
                store,
                currentPlan,
              ),
              onPurchaseRequested: _requestPurchase,
              onBlockedPurchaseRequested: _explainBlockedPurchase,
              onOfferSelected: _onOfferSelected,
              onRestore: _catalog == null ? null : _restorePurchases,
              onManage: _catalog == null
                  ? null
                  : () => _catalog.openManageSubscriptions(),
              onRetry: _catalog == null || _loading ? null : _load,
              onTerms: StoreCatalogConfiguration.legalLinksConfigured
                  ? () => unawaited(
                      _openLegalLink(StoreCatalogConfiguration.termsUrl),
                    )
                  : null,
              onPrivacy: StoreCatalogConfiguration.legalLinksConfigured
                  ? () => unawaited(
                      _openLegalLink(StoreCatalogConfiguration.privacyUrl),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
