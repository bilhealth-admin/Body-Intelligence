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
      var confirmations = 0;
      final results = <List<PremiumVisionSelection>?>[];
      await openVisionV2Review(
        tester,
        onConfirm: (_) async {
          confirmations++;
          return const MealVisionReviewDecision.accepted();
        },
        onResult: results.add,
      );
      Future<void> tapVisible(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

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
        isNotNull,
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

      // Keep the reference captures unchanged, then exercise incomplete input:
      // the enabled action must guide the user without returning or confirming.
      final continueButton = find.byKey(const Key('premium-vision-continue'));
      await tapVisible(continueButton);
      expect(find.byKey(const Key('vision-required-details')), findsOneWidget);
      expect(find.byKey(const Key('vision-missing-stage')), findsOneWidget);
      expect(
        find.byKey(const Key('vision-missing-selection-0')),
        findsOneWidget,
      );
      expect(confirmations, 0);
      expect(results, isEmpty);
      await tapVisible(find.byKey(const Key('vision-required-cancel')));
      expect(find.byKey(const Key('vision-required-details')), findsNothing);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('premium-vision-select-0')))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('premium-vision-stage-before')),
            )
            .selected,
        isFalse,
      );
      expect(confirmations, 0);
      expect(results, isEmpty);

      // Choosing a missing field restores focus, never chooses its answer.
      await tapVisible(continueButton);
      await tapVisible(find.byKey(const Key('vision-missing-selection-0')));
      expect(find.byKey(const Key('vision-required-details')), findsNothing);
      final selection = tester.widget<Checkbox>(
        find.byKey(const Key('premium-vision-select-0')),
      );
      expect(selection.focusNode!.hasFocus, isTrue);
      expect(selection.value, isFalse);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('premium-vision-stage-before')),
            )
            .selected,
        isFalse,
      );
      expect(confirmations, 0);
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
      await tapVisible(find.byKey(const Key('premium-vision-close')));
      expect(results, hasLength(1));
      expect(results.single, isNull);
      expect(confirmations, 0);

      final food = visionV2Food(serving: 60);
      await tester.pumpWidget(
        visionV2App(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditableTrustedVisionFoodMatchDialog(
                context,
                recognizedName: 'فول مدمس مع طحينة — عينة اختبار',
                foods: [food],
                reviewedAmount: 60,
                reviewedUnit: 'g',
                imagePath: visionV2PhotoPath,
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
