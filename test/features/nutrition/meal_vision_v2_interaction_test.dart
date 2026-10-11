import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vision_v2_test_fixture.dart';

Finder key(String value) => find.byKey(Key(value));
Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String field(WidgetTester tester, String name) =>
    tester.widget<TextField>(key('premium-vision-$name-0')).controller!.text;

void main() {
  setUpAll(prepareVisionV2Fixture);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets(
    'V2 original photo choice cannot save leftovers or infer eaten amount',
    (tester) async {
      await setVisionV2Viewport(tester, const Size(430, 844));
      List<PremiumVisionSelection>? result;
      await openVisionV2Review(tester, onResult: (value) => result = value);
      await tap(tester, key('premium-vision-stage-after'));
      await tap(tester, key('premium-vision-select-0'));
      await tap(tester, key('premium-vision-remaining-0'));
      expect(field(tester, 'amount'), isEmpty);
      expect(
        tester.widget<FilledButton>(key('premium-vision-continue')).onPressed,
        isNull,
      );
      expect(result, isNull);
      await tap(tester, key('premium-vision-eaten-0'));
      await tester.enterText(key('premium-vision-amount-0'), '٨٠');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(key('premium-vision-continue')).onPressed,
        isNotNull,
      );
      await tap(tester, key('premium-vision-plus-0'));
      expect(field(tester, 'amount'), '85');
      await tap(tester, key('premium-vision-minus-0'));
      expect(field(tester, 'amount'), '80');
      for (final unit in ['kg', 'oz', 'lb', 'piece', 'ml', 'serving', 'g']) {
        await tap(tester, find.byTooltip('اختيار الوحدة'));
        await tap(tester, find.widgetWithText(PopupMenuItem<String>, unit));
        expect(field(tester, 'unit'), unit);
      }
      await tap(tester, find.text('Alternative TEST food'));
      await tap(tester, key('premium-vision-continue'));
      expect(result, hasLength(1));
      expect(result!.single.amount, 80);
      expect(result!.single.unit, 'g');
      expect(result!.single.candidate.name, 'Alternative TEST food');
      expect(result!.single.candidate.verifiedFoodRecordId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V2 exclude and cancel return no selected write request', (
    tester,
  ) async {
    await setVisionV2Viewport(tester, const Size(390, 844));
    var completed = false;
    List<PremiumVisionSelection>? result;
    await openVisionV2Review(
      tester,
      onResult: (value) {
        completed = true;
        result = value;
      },
    );
    await tap(tester, key('premium-vision-select-0'));
    await tap(tester, key('premium-vision-exclude-0'));
    expect(key('premium-vision-food-0'), findsNothing);
    expect(
      tester.widget<FilledButton>(key('premium-vision-continue')).onPressed,
      isNull,
    );
    await tap(tester, key('premium-vision-close'));
    expect(completed, isTrue);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(768, 1024), const Size(844, 390)]) {
    testWidgets('V2 tablet or landscape $size original image and controls', (
      tester,
    ) async {
      await setVisionV2Viewport(tester, size);
      await openVisionV2Review(tester);
      await captureVisionV2(
        tester,
        'review_${size.width.toInt()}_${size.height.toInt()}',
      );
      expect(tester.getSize(key('premium-vision-render-surface')), size);
      await tap(tester, key('premium-vision-select-0'));
      await tester.ensureVisible(key('premium-vision-amount-0'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('premium-vision-continue')).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('V2 keyboard insets keep original review action reachable', (
    tester,
  ) async {
    await setVisionV2Viewport(tester, const Size(390, 844));
    await openVisionV2Review(tester);
    await tap(tester, key('premium-vision-select-0'));
    await tap(tester, key('premium-vision-amount-0'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await captureVisionV2(tester, 'review_keyboard_inset_300');
    expect(
      tester.getRect(key('premium-vision-continue')).bottom,
      lessThanOrEqualTo(544),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('V2 safe insets leave close and continue inside usable area', (
    tester,
  ) async {
    await setVisionV2Viewport(tester, const Size(390, 844));
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    await openVisionV2Review(tester);
    await captureVisionV2(
      tester,
      'review_safe_insets_24_34',
      wholeScreen: true,
    );
    expect(
      tester.getRect(key('premium-vision-close')).top,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester.getRect(key('premium-vision-continue')).bottom,
      lessThanOrEqualTo(810),
    );
    expect(tester.takeException(), isNull);
  });
}
