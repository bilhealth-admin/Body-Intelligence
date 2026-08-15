import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../repositories/active_catalog_registry.dart';
import '../repositories/composite_food_catalog_repository.dart';
import '../repositories/mobile_catalog_food_repository.dart';
import '../repositories/unified_food_repository.dart';
import '../repositories/usda_core_catalog_repository.dart';
import 'bundled_core_catalog_installer.dart';
import 'catalog_pack_manager.dart';

typedef CatalogRootResolver = Future<Directory> Function();

class ActiveMobileCatalogResolver {
  final CatalogRootResolver _rootResolver;
  final BundledCoreCatalogInstaller _installer;

  ActiveMobileCatalogResolver({
    CatalogRootResolver? rootResolver,
    this._installer = const BundledCoreCatalogInstaller(),
  }) : _rootResolver = rootResolver ?? getApplicationSupportDirectory;

  Future<UnifiedFoodRepository?> openIfAvailable() async {
    try {
      final root = await _rootResolver();
      await _installer.ensureInstalled(root);
      final catalog = await ActiveCatalogRegistry(root).resolveActiveCatalog();
      final repositories = <UnifiedFoodRepository>[
        _openCompatibleCatalog(catalog.path),
      ];
      final packs = await CatalogPackManager(
        rootResolver: () async => root,
      ).installed();
      for (final pack in packs) {
        if (pack.path == catalog.path) continue;
        try {
          repositories.add(_openCompatibleCatalog(pack.path));
        } on SqliteException {
          // A corrupt or incompatible optional pack must never disable core.
        } on StateError {
          // Schema validation is intentionally fail-closed per optional pack.
        }
      }
      return repositories.length == 1
          ? repositories.single
          : CompositeFoodCatalogRepository(repositories);
    } on FileSystemException {
      return null;
    } on StateError {
      return null;
    }
  }

  UnifiedFoodRepository _openCompatibleCatalog(String path) {
    final probe = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final rows = probe.select(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tables = rows.map((row) => row['name'] as String).toSet();
      if (tables.containsAll(const <String>{
        'foods',
        'food_fts',
        'portions',
        'search_alias',
      })) {
        return UsdaCoreCatalogRepository.open(path);
      }
      return MobileCatalogFoodRepository.open(path);
    } finally {
      probe.close();
    }
  }
}
