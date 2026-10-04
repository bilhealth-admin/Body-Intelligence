import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'catalog_file_safety.dart';

class BundledCoreCatalogInstaller {
  const BundledCoreCatalogInstaller({this.bundle});

  final AssetBundle? bundle;
  static const assetPath = 'assets/catalogs/bil_food_core.sqlite';
  static const catalogVersion = 'usda-core-2026-04-v1';
  static const expectedSizeBytes = 31059968;
  static const expectedSha256 =
      '9E6AB0C9BE242A5EDCF35D4E1F0391A321585636190628F9138A0845918A1D85';

  Future<File> ensureInstalled(Directory root) async {
    final catalog = await safeCatalogFile(root, [
      'catalogs',
      catalogVersion,
      'bil_food_core.sqlite',
    ], createParents: true);

    if (await _verified(catalog)) {
      await _writeRegistry(root, catalog);
      return catalog;
    }

    final temporary = await safeCatalogFile(root, [
      'catalogs',
      catalogVersion,
      'bil_food_core.sqlite.installing',
    ]);
    if (await temporary.exists()) await temporary.delete();

    final data = await (bundle ?? rootBundle).load(assetPath);
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

    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (!await _verified(temporary)) {
        throw StateError('Bundled USDA Core integrity mismatch');
      }
      await replaceCatalogFile(temporary, catalog);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    await _writeRegistry(root, catalog);
    return catalog;
  }

  Future<bool> _verified(File file) async {
    if (!await file.exists() || await file.length() != expectedSizeBytes) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expectedSha256.toLowerCase();
  }

  Future<void> _writeRegistry(Directory root, File catalog) async {
    final registry = await safeCatalogFile(root, ['catalog_registry.json']);
    final temporary = await safeCatalogFile(root, [
      'catalog_registry.json.writing',
    ]);
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
    await replaceCatalogFile(temporary, registry);
  }
}
