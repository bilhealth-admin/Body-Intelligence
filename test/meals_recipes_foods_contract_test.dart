import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition shell exposes real meals recipes and food CRUD', () {
    final source = [
      'lib/features/nutrition/presentation/meals_recipes_foods_page.dart',
      'lib/features/nutrition/presentation/meals_tab.dart',
      'lib/features/nutrition/presentation/recipes_tab.dart',
      'lib/features/nutrition/presentation/meals_recipes_components.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    for (final contract in const [
      "Key('my-meals-tab')",
      "Key('my-recipes-tab')",
      'FoodPage(embedded: true, userOwnedOnly: true)',
      'usualMealsProvider',
      'createTemplateFromHistoricalMeal',
      'instantiateTemplate',
      "context.push('/wellness/recipes')",
      "context.push('/nutrition/recipes/import?recipeId=\${savedRecipe.id}')",
      "value: '_edit'",
      "value: '_delete'",
      'trustedRecipeRepositoryProvider).delete(savedRecipe.id)',
      'TrustedRecipeDiaryService(',
    ]) {
      expect(source, contains(contract));
    }
    expect(router, contains("path: '/nutrition'"));
    expect(router, contains('const MealsRecipesFoodsPage()'));
    expect(router, contains("path: '/foods'"));
    for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale':"));
    }
    for (final localizedAction in const [
      "'edit'",
      "'delete'",
      "'deleteTitle'",
      "'deleteBody'",
      "'cancel'",
      "'deleted'",
    ]) {
      expect(
        RegExp(RegExp.escape(localizedAction)).allMatches(source),
        hasLength(greaterThanOrEqualTo(5)),
      );
    }
  });

  test('food page supports embedding without removing standalone CRUD', () {
    final food = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    expect(food, contains('this.embedded = false'));
    expect(food, contains('widget.embedded'));
    expect(food, contains('FloatingActionButton.extended'));
    expect(food, contains('_createFood'));
  });

  test('saved nutrition surface has explicit copy for all 25 locales', () {
    const authored = <String>{'en', 'ar', 'fr', 'es', 'tr'};
    const keys = <String>[
      'My nutrition',
      'My meals',
      'My recipes',
      'My foods',
      'Create meal',
      'Copy previous meal',
      'Build your recipe collection',
      'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.',
      'Saved recipes could not be loaded.',
      'Calculated nutrition with sources is required before logging.',
      'Add a recipe',
    ];
    for (final tag in BilLocalePolicy.productionTags) {
      if (authored.contains(tag)) continue;
      for (final english in keys) {
        final translated = RuntimeCopy.resolve(english, tag);
        expect(translated, isNotNull, reason: '$tag: $english');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $english');
      }
    }
  });
}
