import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/commerce_plan.dart';
import '../domain/market_offer_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../services/verified_store_catalog_adapter.dart';
import '../services/verified_store_purchase_service.dart';
import '../providers/commerce_providers.dart';
import 'bil_dynamic_store_offers.dart';
import 'bil_store_copy.dart';

/// The production plan route. It no longer embeds legacy or synthetic prices.
class BilStorePlansPage extends ConsumerStatefulWidget {
  const BilStorePlansPage({
    super.key,
    this.store,
    this.catalog,
    this.connectToDeviceStore = true,
    this.productIds,
    this.initialFocus,
  });

  final VerifiedStorePurchaseService? store;
  final BilStoreCatalogGateway? catalog;
  final bool connectToDeviceStore;
  final Set<String>? productIds;
  final String? initialFocus;

  @override
  ConsumerState<BilStorePlansPage> createState() => _BilStorePlansPageState();
}

class _BilStorePlansPageState extends ConsumerState<BilStorePlansPage>
    with WidgetsBindingObserver {
  VerifiedStorePurchaseService? _ownedStore;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.catalog != null) {
      _catalog = widget.catalog;
    } else if (widget.store != null) {
      _catalog = VerifiedStoreCatalogAdapter(widget.store!);
    } else if (widget.connectToDeviceStore) {
      _ownedStore = VerifiedStorePurchaseService();
      _catalog = VerifiedStoreCatalogAdapter(_ownedStore!);
    } else {
      _catalog = null;
    }
    (widget.store ?? _ownedStore)?.addListener(_onStoreChanged);
    _load();
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
    if (verifiedTransition || settledRestore) {
      ref.invalidate(verifiedSubscriptionStateProvider);
      ref.invalidate(aiCoachCreditAccessProvider);
      ref
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
    }
    _lastStoreState = store.state;
    _lastStoreMessage = store.messageCode;
    final feedback = _purchaseFeedbackFor(store);
    setState(() {
      _purchaseFeedbackKey = feedback.$1;
      _purchaseFeedbackIsError = feedback.$2;
    });
  }

  void _onOfferSelected(BilStoreOfferMetadata _) {
    // Choosing another term is not a new purchase attempt. Clear only
    // retryable launch/cancellation feedback so an old bottom-banner error
    // cannot follow the member between monthly and annual offers. A pending
    // operation and a receipt verification failure deliberately remain visible
    // and fail-closed until the native transaction is resolved or restored.
    final feedback = _purchaseFeedbackKey;
    if (!mounted ||
        feedback == null ||
        feedback == 'purchase_awaiting_approval' ||
        feedback == 'purchase_in_progress' ||
        feedback == 'purchase_verification_unavailable' ||
        feedback == 'purchase_reconciliation_pending' ||
        feedback == 'purchase_reconciliation_failed' ||
        feedback == 'restore_verification_failed') {
      return;
    }
    setState(() {
      _purchaseFeedbackKey = null;
      _purchaseFeedbackIsError = false;
    });
  }

  (String?, bool) _purchaseFeedbackFor(VerifiedStorePurchaseService store) {
    final code = store.messageCode;
    final key = switch (code) {
      'purchase_pending' => 'purchase_awaiting_approval',
      'restore_pending' => 'restore_checking',
      'reconciliation_pending' => 'purchase_reconciliation_pending',
      // Cancelling the native sheet is an intentional choice, not an error.
      // Keep the catalog actionable so another term can be selected at once.
      'purchase_cancelled' => null,
      'purchase_not_started' => 'purchase_error',
      'store_catalog_changed' => 'purchase_catalog_changed',
      'store_catalog_refresh_failed' => 'purchase_error',
      'purchase_unavailable' || 'authentication_required' => 'purchase_error',
      'verification_failed' => 'purchase_verification_unavailable',
      'restore_verification_failed' => 'restore_verification_failed',
      'reconciliation_verification_failed' => 'purchase_reconciliation_failed',
      'purchase_failed' || 'store_stream_failed' => 'purchase_error',
      'subscription_verified' || 'ai_boost_verified' => 'purchase_verified',
      _ => switch (store.state) {
        VerifiedStoreState.purchasePending => 'purchase_in_progress',
        VerifiedStoreState.cancelled => null,
        VerifiedStoreState.failed => 'purchase_error',
        _ => null,
      },
    };
    final isError = const {
      'purchase_error',
      'restore_verification_failed',
      'purchase_reconciliation_failed',
    }.contains(key);
    return (key, isError);
  }

  bool get _purchaseInProgress =>
      _purchaseRequestInFlight || (widget.store ?? _ownedStore)?.busy == true;

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
            .timeout(const Duration(seconds: 12));
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
    if (catalog == null || _restoring) return;
    setState(() => _restoring = true);
    var messageKey = 'restore_checked';
    try {
      await catalog.restorePurchases().timeout(const Duration(seconds: 20));
      final store = widget.store ?? _ownedStore;
      messageKey = switch (store?.messageCode) {
        'subscription_verified' => 'restore_verified',
        'no_restorable_purchases' => 'restore_none',
        'authentication_required' => 'restore_sign_in',
        'restore_failed' => 'restore_failed',
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
    setState(() => _restoring = false);
    final locale = Localizations.localeOf(context).toLanguageTag();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(BilStoreCopy.text(locale, messageKey))),
      );
  }

  Future<void> _requestPurchase(BilStoreOfferMetadata offer) async {
    final catalog = _catalog;
    final store = widget.store ?? _ownedStore;
    if (catalog == null || _purchaseRequestInFlight || store?.busy == true) {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    (widget.store ?? _ownedStore)?.removeListener(_onStoreChanged);
    _ownedStore?.dispose();
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
    // Production is mounted below ProviderScope. Keeping this preview-safe
    // fallback also lets isolated visual and localization tests render it.
    var currentPlan = CommercePlan.free;
    try {
      currentPlan =
          ref.watch(verifiedSubscriptionAccessProvider).value?.plan ??
          CommercePlan.free;
    } on StateError {
      currentPlan = CommercePlan.free;
    }
    final store = widget.store ?? _ownedStore;
    final purchaseFeedbackKey = _purchaseFeedbackKey;
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: pageForeground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.close_rounded),
        ),
        centerTitle: true,
        title: Text(
          BilStoreCopy.text(locale, 'plans'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: pageForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BilDynamicStoreOffers(
        locale: locale,
        offers: _offers,
        loading: _loading,
        purchaseInProgress: _purchaseInProgress,
        restoreInProgress: _restoring,
        purchaseEnabled: store?.canStartPurchase ?? true,
        purchaseStatusMessage: purchaseFeedbackKey == null
            ? null
            : BilStoreCopy.text(locale, purchaseFeedbackKey),
        purchaseStatusIsError: _purchaseFeedbackIsError,
        currentPlan: currentPlan,
        initialFocus: widget.initialFocus,
        onPurchaseRequested: _requestPurchase,
        onOfferSelected: _onOfferSelected,
        onRestore: _catalog == null ? null : _restorePurchases,
        onManage: _catalog == null
            ? null
            : () => _catalog.openManageSubscriptions(),
        onRetry: _catalog == null || _loading ? null : _load,
      ),
    );
  }
}
