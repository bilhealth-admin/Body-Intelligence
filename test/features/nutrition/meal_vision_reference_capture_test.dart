import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vision_v2_test_fixture.dart';

/// Reference composition evidence, never a physical-device or live AI claim.
void main() {
  setUpAll(prepareVisionV2Fixture);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets(
    'reference composition: review, edit control and trusted full facts',
    (tester) async {
      await setVisionV2Viewport(tester, const Size(430, 932));
      await openVisionV2Review(tester);
      await captureVisionV2(tester, 'reference_review_430_ar_dark');
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-unverified-nutrition')),
      );
      await tester.pumpAndSettle();
      await captureVisionV2(
        tester,
        'reference_unmatched_nutrition_430_ar_dark',
      );
      await tester.tap(
        find.byKey(const Key('premium-vision-edit-ingredients')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('premium-vision-select-0')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('premium-vision-select-0')))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('premium-vision-continue')),
            )
            .onPressed,
        isNull,
      );
      final primaryText = find.descendant(
        of: find.byKey(const Key('premium-vision-continue')),
        matching: find.byType(Text),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(primaryText)
            .text
            .style
            ?.fontFamily,
        'NotoArabicEvidence',
      );
      await captureVisionV2(tester, 'reference_edit_scroll_430_ar_dark');
      await tester.tap(find.byKey(const Key('premium-vision-close')));
      await tester.pumpAndSettle();

      final food = visionV2Food(serving: 60);
      await tester.pumpWidget(
        visionV2App(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPremiumTrustedVisionFoodMatchDialog(
                context,
                recognizedName: 'فول مدمس مع طحينة — عينة اختبار',
                foods: [food],
                reviewedAmount: 60,
                reviewedUnit: 'g',
              ),
              child: const Text('OPEN VERIFIED TEST'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN VERIFIED TEST'));
      await tester.pumpAndSettle();
      expect(find.text(food.name), findsNothing);
      await tester.tap(find.text(food.arabicName!));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-quick-toggle')),
      );
      await tester.pumpAndSettle();
      await captureVisionV2(tester, 'reference_quick_60g_catalog_serving_60g');
      await tester.tap(find.byKey(const Key('premium-vision-full-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('95.0 kcal'), findsOneWidget);
      expect(find.text('8.4 g'), findsOneWidget);
      expect(find.text('170.0 mg'), findsOneWidget);
      await captureVisionV2(tester, 'reference_full_60g_catalog_serving_60g');
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-nutrient-sodium')),
      );
      await tester.pumpAndSettle();
      await captureVisionV2(
        tester,
        'reference_full_minerals_60g_catalog_serving_60g',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
