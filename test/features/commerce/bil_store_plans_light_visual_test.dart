import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'Plans light reference ${locale.languageCode} 390x844 at 160%',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: visualEvidenceTheme(
              ThemeData(),
              fontFamily: locale.languageCode == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
            builder: (context, child) => visualEvidenceTextSurface(
              MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              fontFamily: locale.languageCode == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
            home: BilStorePlansPage(
              catalog: _PlansVisualCatalog(),
              productIds: const {'premium.monthly', 'premium.annual'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('store-purchase-cta')),
          findsOneWidget,
        );
        expect(find.textContaining('EGP'), findsWidgets);
        expect(
          find.text(locale.languageCode == 'ar' ? 'وفّر 36%' : 'Save 36%'),
          findsOneWidget,
        );
        await expectLater(
          find.byType(BilStorePlansPage),
          matchesGoldenFile(
            'goldens/plans_light_${locale.languageCode}_390x844_160.png',
          ),
        );
      },
    );
  }
}

final class _PlansVisualCatalog implements BilStoreCatalogGateway {
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => const [
    BilStoreOfferMetadata(
      productId: 'premium.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'EGP 129.99',
      currencyCode: 'EGP',
      priceMicros: 129990000,
      storeCountryCode: 'EGY',
      billingPeriodIso8601: 'P1M',
    ),
    BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'EGP 999.99',
      currencyCode: 'EGP',
      priceMicros: 999990000,
      storeCountryCode: 'EGY',
      billingPeriodIso8601: 'P1Y',
      trialPeriodIso8601: 'P1W',
      trialEligible: true,
    ),
  ];

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {}

  @override
  Future<void> restorePurchases() async {}
}
