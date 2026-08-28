import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
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
        expect(find.textContaining(r'$'), findsWidgets);
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
      localizedPrice: r'$5.99 / EGP 299',
      currencyCode: 'USD',
      priceMicros: 5990000,
      billingPeriodIso8601: 'P1M',
    ),
    BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: r'$34.99 / EGP 1,749',
      currencyCode: 'USD',
      priceMicros: 34990000,
      billingPeriodIso8601: 'P1Y',
      savingsPercent: 51,
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
