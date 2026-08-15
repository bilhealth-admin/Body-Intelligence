import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three-plan offer is honest, live-priced and store-authoritative', () {
    final offer = File(
      'lib/features/commerce/presentation/glass_store_offer.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/features/commerce/domain/plan_policy.dart',
    ).readAsStringSync();
    final paidCatalog = File(
      'lib/features/commerce/domain/paid_plan_catalog.dart',
    ).readAsStringSync();
    final store = File(
      'lib/features/commerce/services/verified_store_purchase_service.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(offer, contains("CommercePlan.free => const ["));
    expect(offer, contains("CommercePlan.pro => const ["));
    expect(offer, contains('CommercePlan.plus'));
    expect(offer, contains('premiumPlusReady'));
    expect(offer, contains("'premiumPlusRequired'"));
    expect(offer, contains("const Key('paywall-premium-plus-preview')"));
    expect(offer, contains("context.push('/meal-planner')"));
    expect(router, contains("path: '/meal-planner'"));
    expect(offer, contains("'annualSavingDetail'"));
    expect(offer, contains('annual.rawPrice / (monthly.rawPrice * 12)'));
    expect(offer, isNot(contains('SAVE 30%')));
    expect(offer, isNot(contains('وفّر 30%')));
    expect(offer, contains("'startAnnual'"));
    expect(offer, contains("'startMonthly'"));
    expect(offer, contains("const Key('paywall-manage')"));
    expect(offer, contains('store!.purchasePlan('));
    expect(offer, contains('store!.restore'));
    expect(offer, contains('store!.manageSubscription('));
    expect(offer, isNot(contains("'insights': 'Advanced nutrition")));
    expect(offer, isNot(contains("'logging': 'Fast barcode")));

    expect(policy, contains('exposure: StoreExposure.consumerSubscription'));
    expect(paidCatalog, contains('CommerceEntitlement.cloudSync'));
    expect(paidCatalog, contains('CommerceEntitlement.advancedIntelligence'));
    expect(store, contains("'verify-store-purchase'"));
    expect(store, contains("data['entitlement_active'] == true"));
    expect(providers, isNot(contains('GoogleClosedTestAccess')));
    expect(providers, contains('ServerEntitlementRepository().current()'));
    expect(
      File(
        'lib/features/commerce/domain/store_catalog_configuration.dart',
      ).readAsStringSync(),
      contains('static const premiumPlusMealPlannerReady = false'),
    );
    expect(
      File(
        'lib/features/commerce/domain/google_closed_test_access.dart',
      ).existsSync(),
      isFalse,
    );
  });
}
