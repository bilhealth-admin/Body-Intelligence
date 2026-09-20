import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';

Future<void> main() async {
  final repository = UsdaCoreCatalogRepository.open(
    'assets/catalogs/bil_food_core.sqlite',
  );
  const queries = <String>[
    'water tap drinking',
    'apples raw with skin',
    'almonds raw',
    'eggs whole raw fresh',
    'lemons raw without peel',
    'rice brown long grain cooked',
    'lentils raw',
    'lentils red raw',
    'onions raw',
    'carrots raw',
    'cumin seed',
    'yogurt plain whole milk',
    'oats rolled',
    'chickpeas cooked',
    'tomatoes raw',
    'cucumber raw',
    'parsley fresh',
    'lemon juice raw',
    'eggs whole raw',
    'cod cooked dry heat',
    'zucchini raw',
    'chicken breast cooked',
    'cabbage raw',
    'lentils cooked',
    'spinach raw',
    'sesame butter tahini',
    'bread pita',
    'quinoa cooked',
  ];
  for (final query in queries) {
    final hits = await repository.searchUnified(query, limit: 3);
    print('\n$query');
    for (final hit in hits) {
      print('${hit.food.id}\t${hit.food.name}\tverified=${hit.food.verified}');
    }
  }
  repository.close();
}
// ignore_for_file: avoid_print
