import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate active custom barcodes fail closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);
    Future<int> add(String name) => repository.addFood(
      name: name,
      category: 'custom',
      barcode: '4006381333931',
      servingSize: 100,
      servingUnit: 'g',
      calories: 1,
      protein: 0,
      carbs: 0,
      fats: 0,
    );
    await add('First');
    await expectLater(add('Second'), throwsStateError);
    expect(await database.select(database.foods).get(), hasLength(1));

    Future<bool> concurrent(String name) => repository
        .addFood(
          name: name,
          category: 'custom',
          barcode: '036000291452',
          servingSize: 1,
          servingUnit: 'serving',
          calories: 1,
          protein: 0,
          carbs: 0,
          fats: 0,
        )
        .then((_) => true, onError: (_) => false);
    final concurrentResults = await Future.wait([
      concurrent('Concurrent A'),
      concurrent('Concurrent B'),
    ]);
    expect(concurrentResults.where((saved) => saved), hasLength(1));
    expect(await database.select(database.foods).get(), hasLength(2));

    await expectLater(
      repository.addFood(
        name: 'No unit',
        category: 'custom',
        servingSize: 1,
        servingUnit: ' ',
        calories: 1,
        protein: 0,
        carbs: 0,
        fats: 0,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.addFood(
        name: 'Impossible calories',
        category: 'custom',
        servingSize: 1,
        servingUnit: 'g',
        calories: 10001,
        protein: 0,
        carbs: 0,
        fats: 0,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('custom food can be created, edited, and tombstoned', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          seedCatalogProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FoodPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Custom food is intentionally nested behind the single Add food action so
    // the catalog keeps one clear primary task instead of exposing competing
    // capture buttons above the fold.
    await tester.tap(find.byKey(const Key('food-primary-add-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-add-custom-food')));
    await tester.pumpAndSettle();
    expect(find.text('Create custom food'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Serving size'),
          )
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'English name'),
      'Personal yogurt',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '120,5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Serving size'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Serving unit'),
      'g',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Personal yogurt'), findsOneWidget);
    var food = await database.select(database.foods).getSingle();
    expect(food.calories, 120.5);
    expect(
      NutrientEvidenceMask.contains(
        food.nutrientEvidenceMask,
        TrackedNutrient.calories,
      ),
      isTrue,
    );
    expect(
      NutrientEvidenceMask.contains(
        food.nutrientEvidenceMask,
        TrackedNutrient.protein,
      ),
      isFalse,
    );

    final favoriteButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.favorite_border),
    );
    favoriteButton.onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Personal yogurt'), findsOneWidget);
    await FoodRepository(database).recordRecent(food.id);
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('Personal yogurt'), findsOneWidget);

    tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Personal yogurt'))
        .onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit custom food'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '130',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    food = await database.select(database.foods).getSingle();
    expect(food.calories, 130);
    expect(food.revision, 2);

    tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Personal yogurt'))
        .onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete custom food?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    food = await database.select(database.foods).getSingle();
    expect(food.deletedAt, isNotNull);
    expect(food.revision, 3);
    await tester.pumpAndSettle();
    expect(find.text('Personal yogurt'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  test('custom food copy is complete for all 25 locales', () async {
    const keys = [
      'Create custom food',
      'Edit custom food',
      'English name',
      'Arabic name',
      'Barcode',
      'Serving size',
      'Serving unit',
      'Calories',
      'Protein',
      'Carbohydrates',
      'Fat',
      'Fiber',
      'Sodium',
      'Potassium',
      'Calcium',
      'Magnesium',
      'Sugar',
      'Required',
      'Enter a non-negative number',
      'Enter a valid 8 to 14 digit barcode',
      'Could not save this food. Review the values and try again.',
      'A food with this barcode already exists.',
    ];
    for (final locale in RuntimeCopy.supported.where(
      (tag) => !const {'ar', 'en', 'fr', 'es', 'tr'}.contains(tag),
    )) {
      for (final key in keys) {
        // Resolve directly from the generated locale catalog so an English
        // AppLocalizations fallback cannot make this test pass. Some nutrition
        // terms (for example "Barcode" or "Calcium") are legitimately written
        // identically in a number of languages, so string inequality is not a
        // valid completeness test for every key.
        expect(
          ExtendedRuntimeCopy.values[key]?.containsKey(locale),
          isTrue,
          reason: 'authored catalog entry $locale/$key',
        );
        final value = RuntimeCopy.resolve(key, locale);
        expect(value, isNotNull, reason: '$locale/$key');
        expect(value!.trim(), isNotEmpty, reason: '$locale/$key');
        if (key == 'Create custom food') {
          expect(value, isNot(key), reason: '$locale/$key');
        }
      }
    }
    for (final locale in const ['fr', 'es', 'tr']) {
      for (final key in keys) {
        final value = customFoodAuthoredValue(locale, key);
        expect(value, isNotNull, reason: '$locale/$key');
        if (key == 'Create custom food') {
          expect(value, isNot(key), reason: '$locale/$key');
        }
      }
    }
    final arabic = await AppLocalizations.delegate.load(const Locale('ar'));
    for (final key in keys) {
      expect(arabic.text(key), isNot(key), reason: 'ar/$key');
    }
  });
}
