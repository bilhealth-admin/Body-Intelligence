import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';

Future<void> main() async {
  final repository = UsdaCoreCatalogRepository.open('assets/catalogs/bil_food_core.sqlite');
  const queries = [
    'egg whole hard boiled','spinach raw','rice white long grain cooked','corn sweet yellow cooked','peas edible podded raw'
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
