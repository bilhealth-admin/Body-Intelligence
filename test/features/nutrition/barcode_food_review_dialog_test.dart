import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/barcode_food_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barcode review copy covers every production locale exactly', () {
    expect(barcodeReviewTags, BilLocalePolicy.productionTags);
  });

  for (final tag in BilLocalePolicy.productionTags) {
    testWidgets(
      'barcode review renders ingredients and evidenced nutrition in $tag',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final food = _food();
        Food? selected;
        final locale = BilLocalePolicy.localeFromTag(tag);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  key: const Key('open-barcode-review'),
                  onPressed: () async {
                    selected = await showBarcodeFoodReviewDialog(
                      context,
                      barcode: '4006381333931',
                      candidates: <Food>[food],
                      ingredients: 'Oats, milk',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-barcode-review')));
        await tester.pumpAndSettle();

        final title = tester.widget<Text>(
          find.byKey(const Key('barcode-food-review-title')),
        );
        expect(title.data, isNotEmpty, reason: tag);
        expect(
          find.byKey(const Key('barcode-food-review-ingredients')),
          findsOneWidget,
          reason: tag,
        );
        for (final amount in const <String>[
          '123 kcal',
          '12 g',
          '34 g',
          '5 g',
          '6 g',
          '7 g',
          '89 mg',
        ]) {
          expect(
            find.textContaining(amount),
            findsOneWidget,
            reason: '$tag $amount',
          );
        }

        await tester.tap(find.byKey(const Key('barcode-food-review-confirm')));
        await tester.pumpAndSettle();
        expect(selected, same(food), reason: tag);
      },
    );
  }
}

Food _food() {
  final now = DateTime(2026, 9, 5);
  return Food(
    id: 1,
    uuid: 'barcode-review-food',
    name: 'Whole grain cereal',
    arabicName: null,
    category: 'Breakfast',
    keywords: 'oats,milk',
    barcode: '4006381333931',
    servingSize: 100,
    servingUnit: 'g',
    calories: 123,
    protein: 12,
    carbs: 34,
    fats: 5,
    fiber: 6,
    sugar: 7,
    potassium: 0,
    sodium: 89,
    calcium: 0,
    iron: 0,
    magnesium: 0,
    phosphorus: 0,
    vitaminC: 0,
    nutrientEvidenceMask: NutrientEvidenceMask.fromValues(
      calories: 123,
      protein: 12,
      carbohydrates: 34,
      fat: 5,
      fiber: 6,
      sugar: 7,
      sodium: 89,
    ),
    verified: true,
    isCustom: false,
    source: 'Open Food Facts',
    createdAt: now,
    updatedAt: now,
    revision: 1,
    syncStatus: 'local',
  );
}
