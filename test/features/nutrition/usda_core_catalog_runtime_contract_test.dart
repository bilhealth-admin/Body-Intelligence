import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USDA Core runtime is bundled and activated', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final resolver = File(
      'lib/features/nutrition/services/active_mobile_catalog_resolver.dart',
    ).readAsStringSync();
    final installer = File(
      'lib/features/nutrition/services/bundled_core_catalog_installer.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/nutrition/repositories/usda_core_catalog_repository.dart',
    ).readAsStringSync();

    expect(pubspec, contains('assets/catalogs/bil_food_core.sqlite'));
    expect(resolver, contains('ensureInstalled(root)'));
    expect(resolver, contains('UsdaCoreCatalogRepository.open(path)'));
    expect(installer, contains('catalog_registry.json'));
    expect(installer, contains('usda-core-2026-04-v1'));
    expect(repository, contains('search_alias'));
    expect(repository, contains('food_fts MATCH ?'));
    expect(repository, contains('arabic-query-expansion'));
  });
}
