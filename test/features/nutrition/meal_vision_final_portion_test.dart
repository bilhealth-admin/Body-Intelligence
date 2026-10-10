import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_review_dialog.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vision_v2_test_fixture.dart';

void main() {
  setUpAll(prepareVisionV2Fixture);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<void> waitForDecodedPhoto(WidgetTester tester, Finder surface) async {
    final images = find.descendant(
      of: surface,
      matching: find.byType(RawImage),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      if (tester
          .widgetList<RawImage>(images)
          .any((image) => image.image != null)) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('The original TEST file did not decode on the visible photo surface.');
  }

  testWidgets(
    'cancel final review returns no selection and no substitute photo',
    (tester) async {
      await setVisionV2Viewport(tester, const Size(320, 740));
      TrustedVisionFoodSelection? result;
      var completed = false;
      await tester.pumpWidget(
        visionV2App(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showReviewedVisionFoodMatchDialog(
                  context,
                  recognizedName: 'TEST',
                  foods: [visionV2Food()],
                  reviewedAmount: 60,
                  reviewedUnit: 'g',
                  imagePath: 'build/absent-original-photo.png',
                );
                completed = true;
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-vision-final-photo')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('premium-vision-use-food')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('zoom close remains tappable before original photo decodes', (
    tester,
  ) async {
    await setVisionV2Viewport(tester, const Size(390, 844));
    final provider = FileImage(File(visionV2PhotoPath));
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    // Hold the real FileImage stream pending; no placeholder or replacement
    // widget. This reproduces slow decoding deterministically on local Flutter.
    final pending = Completer<ImageInfo>();
    cache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(pending.future),
    );
    addTearDown(() {
      cache.clear();
      cache.clearLiveImages();
    });
    await tester.pumpWidget(
      visionV2App(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showReviewedVisionFoodMatchDialog(
              context,
              recognizedName: 'TEST',
              foods: [visionV2Food()],
              reviewedAmount: 60,
              reviewedUnit: 'g',
              imagePath: visionV2PhotoPath,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('premium-vision-final-photo')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final images = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(RawImage),
    );
    expect(
      tester.widgetList<RawImage>(images).every((image) => image.image == null),
      isTrue,
    );
    await captureVisionV2(tester, 'zoom_pending_original_decode');
    // Fatal hit-test warnings prevent a barrier tap from masquerading as a
    // successful press of the close button.
    await tester.tap(find.byTooltip('إغلاق الصورة'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('final edited portion returns the food and exact commit basis', (
    tester,
  ) async {
    await setVisionV2Viewport(tester, const Size(390, 844));
    TrustedVisionFoodSelection? result;
    final food = visionV2Food();
    await tester.pumpWidget(
      visionV2App(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showReviewedVisionFoodMatchDialog(
                context,
                recognizedName: 'TEST',
                foods: [food],
                reviewedAmount: 60,
                reviewedUnit: 'g',
                imagePath: visionV2PhotoPath,
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    final photo = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('premium-vision-final-photo')),
        matching: find.byType(Image),
      ),
    );
    expect((photo.image as FileImage).file.path, visionV2PhotoPath);
    await waitForDecodedPhoto(
      tester,
      find.byKey(const Key('premium-vision-final-photo')),
    );
    await tester.tap(find.byKey(const Key('premium-vision-final-photo')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final zoom = tester.widget<Image>(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(Image),
      ),
    );
    expect((zoom.image as FileImage).file.path, visionV2PhotoPath);
    await waitForDecodedPhoto(tester, find.byType(InteractiveViewer));
    await tester.tap(find.byTooltip('إغلاق الصورة'));
    await tester.pumpAndSettle();
    // A tap warning is not a successful dismissal: require the zoom route
    // to be gone before touching the underlying trusted-food selection.
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.ensureVisible(find.text(food.arabicName!));
    await tester.tap(find.text(food.arabicName!));
    await tester.pumpAndSettle();
    Future<void> edit(String amount, String unit) async {
      await tester.ensureVisible(
        find.byKey(const Key('premium-vision-final-amount')),
      );
      await tester.enterText(
        find.byKey(const Key('premium-vision-final-amount')),
        amount,
      );
      await tester.enterText(
        find.byKey(const Key('premium-vision-final-unit')),
        unit,
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
    }

    FilledButton action() =>
        tester.widget(find.byKey(const Key('premium-vision-use-food')));
    for (final amount in ['0', '-1', 'NaN', 'Infinity', '']) {
      await edit(amount, 'g');
      expect(action().onPressed, isNull);
    }
    await edit('2', 'piece');
    expect(action().onPressed, isNull); // No invented piece-to-gram conversion.
    await edit('٠٫٠٨', 'kg');
    expect(action().onPressed, isNotNull);
    await tester.ensureVisible(
      find.byKey(const Key('premium-vision-quick-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('76.0 kcal'), findsOneWidget);
    await captureVisionV2(tester, 'functional_final_80g_nutrition');
    // The screenshot must be taken after the edited amount is rendered.
    // UI assertions alone do not guarantee Flutter raster evidence is fresh.
    final recorded = File(
      'build/vision-v2-captures/functional_final_80g_nutrition.png',
    );
    expect(recorded.existsSync(), isTrue);
    expect(recorded.lengthSync(), greaterThan(2500));
    await tester.tap(find.byKey(const Key('premium-vision-use-food')));
    await tester.pumpAndSettle();
    expect(result!.food, same(food));
    expect(result!.amount, 0.08);
    expect(result!.unit, 'kg');
    final portion = mealImageReviewedQuantity(
      amount: result!.amount,
      unit: result!.unit,
      servingSize: result!.food.servingSize,
      servingUnit: result!.food.servingUnit,
    )!;
    expect(portion.quantity, 80);
    expect(portion.quantityInGrams, isTrue);
    expect(portion.servingFactor, 0.8);
    expect(tester.takeException(), isNull);
  });

  test(
    'both diary entry points commit final values and route-scoped original photo',
    () {
      for (final name in [
        'daily_log_capture_actions.dart',
        'food_log_actions.dart',
      ]) {
        final source = File('lib/features/daily_log/$name').readAsStringSync();
        expect(source, contains('showReviewedVisionFoodMatchDialog('));
        expect(source, contains('imagePath: image.path,'));
        expect(source, contains('amount: reviewed.amount,'));
        expect(source, contains('unit: reviewed.unit,'));
        expect(source, contains('food: reviewed.food,'));
        expect(source, contains('addReviewedVisionItemsAtomically('));
      }
    },
  );
}
