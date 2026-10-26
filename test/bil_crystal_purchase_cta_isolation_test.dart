import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/shared/widgets/bil_glass_press_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic store metadata only. No real purchase, network, or user account.
// CI executes this same test against immutable iOS38 and exact BIL39 Crystal
// on the same Flutter 3.44.6 runner. The comparator checks complete CTA pixels,
// halo and geometry, and permits only the separately reviewed feature chevron
// decoration elsewhere on the captured page. It has no pixel-error tolerance.
const _offer = BilStoreOfferMetadata(
  productId: 'crystal.guard.monthly',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Monthly',
  localizedPrice: 'EGP 129.99',
  currencyCode: 'EGP',
  priceMicros: 129990000,
  billingPeriodIso8601: 'P1M',
);

const _purchaseKey = ValueKey('store-purchase-cta');
const _captureKey = Key('crystal-cta-compare-root');
const _legacyBubble = Key('bil-glass-press-bubble');
const _newCrystal = Key('bil-crystal-arrow-bubble');

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  final file = File('build/bil39_crystal_cta_pixels/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  final root = tester.getRect(find.byKey(_captureKey));
  final cta = find.byKey(_purchaseKey);
  final glyph = find.descendant(
    of: cta,
    matching: find.byIcon(Icons.chevron_right_rounded),
  );
  final featureArrow = find.byIcon(Icons.keyboard_arrow_down_rounded);
  expect(featureArrow, findsOneWidget);
  List<double> bounds(Rect rect) => [
    rect.left - root.left,
    rect.top - root.top,
    rect.right - root.left,
    rect.bottom - root.top,
  ];
  File('build/bil39_crystal_cta_pixels/$name.geometry.json').writeAsStringSync(
    jsonEncode({
      'capture_size': [root.width, root.height],
      'cta_bounds': bounds(tester.getRect(cta)),
      'glyph_bounds': bounds(tester.getRect(glyph)),
      'feature_arrow_bounds': bounds(tester.getRect(featureArrow)),
    }),
  );
}

void main() {
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets('protected CTA pixel and action dark=$dark rtl=$rtl', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        BilStoreOfferMetadata? requested;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: RepaintBoundary(
                key: _captureKey,
                child: Scaffold(
                  body: BilDynamicStoreOffers(
                    locale: rtl ? 'ar' : 'en',
                    offers: const [_offer],
                    onPurchaseRequested: (offer) => requested = offer,
                    onRestore: () {},
                    onManage: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cta = find.byKey(_purchaseKey);
        expect(cta, findsOneWidget);
        // This legacy component preserves arrow_forward_rounded in its
        // source, but BilGlassPressFeedback renders chevron_right_rounded.
        // Check BOTH contracts rather than searching for a non-rendered Icon.
        final legacyFeedback = find.descendant(
          of: cta,
          matching: find.byType(BilGlassPressFeedback),
        );
        expect(legacyFeedback, findsOneWidget);
        final feedback = tester.widget<BilGlassPressFeedback>(legacyFeedback);
        final sourceIcon = feedback.child;
        expect(sourceIcon, isA<Icon>());
        final original = sourceIcon as Icon;
        expect(original.icon, Icons.arrow_forward_rounded);
        expect(original.color, const Color(0xFF06121D));
        expect(original.size, 20);

        final arrow = find.descendant(
          of: legacyFeedback,
          matching: find.byIcon(Icons.chevron_right_rounded),
        );
        expect(arrow, findsOneWidget);
        expect(
          find.descendant(
            of: cta,
            matching: find.byIcon(Icons.arrow_forward_rounded),
          ),
          findsNothing,
          reason: 'Legacy glyph modernizer must remain active for checkout.',
        );
        final icon = tester.widget<Icon>(arrow);
        expect(icon.color, const Color(0xFF06121D));
        expect(icon.size, 20);
        expect(tester.getSize(cta).height, 56);
        expect(tester.widget<InkWell>(cta).onTap, isNotNull);
        expect(
          find.descendant(
            of: cta,
            matching: find.byType(BilGlassPressFeedback),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cta, matching: find.byKey(_newCrystal)),
          findsNothing,
          reason: 'The purchase arrow is excluded from persistent crystal.',
        );

        final rect = tester.getRect(arrow);
        final caseId = '${dark ? 'dark' : 'light'}_${rtl ? 'rtl' : 'ltr'}';
        await _capture(tester, 'rest_$caseId');

        final gesture = await tester.startGesture(tester.getCenter(arrow));
        await tester.pump();
        expect(
          find.descendant(of: cta, matching: find.byKey(_legacyBubble)),
          findsOneWidget,
        );
        expect(tester.getRect(arrow), rect);
        await _capture(tester, 'pressed_$caseId');

        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(find.byKey(_legacyBubble), findsNothing);
        expect(requested, isNull);
        expect(tester.getRect(arrow), rect);
        await _capture(tester, 'cancelled_$caseId');

        // Only the synthetic callback is invoked; no platform purchase exists.
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(requested?.productId, _offer.productId);
        expect(
          find.descendant(of: cta, matching: find.byKey(_newCrystal)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
