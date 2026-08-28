import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/market_offer_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

BilStoreOfferMetadata offer(BilStoreProductKind kind, String id) =>
    BilStoreOfferMetadata(
      productId: id,
      kind: kind,
      localizedTitle: id,
      localizedPrice: r'$9.99',
      currencyCode: 'USD',
      priceMicros: 9990000,
    );

void main() {
  test('commercial floors match the approved loss boundary', () {
    expect(MarketOfferPolicy.monthlyProfitFloorUsd, 6);
    expect(MarketOfferPolicy.annualProfitFloorUsd, 35);
  });

  test(
    'storefront exposes Premium AI Coach and Boost in profitable market',
    () {
      final visible = MarketOfferPolicy.visibleOffers([
        offer(BilStoreProductKind.premiumAiCoachSubscription, 'coach-monthly'),
        offer(BilStoreProductKind.aiBoostConsumable, 'bil_ai_boost'),
      ]);
      expect(
        MarketOfferPolicy.targetPlanForKinds(visible.map((item) => item.kind)),
        CommercePlan.premiumAiCoach,
      );
      expect(visible.map((item) => item.productId), [
        'coach-monthly',
        'bil_ai_boost',
      ]);
    },
  );

  test('mixed console catalog fails safe to Premium and hides AI Coach', () {
    final visible = MarketOfferPolicy.visibleOffers([
      offer(BilStoreProductKind.premiumSubscription, 'premium-monthly'),
      offer(BilStoreProductKind.premiumAiCoachSubscription, 'coach-monthly'),
      offer(BilStoreProductKind.aiBoostConsumable, 'bil_ai_boost'),
    ]);
    expect(
      MarketOfferPolicy.targetPlanForKinds(visible.map((item) => item.kind)),
      CommercePlan.premium,
    );
    expect(visible.map((item) => item.productId), [
      'premium-monthly',
      'bil_ai_boost',
    ]);
  });

  test('server verifies billing storefront and blocks market mismatch', () {
    final backend = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260821102504_commerce_country_policy_and_ai_allowances.sql',
    ).readAsStringSync();
    expect(backend, contains('data.regionCode'));
    expect(backend, contains('payload.storefront'));
    expect(backend, contains('p_store_country_code'));
    expect(migration, contains("raise exception 'market_plan_mismatch'"));
    expect(migration, contains("'EG','ER','ET'"));
    expect(migration, contains("'US','UY','VA'"));
  });

  test('ads are requested only through the verified free-user gate', () {
    final policy = File(
      'lib/features/ads/domain/ad_policy.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/ads/providers/ad_providers.dart',
    ).readAsStringSync();
    expect(policy, contains('subscription.plan != CommercePlan.free'));
    expect(policy, contains('AdSuppressionReason.paidSubscription'));
    expect(providers, contains('verifiedSubscriptionStateProvider'));
  });
}
