import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/commerce_plan.dart';
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

class _BilStorePlansPageState extends ConsumerState<BilStorePlansPage> {
  VerifiedStorePurchaseService? _ownedStore;
  late final BilStoreCatalogGateway? _catalog;
  List<BilStoreOfferMetadata> _offers = const [];
  bool _loading = true;
  bool _restoring = false;
  VerifiedStoreState? _lastStoreState;

  @override
  void initState() {
    super.initState();
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

  void _onStoreChanged() {
    final store = widget.store ?? _ownedStore;
    if (store == null || !mounted) return;
    if (store.state == VerifiedStoreState.verified &&
        _lastStoreState != VerifiedStoreState.verified) {
      ref.invalidate(verifiedSubscriptionStateProvider);
      ref.invalidate(aiCoachCreditAccessProvider);
    }
    _lastStoreState = store.state;
    setState(() {});
  }

  Future<void> _load() async {
    final catalog = _catalog;
    final productIds =
        widget.productIds ?? StoreCatalogConfiguration.storefrontProductIds;
    if (catalog == null || productIds.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    List<BilStoreOfferMetadata> offers;
    try {
      // Some device-store implementations never complete their product query
      // when Play Billing is unavailable (common on emulators and offline
      // devices). The plans surface must settle into its truthful unavailable
      // state instead of displaying an endless loading claim.
      offers = await catalog
          .loadOffers(productIds)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      offers = const [];
    } catch (_) {
      offers = const [];
    }
    if (mounted) {
      setState(() {
        _offers = offers;
        _loading = false;
      });
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

  @override
  void dispose() {
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
          ref.watch(verifiedSubscriptionStateProvider).value?.plan ??
          CommercePlan.free;
    } on StateError {
      currentPlan = CommercePlan.free;
    }
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
        restoreInProgress: _restoring,
        currentPlan: currentPlan,
        initialFocus: widget.initialFocus,
        onPurchaseRequested: (offer) async {
          await _catalog?.requestPurchase(offer);
          if (mounted) setState(() {});
        },
        onRestore: _catalog == null ? null : _restorePurchases,
        onManage: _catalog == null
            ? null
            : () => _catalog.openManageSubscriptions(),
      ),
    );
  }
}
