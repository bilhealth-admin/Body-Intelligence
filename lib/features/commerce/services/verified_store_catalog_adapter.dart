import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import 'verified_store_purchase_service.dart';

/// Adapts the existing verified store transport to provider-neutral UI
/// metadata. It cannot grant access; receipt verification remains server-side.
final class VerifiedStoreCatalogAdapter implements BilStoreCatalogGateway {
  VerifiedStoreCatalogAdapter(this.store);

  final VerifiedStorePurchaseService store;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds) async {
    if (store.products.isEmpty) await store.initialize();
    return store.products.values
        .where((product) => productIds.contains(product.id))
        .map((product) {
          final binding = StoreCatalogConfiguration.bindingForProduct(
            product.id,
          );
          if (binding == null) return null;
          return BilStoreOfferMetadata(
            productId: product.id,
            kind: binding.plan == CommercePlan.plus
                ? BilStoreProductKind.premiumAiCoachSubscription
                : BilStoreProductKind.premiumSubscription,
            localizedTitle: product.title,
            localizedPrice: product.price,
            currencyCode: product.currencyCode,
            priceMicros: (product.rawPrice * 1000000).round(),
            billingPeriodIso8601: switch (binding.term.months) {
              1 => 'P1M',
              12 => 'P1Y',
              _ => null,
            },
          );
        })
        .whereType<BilStoreOfferMetadata>()
        .toList(growable: false);
  }

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    final binding = StoreCatalogConfiguration.bindingForProduct(
      offer.productId,
    );
    if (binding == null) return;
    await store.purchasePlan(binding.plan, term: binding.term);
  }

  @override
  Future<void> restorePurchases() => store.restore();

  @override
  Future<void> openManageSubscriptions() => store.manageSubscription();
}
