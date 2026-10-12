import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Catalog implements BilStoreCatalogGateway {
  int purchases = 0;
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> ids) async =>
      const [
        BilStoreOfferMetadata(
          productId: 'bil_premium',
          kind: BilStoreProductKind.premiumSubscription,
          localizedTitle: 'Premium',
          localizedPrice: '2.49',
          currencyCode: 'USD',
          priceMicros: 2490000,
          billingPeriodIso8601: 'P1M',
        ),
      ];
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    purchases++;
  }

  @override
  Future<void> restorePurchases() async {}
  @override
  Future<void> openManageSubscriptions() async {}
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'actual Plans legal links work at 320/2x $language $brightness',
        (tester) async {
          expect(
            StoreCatalogConfiguration.legalLinksConfigured,
            isTrue,
            reason:
                'use the approved HTTPS fixture defines, as owner Full does',
          );
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          WidgetController.hitTestWarningShouldBeFatal = true;
          addTearDown(
            () => WidgetController.hitTestWarningShouldBeFatal = false,
          );
          final opened = <Uri>[];
          final catalog = _Catalog();
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: BilStorePlansPage(
                  catalog: catalog,
                  connectToDeviceStore: false,
                  openLegalUrl: (uri) async {
                    opened.add(uri);
                    return true;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final key in ['store-terms-link', 'store-privacy-link']) {
            final button = find.byKey(Key(key));
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final bounds = tester.getRect(button);
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(button.hitTestable(), findsOneWidget);
            await tester.tap(button);
            await tester.pump();
          }
          expect(opened, [
            Uri.parse(StoreCatalogConfiguration.termsUrl),
            Uri.parse(StoreCatalogConfiguration.privacyUrl),
          ]);
          expect(opened.every((uri) => uri.scheme == 'https'), isTrue);
          expect(catalog.purchases, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
