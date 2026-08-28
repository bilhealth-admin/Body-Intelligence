import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  test('reads only explicit eligible Play half-price offer metadata', () {
    const base = OneTimePurchaseOfferDetailsWrapper(
      formattedPrice: r'$5.00',
      priceAmountMicros: 5000000,
      priceCurrencyCode: 'USD',
    );
    const discount = _ExplicitOneTimeDiscountOffer(
      formattedPrice: r'$2.50',
      priceAmountMicros: 2500000,
      priceCurrencyCode: 'USD',
      fullPriceMicros: 5000000,
      percentageDiscount: 50,
      offerId: 'launch-half-price',
      offerToken: 'opaque-play-offer-token',
    );
    const wrapper = ProductDetailsWrapper(
      description: '2,500 AI tokens',
      name: 'BIL AI Boost',
      productId: StoreCatalogConfiguration.aiBoost,
      productType: ProductType.inapp,
      title: 'BIL AI Boost',
      oneTimePurchaseOfferDetails: base,
      oneTimePurchaseOfferDetailsList: [base, discount],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    final metadata = googlePlayOneTimeDiscountMetadata(product);

    expect(metadata, isNotNull);
    expect(metadata!.localizedPrice, r'$2.50');
    expect(metadata.localizedOriginalPrice, r'$5.00');
    expect(metadata.priceMicros, 2500000);
    expect(metadata.originalPriceMicros, 5000000);
    expect(metadata.savingsPercent, 50);
    expect(metadata.offerId, 'launch-half-price');
    expect(metadata.offerToken, 'opaque-play-offer-token');
    final purchaseParam = verifiedBoostPurchaseParam(
      product: product,
      accountHash: 'opaque-account-hash',
      platform: TargetPlatform.android,
      offerToken: metadata.offerToken,
    );
    expect(purchaseParam, isA<GooglePlayPurchaseParam>());
    expect(
      (purchaseParam as GooglePlayPurchaseParam).offerToken,
      'opaque-play-offer-token',
    );
  });

  test('does not infer a discount from a normal Play price', () {
    const regular = OneTimePurchaseOfferDetailsWrapper(
      formattedPrice: r'$2.50',
      priceAmountMicros: 2500000,
      priceCurrencyCode: 'USD',
    );
    const wrapper = ProductDetailsWrapper(
      description: '2,500 AI tokens',
      name: 'BIL AI Boost',
      productId: StoreCatalogConfiguration.aiBoost,
      productType: ProductType.inapp,
      title: 'BIL AI Boost',
      oneTimePurchaseOfferDetails: regular,
      oneTimePurchaseOfferDetailsList: [regular],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(googlePlayOneTimeDiscountMetadata(product), isNull);
  });

  test('does not infer 50% from two prices without explicit offer fields', () {
    const base = OneTimePurchaseOfferDetailsWrapper(
      formattedPrice: r'$5.00',
      priceAmountMicros: 5000000,
      priceCurrencyCode: 'USD',
    );
    const lowerPrice = OneTimePurchaseOfferDetailsWrapper(
      formattedPrice: r'$2.50',
      priceAmountMicros: 2500000,
      priceCurrencyCode: 'USD',
    );
    const wrapper = ProductDetailsWrapper(
      description: '2,500 AI tokens',
      name: 'BIL AI Boost',
      productId: StoreCatalogConfiguration.aiBoost,
      productType: ProductType.inapp,
      title: 'BIL AI Boost',
      oneTimePurchaseOfferDetails: base,
      oneTimePurchaseOfferDetailsList: [base, lowerPrice],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(googlePlayOneTimeDiscountMetadata(product), isNull);
  });

  testWidgets('shows crossed original price and 50% only for a real offer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const offer = BilStoreOfferMetadata(
      productId: StoreCatalogConfiguration.aiBoost,
      kind: BilStoreProductKind.aiBoostConsumable,
      localizedTitle: 'BIL AI Boost',
      localizedPrice: r'$2.50',
      localizedOriginalPrice: r'$5.00',
      currencyCode: 'USD',
      priceMicros: 2500000,
      originalPriceMicros: 5000000,
      savingsPercent: 50,
      offerId: 'launch-half-price',
      purchaseOfferToken: 'opaque-play-offer-token',
    );

    await _pumpStore(tester, offer);

    final badge = find.byKey(
      const ValueKey('ai-boost-discount-badge-bil_ai_boost'),
    );
    final originalPrice = find.byKey(
      const ValueKey('ai-boost-original-price-bil_ai_boost'),
    );
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.textContaining('50%')),
      findsOneWidget,
    );
    expect(originalPrice, findsOneWidget);
    expect(
      tester.widget<Text>(originalPrice).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(find.textContaining(r'$2.50'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal 2.50 store price shows no discount claim', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const offer = BilStoreOfferMetadata(
      productId: StoreCatalogConfiguration.aiBoost,
      kind: BilStoreProductKind.aiBoostConsumable,
      localizedTitle: 'BIL AI Boost',
      localizedPrice: r'$2.50',
      currencyCode: 'USD',
      priceMicros: 2500000,
    );

    await _pumpStore(tester, offer);

    expect(
      find.byKey(const ValueKey('ai-boost-discount-badge-bil_ai_boost')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('ai-boost-original-price-bil_ai_boost')),
      findsNothing,
    );
    expect(find.textContaining('50%'), findsNothing);
    expect(find.textContaining(r'$2.50'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpStore(
  WidgetTester tester,
  BilStoreOfferMetadata offer,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BilDynamicStoreOffers(
          locale: 'ar',
          offers: [offer],
          initialFocus: 'boost',
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ExplicitOneTimeDiscountOffer
    extends OneTimePurchaseOfferDetailsWrapper {
  const _ExplicitOneTimeDiscountOffer({
    required super.formattedPrice,
    required super.priceAmountMicros,
    required super.priceCurrencyCode,
    required this.fullPriceMicros,
    required this.percentageDiscount,
    required this.offerId,
    required this.offerToken,
  });

  final int fullPriceMicros;
  final int percentageDiscount;
  final String offerId;
  final String offerToken;

  _ExplicitOneTimeDiscountOffer get discountDisplayInfo => this;
}
