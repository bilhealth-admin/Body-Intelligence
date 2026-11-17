import 'dart:io';
import 'package:body_intelligence_log/features/commerce/domain/market_offer_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<BilStoreOfferMetadata> _catalog(String? country) => [
  for (final id in StoreCatalogConfiguration.storefrontProductIds)
    BilStoreOfferMetadata(
      productId: id,
      kind: id == StoreCatalogConfiguration.aiBoost
          ? BilStoreProductKind.aiBoostConsumable
          : StoreCatalogConfiguration.aiTrialProductIds.contains(id)
          ? BilStoreProductKind.premiumAiCoachSubscription
          : BilStoreProductKind.premiumSubscription,
      localizedTitle: id,
      localizedPrice: 'USD 9.99',
      currencyCode: 'USD',
      priceMicros: 9990000,
      storeCountryCode: country,
      billingPeriodIso8601: id == StoreCatalogConfiguration.aiBoost
          ? null
          : id.endsWith('_annual')
          ? 'P1Y'
          : 'P1M',
    ),
];

Set<String> _visible(String? country) => MarketOfferPolicy.visibleOffers(
  _catalog(country),
).map((offer) => offer.productId).toSet();

const _premium = {
  StoreCatalogConfiguration.premiumMonthly,
  StoreCatalogConfiguration.premiumAnnual,
  StoreCatalogConfiguration.aiBoost,
};
const _ai = {
  StoreCatalogConfiguration.premiumAiCoachMonthly,
  StoreCatalogConfiguration.premiumAiCoachAnnual,
  StoreCatalogConfiguration.aiBoost,
};

void main() {
  test('actual JO/JOR metadata chooses AI from a mixed native catalog', () {
    for (final raw in ['JO', 'JOR', ' jo ', 'jor']) {
      expect(_visible(raw), _ai, reason: raw);
    }
  });

  test('the four approved markets choose Premium in ISO2 and ISO3', () {
    for (final raw in ['EG', 'EGY', 'NG', 'NGA', 'PK', 'PAK', 'TR', 'TUR']) {
      expect(_visible(raw), _premium, reason: raw);
    }
    expect(_visible('IN'), _ai);
    expect(_visible('IND'), _ai);
  });

  test('all approved v4 sale aliases exercise the real offer policy', () {
    final sql = File(
      'supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql',
    ).readAsStringSync();
    final blocks = RegExp(
      r'from unnest\(array\[(.*?)\]::text\[\]\) code',
      dotAll: true,
    ).allMatches(sql).toList();
    final ai2 = RegExp(
      r"'([A-Z]{2})'",
    ).allMatches(blocks[1].group(1)!).map((m) => m.group(1)!).toSet();
    final functions = RegExp(
      r"if v_code = any\(array\[(.*?)\]::text\[\]\) then\s*return '([^']+)';",
      dotAll: true,
    ).allMatches(sql);
    final aiBlock = functions
        .singleWhere((m) => m.group(2) == 'premium_ai_coach')
        .group(1)!;
    final ai3 = RegExp(
      r"'([A-Z]{3})'",
    ).allMatches(aiBlock).map((m) => m.group(1)!).toSet();
    expect(ai2, hasLength(168));
    expect(ai3, hasLength(168));
    expect(ai2.intersection({'EG', 'NG', 'PK', 'TR'}), isEmpty);
    for (final raw in {...ai2, ...ai3}) {
      expect(_visible(raw), _ai, reason: raw);
    }
  });

  test('held markets hide subscriptions while retaining valid Boost', () {
    for (final raw in ['BY', 'BLR', 'CN', 'CHN', 'RU', 'RUS']) {
      expect(_visible(raw), {StoreCatalogConfiguration.aiBoost}, reason: raw);
    }
  });

  test('unknown mixed catalog retains the original conservative fallback', () {
    for (final raw in <String?>[null, '', 'ZZ', 'ZZZ', 'not-a-country']) {
      expect(_visible(raw), _premium, reason: raw);
    }
  });

  test('mixed query snapshots cannot promote a subscription', () {
    final offers = [..._catalog('JOR'), ..._catalog('EGY')];
    final visible = MarketOfferPolicy.visibleOffers(offers);
    expect(
      visible.every((o) => o.kind == BilStoreProductKind.aiBoostConsumable),
      isTrue,
    );
    expect(visible.map((o) => o.productId).toSet(), {
      StoreCatalogConfiguration.aiBoost,
    });
  });

  test(
    'invalid Boost stays invalid and valid price objects remain unchanged',
    () {
      final source = _catalog('JOR');
      final visible = MarketOfferPolicy.visibleOffers(source);
      for (final offer in visible) {
        expect(source, contains(same(offer)));
        expect(offer.localizedPrice, 'USD 9.99');
        expect(offer.priceMicros, 9990000);
      }
      expect(
        MarketOfferPolicy.visibleOffers([
          BilStoreOfferMetadata(
            productId: StoreCatalogConfiguration.aiBoost,
            kind: BilStoreProductKind.aiBoostConsumable,
            localizedTitle: '',
            localizedPrice: '',
            currencyCode: '',
            priceMicros: -1,
            storeCountryCode: 'JOR',
          ),
        ]),
        isEmpty,
      );
    },
  );

  testWidgets('actual purchase widget displays only the JOR annual AI CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    BilStoreOfferMetadata? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: _catalog('JOR'),
          onPurchaseRequested: (offer) => requested = offer,
          onRestore: null,
          onManage: null,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('store-tier-premiumSubscription')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('store-tier-premiumAiCoachSubscription')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));
    await tester.pump();
    expect(
      requested?.productId,
      StoreCatalogConfiguration.premiumAiCoachAnnual,
    );
    expect(requested?.storeCountryCode, 'JOR');
  });
}
