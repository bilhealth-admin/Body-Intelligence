import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'feature labels remain meaningful in all25 release locales without changing prices or rights',
    () {
      for (final locale in BilLocaleRolloutManifest.releaseTargets25) {
        expect(
          BilStoreCopy.text(locale, 'premium_benefit_personal_plan'),
          isNot('premium_benefit_personal_plan'),
        );
        final label = BilStoreCopy.text(locale, 'ai_benefit_vision');
        expect(label, startsWith('BIL Vision · '));
        expect(label, isNot(contains('unlimited')));
      }
    },
  );
  testWidgets(
    'actual expanded Plans lists Personal plan and Vision without triggering purchase',
    (t) async {
      var buys = 0;
      const offer = BilStoreOfferMetadata(
        productId: 'synthetic.ai.monthly',
        kind: BilStoreProductKind.premiumAiCoachSubscription,
        localizedTitle: 'Monthly',
        localizedPrice: 'JOD4.250',
        currencyCode: 'JOD',
        priceMicros: 4250000,
        billingPeriodIso8601: 'P1M',
      );
      await t.pumpWidget(
        MaterialApp(
          home: BilDynamicStoreOffers(
            locale: 'en',
            offers: const [offer],
            onPurchaseRequested: (_) => buys++,
            onRestore: () {},
            onManage: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      // The public feature expansion action, not a purchase CTA.
      final expand = find.byKey(
        const ValueKey('store-benefits-toggle-premiumAiCoachSubscription'),
      );
      expect(expand, findsOneWidget);
      await t.ensureVisible(expand);
      await t.tap(expand);
      await t.pumpAndSettle();
      expect(
        find.text(BilStoreCopy.text('en', 'premium_benefit_personal_plan')),
        findsWidgets,
      );
      expect(
        find.text(BilStoreCopy.text('en', 'ai_benefit_vision')),
        findsWidgets,
      );
      expect(buys, 0);
      expect(t.takeException(), isNull);
    },
  );
}
