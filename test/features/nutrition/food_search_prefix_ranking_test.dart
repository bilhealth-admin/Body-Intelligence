import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_food_search_pipeline.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_search_text_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pipeline = OfflineFoodSearchPipeline();
  const matcher = FoodSearchTextMatcher();

  test('ranking is exact then phrase prefix then word prefix then keyword', () {
    final matches = <FoodSearchTextMatch>[
      matcher.match(query: 'app', primaryName: 'App'),
      matcher.match(query: 'app', primaryName: 'Apple Fuji'),
      matcher.match(query: 'app', primaryName: 'Green Apple'),
      matcher.match(
        query: 'app',
        primaryName: 'Starter',
        keywords: const <String>['appetizer'],
      ),
    ];

    expect(matches.map((match) => match.tier), <FoodSearchTextMatchTier>[
      FoodSearchTextMatchTier.exact,
      FoodSearchTextMatchTier.primaryPhrasePrefix,
      FoodSearchTextMatchTier.wordPrefix,
      FoodSearchTextMatchTier.keywordOrContains,
    ]);
    expect(
      matches.map((match) => match.rank),
      orderedEquals(<int>[4, 3, 2, 1]),
    );
  });

  test('completed apple token never admits Applebees as a substring', () {
    final hits = pipeline.search(
      foods: <UnifiedFood>[
        _food(id: 'apple', name: 'Apple'),
        _food(id: 'apples', name: 'Apples Fuji'),
        _food(id: 'applebees', name: 'Applebees Bacon'),
      ],
      query: 'apple',
    );

    expect(hits.map((hit) => hit.food.id), <String>['apple', 'apples']);
  });

  test('unlisted complete food token suppresses a longer brand token', () {
    final foods = <UnifiedFood>[
      _food(id: 'pear', name: 'Pear'),
      _food(id: 'pearl', name: 'Pearl barley'),
    ];

    expect(
      pipeline.search(foods: foods, query: 'pea').map((hit) => hit.food.id),
      <String>['pear', 'pearl'],
    );
    expect(
      pipeline.search(foods: foods, query: 'pear').map((hit) => hit.food.id),
      <String>['pear'],
    );
  });

  test('English search remains discoverable through every typed prefix', () {
    final apple = _food(id: 'apple', name: 'Apple');
    for (final query in const ['a', 'ap', 'app', 'appl', 'apple']) {
      final hits = pipeline.search(foods: <UnifiedFood>[apple], query: query);
      expect(hits.single.food.id, 'apple', reason: query);
      expect(
        hits.single.reasons,
        contains(
          query == 'apple'
              ? 'primary-name-exact'
              : 'primary-name-phrase-prefix',
        ),
        reason: query,
      );
    }
  });

  test('Arabic search remains discoverable through every typed prefix', () {
    final apple = _food(id: 'apple', name: 'Apple', arabicName: 'تفاح');
    for (final query in const ['ت', 'تف', 'تفا', 'تفاح']) {
      final hits = pipeline.search(foods: <UnifiedFood>[apple], query: query);
      expect(hits.single.food.id, 'apple', reason: query);
      expect(
        hits.single.reasons,
        contains(
          query == 'تفاح' ? 'arabic-name-exact' : 'arabic-name-phrase-prefix',
        ),
        reason: query,
      );
    }
  });

  test('non-Latin search preserves every Cyrillic prefix', () {
    final apple = _food(id: 'apple-ru', name: 'яблоко');
    for (final query in const ['я', 'яб', 'ябл', 'ябло', 'яблок', 'яблоко']) {
      final hits = pipeline.search(foods: <UnifiedFood>[apple], query: query);
      expect(hits.single.food.id, 'apple-ru', reason: query);
    }
  });

  test(
    'each additional prefix narrows candidates without a dead keystroke',
    () {
      final foods = <UnifiedFood>[
        _food(id: 'apple', name: 'Apple'),
        _food(id: 'apricot', name: 'Apricot'),
        _food(id: 'avocado', name: 'Avocado'),
        _food(id: 'banana', name: 'Banana'),
      ];
      final counts = <int>[
        for (final query in const ['a', 'ap', 'app', 'appl', 'apple'])
          pipeline.search(foods: foods, query: query).length,
      ];

      expect(counts, <int>[3, 2, 1, 1, 1]);
    },
  );
}

UnifiedFood _food({
  required String id,
  required String name,
  String? arabicName,
  List<String> keywords = const <String>[],
}) {
  return UnifiedFood(
    id: id,
    name: name,
    arabicName: arabicName,
    category: 'food',
    keywords: keywords,
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients: const <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: NutrientAmount.known(52),
      FoodNutrient.protein: NutrientAmount.known(.3),
      FoodNutrient.carbohydrates: NutrientAmount.known(14),
      FoodNutrient.fat: NutrientAmount.known(.2),
    },
    source: FoodDataSource.foundation,
    sourceLabel: 'test',
    verified: true,
    isCustom: false,
  );
}
