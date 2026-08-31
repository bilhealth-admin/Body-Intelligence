import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI-only storefront explains concrete Premium and AI benefits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BilDynamicStoreOffers(
            locale: 'en',
            offers: const [
              BilStoreOfferMetadata(
                productId: 'bil_premium_ai_coach',
                kind: BilStoreProductKind.premiumAiCoachSubscription,
                localizedTitle: 'Premium AI Coach',
                localizedPrice: r'$9.99',
                currencyCode: 'USD',
                priceMicros: 9990000,
                billingPeriodIso8601: 'P1M',
              ),
            ],
            onPurchaseRequested: (_) {},
            onRestore: null,
            onManage: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Coach'), findsOneWidget);
    expect(
      find.text('BIL Free + every paid feature + AI Coach'),
      findsOneWidget,
    );
    expect(find.text('Everything included in BIL Premium'), findsOneWidget);
    expect(find.text('Advanced personalized AI Coach'), findsOneWidget);
    expect(find.text('Global multilingual voice'), findsOneWidget);
    expect(
      find.text('2,500 AI tokens each week, up to 10,000 each month'),
      findsOneWidget,
    );
    expect(find.text('1,500 recipes'), findsNothing);

    final featuresToggle = find.byKey(
      const ValueKey('store-benefits-toggle-premiumAiCoachSubscription'),
    );
    await tester.ensureVisible(featuresToggle);
    await tester.tap(featuresToggle);
    await tester.pump();

    expect(find.text('1,500 recipes'), findsOneWidget);
    expect(find.text('300+ home workout videos'), findsOneWidget);
    expect(find.text('Scan food barcode'), findsOneWidget);
    expect(find.text('Live fasting timer'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
    expect(find.text('Friends and requests'), findsOneWidget);
    expect(find.text('Private messages'), findsOneWidget);
    final visiblePremiumLabels = tester
        .widgetList<Text>(find.byType(Text))
        .where(
          (widget) => (widget.data ?? '').toLowerCase().contains('premium'),
        );
    expect(visiblePremiumLabels, hasLength(1));
  });
}
