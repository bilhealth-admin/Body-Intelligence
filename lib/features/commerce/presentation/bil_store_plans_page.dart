import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../services/verified_store_catalog_adapter.dart';
import '../services/verified_store_purchase_service.dart';
import 'bil_dynamic_store_offers.dart';

/// The production plan route. It no longer embeds legacy or synthetic prices.
class BilStorePlansPage extends StatefulWidget {
  const BilStorePlansPage({
    super.key,
    this.store,
    this.catalog,
    this.connectToDeviceStore = true,
    this.productIds,
  });

  final VerifiedStorePurchaseService? store;
  final BilStoreCatalogGateway? catalog;
  final bool connectToDeviceStore;
  final Set<String>? productIds;

  @override
  State<BilStorePlansPage> createState() => _BilStorePlansPageState();
}

class _BilStorePlansPageState extends State<BilStorePlansPage> {
  VerifiedStorePurchaseService? _ownedStore;
  late final BilStoreCatalogGateway? _catalog;
  List<BilStoreOfferMetadata> _offers = const [];
  bool _loading = true;

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
    _load();
  }

  Future<void> _load() async {
    final catalog = _catalog;
    final productIds =
        widget.productIds ?? StoreCatalogConfiguration.productIds;
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

  @override
  void dispose() {
    _ownedStore?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('BODY INTELLIGENCE LOG™'),
      ),
    ),
    body: BilDynamicStoreOffers(
      locale: Localizations.localeOf(context).toLanguageTag(),
      offers: _offers,
      loading: _loading,
      onPurchaseRequested: (offer) async {
        await _catalog?.requestPurchase(offer);
        if (mounted) setState(() {});
      },
      onRestore: _catalog == null ? null : () => _catalog.restorePurchases(),
      onManage: _catalog == null
          ? null
          : () => _catalog.openManageSubscriptions(),
    ),
  );
}
