import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _captureKey = ValueKey('app-store-review-capture');

const _premiumMonthly = BilStoreOfferMetadata(
  productId: 'bil_premium',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'BIL Premium Monthly',
  localizedPrice: 'EGP 129.99',
  currencyCode: 'EGP',
  priceMicros: 129990000,
  storeCountryCode: 'EGY',
  billingPeriodIso8601: 'P1M',
);

const _premiumAnnual = BilStoreOfferMetadata(
  productId: 'bil_premium_annual',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'BIL Premium Annual',
  localizedPrice: 'EGP 999.99',
  currencyCode: 'EGP',
  priceMicros: 999990000,
  storeCountryCode: 'EGY',
  billingPeriodIso8601: 'P1Y',
);

const _aiCoachMonthly = BilStoreOfferMetadata(
  productId: 'bil_premium_ai_coach',
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'BIL Premium + AI Coach Monthly',
  localizedPrice: r'$5.99',
  currencyCode: 'USD',
  priceMicros: 5990000,
  storeCountryCode: 'USA',
  billingPeriodIso8601: 'P1M',
);

const _aiCoachAnnual = BilStoreOfferMetadata(
  productId: 'bil_premium_ai_coach_annual',
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'BIL Premium + AI Coach Annual',
  localizedPrice: r'$49.99',
  currencyCode: 'USD',
  priceMicros: 49990000,
  storeCountryCode: 'USA',
  billingPeriodIso8601: 'P1Y',
);

const _aiBoost = BilStoreOfferMetadata(
  productId: 'bil_ai_boost',
  kind: BilStoreProductKind.aiBoostConsumable,
  localizedTitle: 'BIL AI Boost — 2,500 Tokens',
  localizedPrice: r'$2.49',
  currencyCode: 'USD',
  priceMicros: 2490000,
  storeCountryCode: 'USA',
);

final class _ReviewCatalog implements BilStoreCatalogGateway {
  const _ReviewCatalog(this.offers);

  final List<BilStoreOfferMetadata> offers;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds) async {
    return offers
        .where((offer) => productIds.contains(offer.productId))
        .toList(growable: false);
  }

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {}

  @override
  Future<void> restorePurchases() async {}
}

final class _ReviewScenario {
  const _ReviewScenario({
    required this.productId,
    required this.localizedPrice,
    required this.offers,
    required this.expectedCurrencyCode,
    required this.expectedStoreCountryCode,
    this.annualProductId,
    this.expectedAnnualSavingsLabel,
    this.focusBoost = false,
  });

  final String productId;
  final String localizedPrice;
  final List<BilStoreOfferMetadata> offers;
  final String expectedCurrencyCode;
  final String expectedStoreCountryCode;
  final String? annualProductId;
  final String? expectedAnnualSavingsLabel;
  final bool focusBoost;
}

Future<void> _loadAppStoreReviewFonts() async {
  await loadVisualEvidenceFont();
  final displayFont = File(
    '${Directory.current.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}fonts${Platform.pathSeparator}'
    'Montserrat-Bold.ttf',
  );
  if (!displayFont.existsSync()) {
    throw StateError('BILDisplay font was not found at ${displayFont.path}.');
  }
  await (FontLoader('BILDisplay')..addFont(
        displayFont.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      ))
      .load();
}

