import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String between(String value, String start, String end) {
  final startIndex = value.indexOf(start);
  final endIndex = value.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  expect(
    endIndex,
    greaterThan(startIndex),
    reason: 'Missing $end after $start',
  );
  return value.substring(startIndex, endIndex);
}

void main() {
  group('IMG_6450-6459 reference acceptance', () {
    test(
      'Today keeps calories first and one compact carbs-fat-protein deck',
      () {
        final phone = source(
          'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
        );
        final calories = phone.indexOf('_ReferenceCaloriesCard(');
        final macros = phone.indexOf('_ReferenceMacrosCard(');

        expect(calories, greaterThanOrEqualTo(0));
        expect(macros, greaterThan(calories));
        final macroDeck = between(
          phone.substring(macros),
          '_ReferenceMacrosCard(',
          'overviewCards.add(',
        );
        expect(macroDeck.indexOf("label: tr('Carbs'"), greaterThanOrEqualTo(0));
        expect(
          macroDeck.indexOf("label: tr('Fat'"),
          greaterThan(macroDeck.indexOf("label: tr('Carbs'")),
        );
        expect(
          macroDeck.indexOf("label: tr('Protein'"),
          greaterThan(macroDeck.indexOf("label: tr('Fat'")),
        );
        expect(phone, contains('_OverviewCardsCarousel('));
        expect(phone, contains('cards: overviewCards'));
      },
    );

    test('Diary summary and food rows stay intentionally compact', () {
      final page = source('lib/features/daily_log/daily_log_page.dart');
      final meals = [
        'lib/features/daily_log/presentation/daily_log_meals_list.dart',
        'lib/features/daily_log/presentation/daily_log_meal_detail_items.dart',
      ].map(source).join('\n');
      final row = between(
        meals,
        'class _DiaryFoodRow',
        'class _DiaryEmptyMeals',
      );

      expect(page, contains("Key('daily-log-today-summary')"));
      expect(page, contains("Key('daily-log-action-copy')"));
      expect(page, contains("Key('daily-log-action-edit')"));
      expect(row, contains('final serving = _servingText('));
      expect(row, contains('item.calories.round().toString()'));
      expect(row, isNot(contains('food.source')));
      expect(row, isNot(contains('Nutrition Facts')));
      expect(row, isNot(contains('MealItemEvidencePresenter')));
    });

    test(
      'Food Search stays focused while global Quick Add owns capture tools',
      () {
        final search = source(
          'lib/features/daily_log/daily_log_meal_search.dart',
        );
        final diary = [
          'lib/features/daily_log/daily_log_page.dart',
          'lib/features/daily_log/daily_log_navigation_actions.dart',
        ].map(source).join('\n');
        final shell = source('lib/app/router/responsive_app_shell.dart');
        final tile = between(
          search,
          'Widget _mealSearchFoodTile',
          'String _displayFoodName',
        );

        for (final removedTab in const [
          'all',
          'myMeals',
          'myRecipes',
          'myFoods',
        ]) {
          expect(
            search,
            isNot(contains("_mealCopy('$removedTab')")),
            reason: 'removed tab $removedTab',
          );
        }
        for (final tool in const [
          'barcodeScan',
          'voiceLog',
          'mealScan',
          'quickAdd',
        ]) {
          expect(
            search,
            isNot(contains("_mealCopy('$tool')")),
            reason: 'Focused meal search must not duplicate global tool $tool',
          );
        }
        expect(shell, contains("'/daily-log?action=barcode&from=\$origin'"));
        expect(shell, contains("'/daily-log?action=voice&from=\$origin'"));
        expect(shell, contains("'/daily-log?action=photo&from=\$origin'"));
        expect(diary, contains("case 'barcode':"));
        expect(diary, contains('await _scanBarcode();'));
        expect(diary, contains("case 'voice':"));
        expect(diary, contains('await _captureMealVoice();'));
        expect(diary, contains("case 'photo':"));
        expect(diary, contains('await _analyzeMealImage();'));
        expect(tile, contains('food.calories.round()'));
        expect(tile, contains('servingSize'));
        expect(tile, isNot(contains('food.protein')));
        expect(tile, isNot(contains('food.carbs')));
        expect(tile, isNot(contains('food.fats')));
        expect(tile, isNot(contains('food.source')));
        expect(tile, isNot(contains('verifiedSource')));
      },
    );

    test('Add Food owns controls, calorie macros, then Nutrition Facts', () {
      final entry = source('lib/features/daily_log/daily_log_meal_entry.dart');
      final details = between(
        entry,
        'Widget _selectedFoodNutritionPreview',
        'class _NutritionFactRow',
      );

      final serving = details.indexOf("_mealCopy('servingSize')");
      final unit = details.indexOf(
        "for (final unit in const ['g', 'oz', 'kg', 'lb'])",
      );
      final ring = details.indexOf('DailyLogCalorieMacroRing(');
      final facts = details.indexOf("Key('daily-log-nutrition-facts')");
      expect(serving, greaterThanOrEqualTo(0));
      expect(unit, greaterThan(serving));
      expect(ring, greaterThan(unit));
      expect(facts, greaterThan(ring));
      expect(details, contains("Key('daily-log-nutrition-facts')"));
    });

    test('Water is a focused route instead of a full inline diary editor', () {
      final router = source('lib/app/router/app_router.dart');
      final shell = source('lib/app/router/responsive_app_shell.dart');
      final diary = [
        'lib/features/daily_log/daily_log_page.dart',
        'lib/features/daily_log/daily_log_navigation_actions.dart',
      ].map(source).join('\n');
      final water = source('lib/features/daily_log/daily_water_page.dart');

      expect(router, contains("path: '/daily-log/water'"));
      expect(
        shell,
        isNot(contains("context.go('/daily-log/water?from=\$origin')")),
      );
      expect(diary, contains("context.go('/daily-log/water?from=\$origin')"));
      expect(diary, contains('DailyWaterShortcut('));
      expect(diary, isNot(contains('DailyWaterSection(')));
      expect(water, contains("Key('daily-water-page')"));
      expect(water, contains('DailyWaterSection('));
      expect(water, contains('PopScope('));
    });

    test('Progress navigation exposes reference nutrition tabs and content', () {
      final shell = source('lib/app/router/responsive_app_shell.dart');
      final router = source('lib/app/router/app_router.dart');
      final analytics = source(
        'lib/features/analytics/nutrition_analytics_page.dart',
      );

      expect(
        shell,
        contains("'/history'"),
        reason:
            'The Progress destination must open the dedicated Progress surface.',
      );
      expect(router, contains("path: '/analytics/nutrition'"));
      expect(analytics, contains('DefaultTabController('));
      expect(analytics, contains("Tab(text: _t(context, 'Calories'))"));
      expect(analytics, contains("Tab(text: _t(context, 'Nutrients'))"));
      expect(analytics, contains("Tab(text: _t(context, 'Macros'))"));
      expect(analytics, contains('_CaloriesTab('));
      expect(analytics, contains('_NutrientsTab('));
      expect(analytics, contains('_MacrosTab('));
    });
  });

  group('plans and premium route acceptance', () {
    test('Plans keeps a crown and metadata-backed store truth', () {
      final plans = source(
        'lib/features/commerce/presentation/bil_store_plans_page.dart',
      );
      final components = source(
        'lib/features/commerce/presentation/bil_dynamic_store_components.dart',
      );
      final offers = source(
        'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
      );
      final copy = source(
        'lib/features/commerce/presentation/bil_store_copy.dart',
      );

      expect(plans, contains('BilDynamicStoreOffers('));
      expect(components, contains('PremiumCrownEmblem('));
      expect(copy, contains("'premium': 'Premium'"));
      expect(copy, contains("'premium_ai_coach': 'AI Coach'"));
      expect(copy, isNot(contains("'premium_ai_coach': 'Premium + AI Coach'")));
      expect(copy, contains("'trial_7_days': '7 days free'"));
      expect(copy, contains("'premium_benefit_trial'"));
      expect(offers, contains('offer.trialEligible == true'));
      expect(
        offers,
        contains("const {'P1W', 'P7D'}.contains(offer.trialPeriodIso8601)"),
      );
      expect(
        offers,
        contains("const {'P1M', 'P1Y'}.contains(offer.billingPeriodIso8601)"),
      );
    });

    test('route glass paints real content, blurs it, and blocks its input', () {
      final glass = source(
        'lib/features/commerce/presentation/premium_route_glass_gate.dart',
      );

      expect(glass, contains('AbsorbPointer('));
      expect(glass, contains('BackdropFilter('));
      expect(glass, contains('ImageFilter.blur(sigmaX: 8, sigmaY: 8)'));
      expect(glass, contains('PremiumCrownEmblem('));
      expect(glass, contains("ValueKey('premium-route-upgrade-cta')"));
      expect(glass, isNot(contains('ImageFiltered(')));
      expect(glass, isNot(contains('Opacity(')));
    });
  });
}
