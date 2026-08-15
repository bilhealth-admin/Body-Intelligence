import 'package:flutter/material.dart';

import '../domain/store_offer_metadata.dart';
import 'bil_store_copy.dart';

/// Store-driven offer surface for the final tier vocabulary.
/// Prices/promotions come only from device-store metadata. A tap requests a
/// purchase but never grants entitlement locally.
class BilDynamicStoreOffers extends StatelessWidget {
  const BilDynamicStoreOffers({
    required this.locale,
    required this.offers,
    required this.onPurchaseRequested,
    required this.onRestore,
    required this.onManage,
    this.loading = false,
    super.key,
  });

  final String locale;
  final List<BilStoreOfferMetadata> offers;
  final ValueChanged<BilStoreOfferMetadata> onPurchaseRequested;
  final VoidCallback? onRestore;
  final VoidCallback? onManage;
  final bool loading;

  String _copy(String key) => BilStoreCopy.text(locale, key);

  @override
  Widget build(BuildContext context) {
    final grouped = <BilStoreProductKind, List<BilStoreOfferMetadata>>{};
    for (final offer in offers.where((offer) => offer.valid)) {
      grouped.putIfAbsent(offer.kind, () => []).add(offer);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FreeTierCard(label: _copy('free')),
        const SizedBox(height: 12),
        for (final kind in BilStoreProductKind.values) ...[
          _StoreTierCard(
            title: _copy(switch (kind) {
              BilStoreProductKind.premiumSubscription => 'premium',
              BilStoreProductKind.premiumAiCoachSubscription =>
                'premium_ai_coach',
              BilStoreProductKind.aiBoostConsumable => 'ai_boost',
            }),
            offers: grouped[kind] ?? const [],
            loadingLabel: _copy('store_loading'),
            unavailableLabel: _copy('store_unavailable'),
            monthlyLabel: _copy('monthly'),
            annualLabel: _copy('annual'),
            trialLabel: _copy('trial'),
            loading: loading,
            onPurchaseRequested: onPurchaseRequested,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(onPressed: onRestore, child: Text(_copy('restore'))),
        TextButton(onPressed: onManage, child: Text(_copy('manage'))),
      ],
    );
  }
}

class _FreeTierCard extends StatelessWidget {
  const _FreeTierCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.check_circle_outline_rounded),
      title: Text(label),
      trailing: const Icon(Icons.check_rounded),
    ),
  );
}

class _StoreTierCard extends StatelessWidget {
  const _StoreTierCard({
    required this.title,
    required this.offers,
    required this.loadingLabel,
    required this.unavailableLabel,
    required this.monthlyLabel,
    required this.annualLabel,
    required this.trialLabel,
    required this.loading,
    required this.onPurchaseRequested,
  });

  final String title;
  final List<BilStoreOfferMetadata> offers;
  final String loadingLabel;
  final String unavailableLabel;
  final String monthlyLabel;
  final String annualLabel;
  final String trialLabel;
  final bool loading;
  final ValueChanged<BilStoreOfferMetadata> onPurchaseRequested;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (offers.isEmpty)
            Text(
              loading ? loadingLabel : unavailableLabel,
              key: ValueKey('store-placeholder-$title'),
            )
          else
            for (final offer in offers)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  key: ValueKey('store-offer-${offer.productId}'),
                  onPressed: loading ? null : () => onPurchaseRequested(offer),
                  child: Text(_offerLabel(offer)),
                ),
              ),
        ],
      ),
    ),
  );

  String _offerLabel(BilStoreOfferMetadata offer) {
    final term = switch (offer.billingPeriodIso8601) {
      'P1M' => ' | $monthlyLabel',
      'P1Y' => ' | $annualLabel',
      _ => '',
    };
    final trial =
        offer.trialEligible == true && offer.trialPeriodIso8601 != null
        ? ' | $trialLabel'
        : '';
    return '${offer.localizedTitle} | ${offer.localizedPrice}$term$trial';
  }
}
