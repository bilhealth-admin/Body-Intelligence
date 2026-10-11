import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_premium_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vision_v2_test_fixture.dart';

Finder key(String value) => find.byKey(Key(value));

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void originalPhoto(WidgetTester tester, Finder parent) {
  final photo = tester.widget<Image>(
    find.descendant(of: parent, matching: find.byType(Image)).first,
  );
  expect(photo.image, isA<FileImage>());
  expect((photo.image as FileImage).file.path, visionV2PhotoPath);
}

void main() {
  setUpAll(prepareVisionV2Fixture);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final language in ['ar', 'en']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.8, 2.0]) {
          final id =
              '${width.toInt()}_${language}_${brightness.name}_${scale}x';
          final capture =
              (language == 'ar' && brightness == Brightness.dark) ||
              (language == 'en' &&
                  brightness == Brightness.light &&
                  scale == 1.8);
          testWidgets(
            'V2 review $id original photo, clock, controls and overflow',
            (tester) async {
              await setVisionV2Viewport(tester, Size(width, 844));
              await openVisionV2Review(
                tester,
                language: language,
                brightness: brightness,
                scale: scale,
              );
              expect(
                tester.getSize(key('premium-vision-render-surface')),
                Size(width, 844),
              );
              originalPhoto(tester, key('premium-vision-photo'));
              expect(find.byType(BackdropFilter), findsWidgets);
              final actionText = find.descendant(
                of: key('premium-vision-continue'),
                matching: find.byType(Text),
              );
              final action = tester.renderObject<RenderParagraph>(actionText);
              expect(
                action.text.style?.fontFamily,
                language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
                reason:
                    'Action text must inherit the real evidence font, not Ahem fallback.',
              );
              expect(key('premium-vision-amount-0'), findsNothing);
              if (capture) {
                await captureVisionV2(tester, 'review_initial_$id');
              }
              await tester.ensureVisible(key('premium-vision-clock'));
              await tester.pumpAndSettle();
              expect(
                tester.widget<Text>(key('premium-vision-clock')).data,
                '11:30',
              );
              expect(
                Directionality.of(tester.element(key('premium-vision-clock'))),
                TextDirection.ltr,
              );
              if (width == 430 &&
                  language == 'ar' &&
                  brightness == Brightness.dark &&
                  scale == 1) {
                await captureVisionV2(tester, 'clock_11_30_$id');
                await tapVisible(tester, key('premium-vision-photo'));
                expect(find.byType(InteractiveViewer), findsOneWidget);
                originalPhoto(tester, find.byType(InteractiveViewer));
                await captureVisionV2(
                  tester,
                  'original_photo_zoom_$id',
                  wholeScreen: true,
                );
                await tester.tap(find.byTooltip('إغلاق الصورة'));
                await tester.pumpAndSettle();
              }
              await tapVisible(tester, key('premium-vision-select-0'));
              expect(key('premium-vision-amount-0'), findsOneWidget);
              await tester.ensureVisible(key('premium-vision-amount-0'));
              await tester.pumpAndSettle();
              if (capture) {
                await captureVisionV2(tester, 'review_selected_$id');
              }
              expect(
                tester
                    .widget<FilledButton>(key('premium-vision-continue'))
                    .onPressed,
                isNull,
              );
              expect(tester.takeException(), isNull, reason: id);
            },
          );

          testWidgets(
            'V2 nutrients $id values and unavailable facts stay readable',
            (tester) async {
              await setVisionV2Viewport(tester, Size(width, 844));
              final food = visionV2Food();
              await tester.pumpWidget(
                visionV2App(
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showEditableTrustedVisionFoodMatchDialog(
                        context,
                        recognizedName: 'TEST FIXTURE — فول',
                        foods: [food],
                        reviewedAmount: 80,
                        reviewedUnit: 'g',
                        imagePath: visionV2PhotoPath,
                      ),
                      child: const Text('OPEN NUTRIENTS'),
                    ),
                  ),
                  language: language,
                  brightness: brightness,
                  scale: scale,
                ),
              );
              await tester.tap(find.text('OPEN NUTRIENTS'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<FilledButton>(key('premium-vision-use-food'))
                    .onPressed,
                isNull,
              );
              final foodTitle = language == 'ar' ? food.arabicName! : food.name;
              await tester.scrollUntilVisible(
                find.text(foodTitle),
                100,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              expect(find.text(foodTitle), findsOneWidget);
              if (language == 'ar') expect(find.text(food.name), findsNothing);
              await tapVisible(tester, find.text(foodTitle));
              for (final entry in {
                'calories': '76.0 kcal',
                'protein': '4.1 g',
                'fat': '2.7 g',
                'carbohydrates': '9.5 g',
                'fiber': '2.8 g',
                'netCarbs': '6.7 g',
              }.entries) {
                expect(
                  find.descendant(
                    of: key('premium-vision-nutrient-${entry.key}'),
                    matching: find.text(entry.value),
                  ),
                  findsOneWidget,
                );
              }
              expect(key('premium-vision-nutrient-potassium'), findsNothing);
              await tester.ensureVisible(key('premium-vision-quick-toggle'));
              await tester.pumpAndSettle();
              if (capture) {
                await captureVisionV2(tester, 'nutrition_quick_$id');
              }
              await tapVisible(tester, key('premium-vision-full-toggle'));
              for (final entry in {
                'potassium': '136.0 mg',
                'calcium': '36.0 mg',
                'magnesium': '23.2 mg',
                'phosphorus': '88.8 mg',
              }.entries) {
                expect(
                  find.descendant(
                    of: key('premium-vision-nutrient-${entry.key}'),
                    matching: find.text(entry.value),
                  ),
                  findsOneWidget,
                );
              }
              await tester.ensureVisible(key('premium-vision-nutrient-sodium'));
              await tester.pumpAndSettle();
              if (capture) {
                await captureVisionV2(tester, 'nutrition_full_$id');
              }
              final clipped = <String>[];
              for (final nutrient in ['sugar', 'sodium', 'iron', 'vitaminC']) {
                final unknown = find.descendant(
                  of: key('premium-vision-nutrient-$nutrient'),
                  matching: find.text(
                    language == 'ar' ? 'غير متوفر' : 'Not available',
                  ),
                );
                expect(unknown, findsOneWidget);
                final paragraph = tester.renderObject<RenderParagraph>(unknown);
                if (paragraph.didExceedMaxLines) clipped.add(nutrient);
              }
              expect(tester.takeException(), isNull, reason: id);
              expect(
                clipped,
                isEmpty,
                reason:
                    'Unavailable nutrient values must be fully readable at $id',
              );
              await tapVisible(tester, key('premium-vision-quick-toggle'));
              expect(key('premium-vision-nutrient-potassium'), findsNothing);
            },
          );
        }
      }
    }
  }
}
