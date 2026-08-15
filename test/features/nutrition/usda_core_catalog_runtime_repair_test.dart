import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USDA Core adapter imports the project search hit contract', () {
    final repository = File(
      'lib/features/nutrition/repositories/usda_core_catalog_repository.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/features/nutrition/services/active_mobile_catalog_resolver.dart',
    ).readAsStringSync();

    expect(
      repository,
      contains("import '../services/offline_food_search_pipeline.dart';"),
    );
    expect(repository, contains('this._ownsDatabase = false'));
    expect(resolver, contains('this._installer = const'));
    expect(repository, contains('Future<List<FoodSearchHit>> searchUnified'));
  });
}
