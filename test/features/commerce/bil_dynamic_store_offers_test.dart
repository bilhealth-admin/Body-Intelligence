import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dark theme keeps the full purchase path on dark surfaces', (
    tester,
  ) async {
    const monthly = BilStoreOfferMetadata(
      productId: 'premium.dark.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'USD 5.00',
      currencyCode: 'USD',
      priceMicros: 5000000,
      billingPeriodIso8601: 'P1M',
    );
    const annual = BilStoreOfferMetadata(
      productId: 'premium.dark.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'USD 42.00',
      currencyCode: 'USD',
      priceMicros: 42000000,
      billingPeriodIso8601: 'P1Y',
    );
    final theme = ThemeData.dark(useMaterial3: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [monthly, annual],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    final scheme = theme.colorScheme;
    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('store-offers-background')),
    );
    expect((background.decoration as BoxDecoration).color, scheme.surface);

    final freeCard = tester.widget<Container>(
      find.byKey(const ValueKey('store-free-tier-card')),
    );
    expect(
      (freeCard.decoration! as BoxDecoration).color,
      scheme.surfaceContainerLow,
    );

    final premiumCard = tester.widget<Container>(
      find.byKey(const ValueKey('store-tier-premiumSubscription')),
    );
    expect(
      (premiumCard.decoration! as BoxDecoration).color,
      scheme.surfaceContainerLow,
    );

    final boostCard = tester.widget<Container>(
      find.byKey(const ValueKey('store-tier-aiBoostConsumable')),
    );
    final boostGradient =
        (boostCard.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(boostGradient.colors, isNot(contains(Colors.white)));

    final monthlySurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('store-offer-surface-premium.dark.monthly')),
    );
    expect(
      (monthlySurface.decoration! as BoxDecoration).color,
      scheme.surfaceContainerHighest,
    );

    final selectedAnnual = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('store-offer-surface-premium.dark.annual')),
    );
    final selectedGradient =
        (selectedAnnual.decoration! as BoxDecoration).gradient!
            as LinearGradient;
    expect(selectedGradient.colors, isNot(contains(Colors.white)));

    final sticky = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('store-sticky-purchase-bar')),
    );
    expect(
      (sticky.decoration as BoxDecoration).color,
      scheme.surface.withValues(alpha: .98),
    );

    final monthlyPrice = tester.widget<Text>(
      find.byKey(const ValueKey('store-offer-price-premium.dark.monthly')),
    );
    expect(monthlyPrice.style?.color, scheme.onSurface);
  });

  testWidgets('does not invent prices when store metadata is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsNothing);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(2));
    expect(find.text('Loading price from the store…'), findsNothing);
    expect(find.text('Scan food barcode'), findsOneWidget);
    expect(find.text('Macro and nutrient trends'), findsOneWidget);
    expect(find.text('1,500 recipes'), findsOneWidget);
    expect(find.text('Food, water and weight tracking'), findsOneWidget);
    expect(find.text('Core nutrition insights'), findsOneWidget);
    expect(find.text('Local progress analytics'), findsOneWidget);
    expect(find.text('Export your own data'), findsOneWidget);
    expect(find.text('Watch and health sync'), findsOneWidget);
    expect(find.text('300+ home workout videos'), findsNothing);
    expect(find.text('View all features (19)'), findsOneWidget);
    expect(find.text('More insights. No ads.'), findsOneWidget);
    final heroTitle = tester.widget<Text>(
      find.text('Know your body. Go further.'),
    );
    expect(heroTitle.style?.fontFamily, 'BILDisplay');
    expect(heroTitle.style?.fontFamilyFallback, contains('BILArabic'));
    expect(heroTitle.maxLines, 3);

    final featuresToggle = find.byKey(
      const ValueKey('store-benefits-toggle-premiumSubscription'),
    );
    await tester.ensureVisible(featuresToggle);
    await tester.tap(featuresToggle);
    await tester.pump();

    // The published 300+ workout-video inventory is included in Premium.
    for (final benefit in <String>[
      '300+ home workout videos',
      'Personal weekly meal plan',
      'Goal-based nutrition pathways',
      'Weekly trends and comparisons',
      'Live fasting timer',
      'Sleep trends',
      'Detailed body profile',
      'Compatible fitness device connections',
      '100+ video-guided weight-training plans',
      'Connected health',
      'Friends and requests',
      'Private messages',
      'Custom calories and macros',
    ]) {
      expect(find.text(benefit), findsOneWidget, reason: benefit);
    }
    expect(find.text('7-day trial includes 1,000 AI tokens'), findsNothing);
    expect(find.text('YOUR COACH. YOUR PLAN. EVERY DAY.'), findsOneWidget);
    expect(find.textContaining('supports multiple languages'), findsOneWidget);
    expect(
      find.text('Daily, weekly, and monthly plans for your goal'),
      findsOneWidget,
    );
  });

  testWidgets('shows trial copy only for eligible AI Coach metadata', (
    tester,
  ) async {
    const paidOnly = BilStoreOfferMetadata(
      productId: 'premium.paid-only',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'USD 5.00',
      currencyCode: 'USD',
      priceMicros: 5000000,
      billingPeriodIso8601: 'P1M',
      trialEligible: false,
    );
    const forbiddenPremiumTrial = BilStoreOfferMetadata(
      productId: 'bil_premium',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'USD 5.00',
      currencyCode: 'USD',
      priceMicros: 5000000,
      billingPeriodIso8601: 'P1M',
      trialEligible: true,
      trialPeriodIso8601: 'P7D',
    );
    const withAiTrial = BilStoreOfferMetadata(
      productId: 'bil_premium_ai_coach',
      kind: BilStoreProductKind.premiumAiCoachSubscription,
      localizedTitle: 'AI Coach Monthly',
      localizedPrice: 'USD 8.00',
      currencyCode: 'USD',
      priceMicros: 8000000,
      billingPeriodIso8601: 'P1M',
      trialEligible: true,
      trialPeriodIso8601: 'P7D',
    );
    const aliasedAiTrial = BilStoreOfferMetadata(
      productId: 'bil_premium_ai_coach_alias',
      kind: BilStoreProductKind.premiumAiCoachSubscription,
      localizedTitle: 'AI Coach Monthly',
      localizedPrice: 'USD 8.00',
      currencyCode: 'USD',
      priceMicros: 8000000,
      billingPeriodIso8601: 'P1M',
      trialEligible: true,
      trialPeriodIso8601: 'P7D',
    );

    Future<void> pump(List<BilStoreOfferMetadata> offers) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(offers.first.productId),
          home: BilDynamicStoreOffers(
            locale: 'en',
            offers: offers,
            onPurchaseRequested: (_) {},
            onRestore: () {},
            onManage: () {},
          ),
        ),
      );
      final toggle = find.byKey(
        ValueKey('store-benefits-toggle-${offers.first.kind.name}'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }

    await pump(const [paidOnly]);
    expect(find.text('7-day trial includes 1,000 AI tokens'), findsNothing);

    await pump(const [forbiddenPremiumTrial]);
    expect(find.text('7-day trial includes 1,000 AI tokens'), findsNothing);
    expect(find.text('7 days free'), findsNothing);
    expect(
      find.byKey(const ValueKey('store-trial-renewal-bil_premium')),
      findsNothing,
    );

    await pump(const [aliasedAiTrial]);
    expect(find.text('7 days free'), findsNothing);
    expect(
      find.byKey(
        const ValueKey('store-trial-renewal-bil_premium_ai_coach_alias'),
      ),
      findsNothing,
    );

    await pump(const [withAiTrial]);
    expect(find.text('7-day trial includes 1,000 AI tokens'), findsOneWidget);
    expect(find.text('7 days free'), findsOneWidget);
    expect(
      find.text(
        'Then USD 8.00 per month. Renews automatically until canceled.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AI annual trial discloses localized store price and renewal', (
    tester,
  ) async {
    const offer = BilStoreOfferMetadata(
      productId: 'bil_premium_ai_coach_annual',
      kind: BilStoreProductKind.premiumAiCoachSubscription,
      localizedTitle: 'AI Coach Annual',
      localizedPrice: 'EGP 999.00',
      currencyCode: 'EGP',
      priceMicros: 999000000,
      billingPeriodIso8601: 'P1Y',
      trialEligible: true,
      trialPeriodIso8601: 'P1W',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'ar',
          offers: const [offer],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    expect(find.text('7 أيام مجانًا'), findsOneWidget);
    expect(
      find.text('ثم EGP 999.00 سنويًا. يتجدد تلقائيًا حتى الإلغاء.'),
      findsOneWidget,
    );
  });

  testWidgets('AI Coach focus selects only the exact AI subscription', (
    tester,
  ) async {
    const ai = BilStoreOfferMetadata(
      productId: 'bil_premium_ai_coach',
      kind: BilStoreProductKind.premiumAiCoachSubscription,
      localizedTitle: 'AI Coach Monthly',
      localizedPrice: 'USD 8.00',
      currencyCode: 'USD',
      priceMicros: 8000000,
      billingPeriodIso8601: 'P1M',
    );
    BilStoreOfferMetadata? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [ai],
          initialFocus: 'ai-coach',
          onPurchaseRequested: (offer) => requested = offer,
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));
    expect(requested, same(ai));

    const premium = BilStoreOfferMetadata(
      productId: 'bil_premium',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Premium Monthly',
      localizedPrice: 'USD 5.00',
      currencyCode: 'USD',
      priceMicros: 5000000,
      billingPeriodIso8601: 'P1M',
    );
    requested = null;
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('premium-only-ai-focus'),
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [premium],
          initialFocus: 'ai-coach',
          onPurchaseRequested: (offer) => requested = offer,
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('store-purchase-cta')), findsNothing);
    expect(requested, isNull);
  });

  testWidgets(
    'AI Coach explains inherited Free and paid features with one Premium label',
    (tester) async {
      const monthly = BilStoreOfferMetadata(
        productId: 'bil_premium_ai_coach',
        kind: BilStoreProductKind.premiumAiCoachSubscription,
        localizedTitle: 'AI Coach Monthly',
        localizedPrice: r'$5.99',
        currencyCode: 'USD',
        priceMicros: 5990000,
        billingPeriodIso8601: 'P1M',
      );
      const annual = BilStoreOfferMetadata(
        productId: 'bil_premium_ai_coach_annual',
        kind: BilStoreProductKind.premiumAiCoachSubscription,
        localizedTitle: 'AI Coach Annual',
        localizedPrice: r'$49.99',
        currencyCode: 'USD',
        priceMicros: 49990000,
        billingPeriodIso8601: 'P1Y',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BilDynamicStoreOffers(
            locale: 'en',
            offers: const [monthly, annual],
            onPurchaseRequested: (_) {},
            onRestore: () {},
            onManage: () {},
          ),
        ),
      );

      expect(find.text('AI Coach'), findsOneWidget);
      expect(find.text('Everything included in BIL Premium'), findsOneWidget);
      expect(find.text('Advanced personalized AI Coach'), findsOneWidget);
      expect(
        find.text('BIL Free + every paid feature + AI Coach'),
        findsOneWidget,
      );

      final toggle = find.byKey(
        const ValueKey('store-benefits-toggle-premiumAiCoachSubscription'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      for (final inherited in const <String>[
        'No ads',
        'Personalized Meal Planner',
        'Scan food barcode',
        '1,500 recipes',
        '300+ home workout videos',
        '100+ video-guided weight-training plans',
        'Connected health',
        'Friends and requests',
        'Private messages',
      ]) {
        expect(find.text(inherited), findsOneWidget, reason: inherited);
      }

      final premiumLabels = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').toLowerCase().contains('premium'),
      );
      expect(premiumLabels, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Premium-only tier keeps monthly visible and purchasable', (
    tester,
  ) async {
    const monthly = BilStoreOfferMetadata(
      productId: 'bil_premium',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Premium Monthly',
      localizedPrice: 'EGP 129.99',
      currencyCode: 'EGP',
      priceMicros: 129990000,
      billingPeriodIso8601: 'P1M',
    );
    const annual = BilStoreOfferMetadata(
      productId: 'bil_premium_annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Premium Annual',
      localizedPrice: 'EGP 999.99',
      currencyCode: 'EGP',
      priceMicros: 999990000,
      billingPeriodIso8601: 'P1Y',
    );
    BilStoreOfferMetadata? requested;

    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [monthly, annual],
          onPurchaseRequested: (offer) => requested = offer,
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('store-offer-bil_premium')),
      findsOneWidget,
    );
    expect(find.text('EGP 129.99'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('store-offer-bil_premium')),
    );
    await tester.tap(find.byKey(const ValueKey('store-offer-bil_premium')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));

    expect(requested, same(monthly));
    final premiumLabels = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data ?? '').toLowerCase().contains('premium'),
    );
    expect(premiumLabels, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders store price and emits request without granting access', (
    tester,
  ) async {
    BilStoreOfferMetadata? requested;
    const offer = BilStoreOfferMetadata(
      productId: 'premium_monthly_owner_placeholder',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'EGP 99.00',
      currencyCode: 'EGP',
      priceMicros: 99000000,
      storeCountryCode: 'EG',
      billingPeriodIso8601: 'P1M',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [offer],
          onPurchaseRequested: (value) => requested = value,
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));
    expect(requested, same(offer));
    expect(find.textContaining('EGP 99.00'), findsNWidgets(2));
  });

  testWidgets(
    'annual offer derives its badge and reference from store metadata',
    (tester) async {
      const monthly = BilStoreOfferMetadata(
        productId: 'premium.monthly',
        kind: BilStoreProductKind.premiumSubscription,
        localizedTitle: 'Monthly',
        localizedPrice: 'Local 199',
        currencyCode: 'USD',
        priceMicros: 1990000,
        billingPeriodIso8601: 'P1M',
      );
      const annual = BilStoreOfferMetadata(
        productId: 'premium.annual',
        kind: BilStoreProductKind.premiumSubscription,
        localizedTitle: 'Annual',
        localizedPrice: 'Local 16.72',
        currencyCode: 'USD',
        priceMicros: 16720000,
        billingPeriodIso8601: 'P1Y',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BilDynamicStoreOffers(
            locale: 'en',
            offers: const [monthly, annual],
            onPurchaseRequested: (_) {},
            onRestore: () {},
            onManage: () {},
          ),
        ),
      );

      // The monthly and annual store amounts calculate to a rounded 30%.
      expect(find.text('Local 16.72'), findsOneWidget);
      expect(find.text('Save 30%'), findsOneWidget);
      expect(find.textContaining('12 monthly payments:'), findsOneWidget);
      expect(find.textContaining('Monthly equivalent:'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('annual-savings-premium.annual')),
        findsOneWidget,
      );
      final referencePrice = tester.widget<Text>(
        find.byKey(const ValueKey('annual-reference-price-premium.annual')),
      );
      expect(referencePrice.data, isNotEmpty);
      expect(referencePrice.style?.decoration, TextDecoration.lineThrough);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('store-offer-premium.annual')))
            .height,
        lessThan(200),
      );
      final annualPrice = tester.widget<Text>(
        find.byKey(const ValueKey('store-offer-price-premium.annual')),
      );
      expect(annualPrice.maxLines, 1);
    },
  );

  testWidgets('annual badge reflects a different store-derived saving', (
    tester,
  ) async {
    const monthly = BilStoreOfferMetadata(
      productId: 'premium.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'Local 1.99',
      currencyCode: 'USD',
      priceMicros: 1990000,
      billingPeriodIso8601: 'P1M',
    );
    const annual = BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'Local 16.99',
      currencyCode: 'USD',
      priceMicros: 16990000,
      billingPeriodIso8601: 'P1Y',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [monthly, annual],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    expect(find.text('Save 29%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('annual-reference-price-premium.annual')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('annual-savings-premium.annual')),
      findsOneWidget,
    );
  });

  testWidgets('annual comparison fails closed without a monthly store offer', (
    tester,
  ) async {
    const annual = BilStoreOfferMetadata(
      productId: 'premium.annual.only',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'Store annual price',
      currencyCode: 'USD',
      priceMicros: 21000000,
      billingPeriodIso8601: 'P1Y',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [annual],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('annual-reference-price-premium.annual.only')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('annual-savings-premium.annual.only')),
      findsNothing,
    );
  });
}
