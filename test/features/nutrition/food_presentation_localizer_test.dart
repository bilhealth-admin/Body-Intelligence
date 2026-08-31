import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_presentation_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

String _librarySource(String path) {
  final library = File(path);
  final entrypoint = library.readAsStringSync();
  final parts = RegExp(r"part '([^']+)';")
      .allMatches(entrypoint)
      .map((match) => File('${library.parent.path}/${match.group(1)!}'));
  return <String>[
    entrypoint,
    for (final part in parts) part.readAsStringSync(),
  ].join('\n');
}

void main() {
  final tags = AppLocalizations.supportedLocales
      .map(BilLocalePolicy.canonicalTag)
      .toSet();

  test('reviewed foods resolve locally in all 25 locales', () {
    expect(tags, FoodPresentationLocalizer.supportedLocaleTags);
    for (final tag in tags) {
      for (final food in const [
        'Apple',
        'Banana',
        'Orange',
        'Chicken, roasted',
        'Beef, cooked',
        'Fish, raw',
        'Rice, cooked',
        'Bread, whole wheat',
        'Egg, whole, raw, fresh',
        'Milk, whole',
        'Yogurt, plain',
        'Cheese, cheddar',
        'Potato, baked',
        'Tomato, red',
        'Cucumber, with peel',
        'Oats, rolled',
        'Salmon, cooked',
        'Tuna, canned',
        'Lentils, cooked',
        'Beans, cooked',
        'Water',
        'Coffee, brewed',
        'Tea, brewed',
      ]) {
        final localized = FoodPresentationLocalizer.foodName(
          name: food,
          localeTag: tag,
          source: 'USDA FoodData Central',
        );
        expect(localized.trim(), isNotEmpty, reason: '$tag / $food');
        expect(
          FoodPresentationLocalizer.hasLocalizedBrowseName(
            name: food,
            localeTag: tag,
            source: 'USDA FoodData Central',
          ),
          isTrue,
          reason: 'Missing localized catalog identity $tag / $food',
        );
        expect(localized, isNot(contains('Ã')));
        expect(localized, isNot(contains('Ø')));
        expect(localized, isNot(contains('Ù')));
      }
    }
    for (final tag in tags.where((tag) => tag != 'en')) {
      expect(
        FoodPresentationLocalizer.foodName(
          name: 'Chicken breast',
          localeTag: tag,
          source: 'USDA FoodData Central',
        ),
        isNot('Chicken breast'),
        reason: 'English food-name fallback: $tag',
      );
    }
  });

  test(
    'brand, custom, and unknown scientific identities are never invented',
    () {
      expect(
        FoodPresentationLocalizer.foodName(
          name: 'Apple Cinnamon Crunch™',
          localeTag: 'ar',
          source: 'branded barcode product',
        ),
        'Apple Cinnamon Crunch™',
      );
      expect(
        FoodPresentationLocalizer.foodName(
          name: 'My Apple Bowl',
          localeTag: 'ar',
          isCustom: true,
        ),
        'My Apple Bowl',
      );
      expect(
        FoodPresentationLocalizer.foodName(
          name: 'Malus domestica var. unknown-17',
          localeTag: 'ar',
          source: 'scientific catalog',
        ),
        'Malus domestica var. unknown-17',
      );
    },
  );

  test('serving units cover 25 locales and never expose undetermined', () {
    for (final tag in tags) {
      for (final unit in const [
        'g',
        'mg',
        'ml',
        'kcal',
        'piece',
        'serving',
        'oz',
        'kg',
        'lb',
      ]) {
        expect(
          FoodPresentationLocalizer.servingUnit(unit, tag).trim(),
          isNotEmpty,
          reason: '$tag / $unit',
        );
      }
      final unknown = FoodPresentationLocalizer.servingUnit(
        'undetermined',
        tag,
      );
      expect(unknown.toLowerCase(), isNot('undetermined'), reason: tag);
      expect(unknown.trim(), isNotEmpty, reason: tag);
      if (tag != 'en') {
        expect(
          FoodPresentationLocalizer.servingUnit('piece', tag),
          isNot('piece'),
          reason: 'English serving-unit fallback: $tag',
        );
      }
    }
    expect(FoodPresentationLocalizer.servingUnit('g', 'ar'), 'جم');
    expect(
      FoodPresentationLocalizer.servingUnit('undetermined', 'ar'),
      'الحصة غير متاحة',
    );
    expect(
      FoodPresentationLocalizer.servingText(
        amount: '1',
        unit: 'undetermined',
        localeTag: 'en',
      ),
      'Serving unavailable',
    );
    expect(
      FoodPresentationLocalizer.browseServingText(
        amount: '100',
        unit: 'undetermined',
        localeTag: 'ar',
      ),
      isNull,
    );
  });

  test('detail section labels are reviewed in all 25 locales', () {
    for (final tag in tags) {
      for (final key in const ['nutritionFacts', 'noAdditionalNutrients']) {
        final value = FoodPresentationLocalizer.label(key, tag);
        expect(value.trim(), isNotEmpty, reason: '$tag / $key');
        if (tag != 'en') {
          expect(
            value,
            isNot(FoodPresentationLocalizer.label(key, 'en')),
            reason: 'English fallback $tag / $key',
          );
        }
      }
    }
  });

  test('food result language always follows the selected app locale', () {
    expect(
      FoodPresentationLocalizer.resultLocaleForQuery(
        query: 'chicken',
        interfaceLocaleTag: 'ar',
      ),
      'ar',
    );
    expect(
      FoodPresentationLocalizer.resultLocaleForQuery(
        query: 'دجاج',
        interfaceLocaleTag: 'en',
      ),
      'en',
    );
    expect(
      FoodPresentationLocalizer.resultLocaleForQuery(
        query: '鸡肉',
        interfaceLocaleTag: 'ar',
      ),
      'ar',
    );
  });

  test('Search and Add Food UI copy has no English fallback in 25 locales', () {
    const keys = [
      'favorites',
      'recent',
      'popular',
      'servingSize',
      'servings',
      'time',
      'meal',
      'carbs',
      'fat',
      'protein',
      'quickAdd',
      'barcodeScan',
      'voiceLog',
      'mealScan',
      'add',
    ];
    for (final tag in tags) {
      for (final key in keys) {
        final english = dailyLogMealCopyForLocale(key, 'en');
        final localized = dailyLogMealCopyForLocale(key, tag);
        expect(localized.trim(), isNotEmpty, reason: '$tag / $key');
        expect(
          dailyLogMealHasReviewedCopy(key, tag),
          isTrue,
          reason: 'Missing reviewed copy $tag / $key ($english)',
        );
      }
    }
  });

  test('meal logging calls to action are native in all 25 locales', () {
    for (final tag in tags) {
      for (final source in const ['Log food', 'Log more']) {
        final value = RuntimeCopy.resolve(source, tag);
        expect(value, isNotNull, reason: '$tag / $source');
        expect(value!.trim(), isNotEmpty, reason: '$tag / $source');
        if (tag != 'en') {
          expect(
            value,
            isNot(source),
            reason: 'English fallback $tag / $source',
          );
        }
      }
    }

    final generated = File(
      'lib/app/localization/runtime_copy_extended.dart',
    ).readAsStringSync();
    for (final mistranslation in const [
      'Log-Essen',
      'غذای چوبی',
      '原木食物',
      'Бревенчатая еда',
      'Melden Sie sich mehr an',
      'Войти больше',
    ]) {
      expect(generated, isNot(contains(mistranslation)));
    }
  });

  test(
    'Search, Diary, and Detail all use the same safe presentation layer',
    () {
      final search = File(
        'lib/features/daily_log/daily_log_meal_search.dart',
      ).readAsStringSync();
      final diary = _librarySource(
        'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      );
      final detail = File(
        'lib/features/daily_log/daily_log_meal_entry.dart',
      ).readAsStringSync();
      expect(search, contains('FoodPresentationLocalizer.foodName('));
      expect(search, contains('FoodPresentationLocalizer.servingUnit('));
      expect(search, isNot(contains('_searchTab(')));
      expect(search, isNot(contains("'myMeals'")));
      expect(search, isNot(contains("'myRecipes'")));
      expect(search, isNot(contains("'myFoods'")));
      expect(search, isNot(contains("'all'")));
      expect(search, contains('FoodPresentationLocalizer.browseServingText('));
      expect(diary, contains('FoodPresentationLocalizer.foodName('));
      expect(diary, contains('FoodPresentationLocalizer.servingText('));
      expect(detail, contains('resultLocaleForQuery('));
      expect('$search\n$diary\n$detail', isNot(contains("'undetermined'")));
    },
  );

  test('Arabic popular browse never leaks an English catalog fallback', () {
    expect(
      FoodPresentationLocalizer.hasLocalizedBrowseName(
        name: 'Apples, dried, sulfured, uncooked',
        localeTag: 'ar',
        source: 'USDA FoodData Central',
      ),
      isFalse,
    );
    expect(
      FoodPresentationLocalizer.hasLocalizedBrowseName(
        name: 'Chicken breast, roasted, skinless',
        localeTag: 'ar',
        source: 'USDA FoodData Central',
      ),
      isTrue,
    );
    expect(
      FoodPresentationLocalizer.foodName(
        name: 'Chicken breast, roasted, skinless',
        localeTag: 'ar',
        source: 'USDA FoodData Central',
      ),
      isNot(contains('Chicken')),
    );
  });
}
