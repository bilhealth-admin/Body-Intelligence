import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class BundledCoreCatalogInstaller {
  const BundledCoreCatalogInstaller();
  static const assetPath = 'assets/catalogs/bil_food_core.sqlite';
  static const catalogVersion = 'usda-core-2026-04-v1';
  static const expectedSizeBytes = 31059968;
  static const expectedSha256 =
      '9E6AB0C9BE242A5EDCF35D4E1F0391A321585636190628F9138A0845918A1D85';

  Future<File> ensureInstalled(Directory root) async {
    final catalogsRoot = Directory(p.join(root.path, 'catalogs'));
    final versionRoot = Directory(p.join(catalogsRoot.path, catalogVersion));
    final catalog = File(p.join(versionRoot.path, 'bil_food_core.sqlite'));

    if (await catalog.exists() && await catalog.length() == expectedSizeBytes) {
      await _writeRegistry(root, catalog);
      return catalog;
    }

    await versionRoot.create(recursive: true);
    final temporary = File('${catalog.path}.installing');
    if (await temporary.exists()) await temporary.delete();

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length != expectedSizeBytes) {
      throw StateError(
        'Bundled USDA Core size mismatch: '
        'expected=$expectedSizeBytes actual=${bytes.length}',
      );
    }

    await temporary.writeAsBytes(bytes, flush: true);
    if (await catalog.exists()) await catalog.delete();
    await temporary.rename(catalog.path);
    await _writeRegistry(root, catalog);
    return catalog;
  }

  Future<void> _writeRegistry(Directory root, File catalog) async {
    final registry = File(p.join(root.path, 'catalog_registry.json'));
    final temporary = File('${registry.path}.writing');
    final payload = <String, Object?>{
      'schema_version': 1,
      'active': <String, Object?>{
        'path': catalog.path,
        'catalog_version': catalogVersion,
        'catalog_role': 'offline_core',
        'sha256': expectedSha256,
        'size_bytes': expectedSizeBytes,
      },
    };
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    if (await registry.exists()) await registry.delete();
    await temporary.rename(registry.path);
  }
}
