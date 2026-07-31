import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ActiveCatalogRegistry {
  final Directory root;
  const ActiveCatalogRegistry(this.root);

  File get registryFile => File(p.join(root.path, 'catalog_registry.json'));

  Future<File> resolveActiveCatalog() async {
    if (!await registryFile.exists()) {
      throw StateError('BIL catalog registry is missing: ${registryFile.path}');
    }
    final decoded = jsonDecode(await registryFile.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['active'] is! Map<String, dynamic>) {
      throw StateError('BIL catalog registry has no active catalog');
    }
    final active = decoded['active'] as Map<String, dynamic>;
    final rawPath = active['path'];
    if (rawPath is! String || rawPath.trim().isEmpty) {
      throw StateError('BIL catalog registry active path is invalid');
    }
    final catalog = File(rawPath);
    if (!await catalog.exists()) {
      throw StateError('BIL active catalog is missing: ${catalog.path}');
    }
    return catalog;
  }
}