void main() {
  setUpAll(_loadAppStoreReviewFonts);

  const scenarios = <_ReviewScenario>[
    _ReviewScenario(
      productId: 'bil_premium',
      localizedPrice: 'EGP 129.99',
      expectedCurrencyCode: 'EGP',
      expectedStoreCountryCode: 'EGY',
      annualProductId: 'bil_premium_annual',
      offers: [_premiumMonthly, _premiumAnnual, _aiBoost],
    ),
    _ReviewScenario(
      productId: 'bil_premium_annual',
      localizedPrice: 'EGP 999.99',
      expectedCurrencyCode: 'EGP',
      expectedStoreCountryCode: 'EGY',
      annualProductId: 'bil_premium_annual',
      expectedAnnualSavingsLabel: 'Save 36%',
      offers: [_premiumMonthly, _premiumAnnual, _aiBoost],
    ),
    _ReviewScenario(
      productId: 'bil_premium_ai_coach',
      localizedPrice: r'$5.99',
      expectedCurrencyCode: 'USD',
      expectedStoreCountryCode: 'USA',
      annualProductId: 'bil_premium_ai_coach_annual',
      offers: [_aiCoachMonthly, _aiCoachAnnual, _aiBoost],
    ),
    _ReviewScenario(
      productId: 'bil_premium_ai_coach_annual',
      localizedPrice: r'$49.99',
      expectedCurrencyCode: 'USD',
      expectedStoreCountryCode: 'USA',
      annualProductId: 'bil_premium_ai_coach_annual',
      expectedAnnualSavingsLabel: 'Save 30%',
      offers: [_aiCoachMonthly, _aiCoachAnnual, _aiBoost],
    ),
    _ReviewScenario(
      productId: 'bil_ai_boost',
      localizedPrice: r'$2.49',
      expectedCurrencyCode: 'USD',
      expectedStoreCountryCode: 'USA',
      focusBoost: true,
      offers: [_premiumMonthly, _premiumAnnual, _aiBoost],
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets('App Store review screenshot selects ${scenario.productId}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme = visualEvidenceTheme(
        BilFlagshipTheme.light(isArabic: false),
        fontFamily: 'RobotoEvidence',
      );
      final catalog = _ReviewCatalog(scenario.offers);
      final selectedMetadata = scenario.offers.singleWhere(
        (offer) => offer.productId == scenario.productId,
      );
      expect(selectedMetadata.currencyCode, scenario.expectedCurrencyCode);
      expect(
        selectedMetadata.storeCountryCode,
        scenario.expectedStoreCountryCode,
      );
      if (scenario.productId == 'bil_premium' ||
          scenario.productId == 'bil_premium_annual') {
        expect(
          selectedMetadata.currencyCode,
          isNot('USD'),
          reason: 'Premium is unavailable in USA and must use a live market.',
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en', 'US'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: theme,
            builder: (context, child) =>
                visualEvidenceTextSurface(child, fontFamily: 'RobotoEvidence'),
            home: RepaintBoundary(
              key: _captureKey,
              child: BilStorePlansPage(
                catalog: catalog,
                connectToDeviceStore: false,
                productIds: scenario.offers
                    .map((offer) => offer.productId)
                    .toSet(),
                initialFocus: scenario.focusBoost ? 'boost' : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();

      final selectedCard = find.byKey(
        ValueKey('store-offer-${scenario.productId}'),
      );
      expect(selectedCard, findsOneWidget);
      await tester.ensureVisible(selectedCard);
      await tester.tap(selectedCard);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: selectedCard,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
        reason: '${scenario.productId} must be the selected review product.',
      );

      final annualProductId = scenario.annualProductId;
      if (annualProductId != null && annualProductId != scenario.productId) {
        final annualCard = find.byKey(ValueKey('store-offer-$annualProductId'));
        expect(
          find.descendant(
            of: annualCard,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsNothing,
          reason: 'A monthly review image must never select Annual.',
        );
      }

      final annualBadge = find.byKey(
        ValueKey('annual-savings-${scenario.productId}'),
      );
      if (scenario.expectedAnnualSavingsLabel != null) {
        expect(annualBadge, findsOneWidget);
        expect(
          find.descendant(
            of: annualBadge,
            matching: find.text(scenario.expectedAnnualSavingsLabel!),
          ),
          findsOneWidget,
        );
      } else {
        expect(annualBadge, findsNothing);
      }

      if (scenario.productId == 'bil_ai_boost') {
        // A plain App Store consumable has no verified original-price offer.
        // Never fabricate a 50% badge without store-supplied offer metadata.
        expect(
          find.byKey(const ValueKey('ai-boost-discount-badge-bil_ai_boost')),
          findsNothing,
        );
      }

      final purchaseCta = find.byKey(const ValueKey('store-purchase-cta'));
      expect(purchaseCta, findsOneWidget);
      expect(
        find.descendant(
          of: purchaseCta,
          matching: find.textContaining(scenario.localizedPrice),
        ),
        findsOneWidget,
        reason: 'The CTA must match the selected StoreKit product price.',
      );
      expect(tester.takeException(), isNull);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        await expectLater(
          image,
          matchesGoldenFile(
            'goldens/app_store_review/v1.0/${scenario.productId}.png',
          ),
        );
      } finally {
        image.dispose();
      }
    });
  }
}
