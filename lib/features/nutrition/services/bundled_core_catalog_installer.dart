import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'catalog_file_safety.dart';

class BundledCoreCatalogInstaller {
  const BundledCoreCatalogInstaller({this.bundle});

  final AssetBundle? bundle;
  static const assetPath = 'assets/catalogs/bil_food_core.sqlite';
  static const catalogVersion = 'usda-core-2026-04-v2-magnesium';
  static const expectedSizeBytes = 32010240;
  static const expectedSha256 =
      '2801A24BC8E53BC5724BA9A73A1A9262410C71A1E4128C7F59902D8E4D4EBA83';

  // A verified immutable bundled catalog can be reused while its file identity
  // stays unchanged. Owner rows/results are never held in this shared cache.
  static final _verifiedFiles = <String, _VerifiedCatalogStamp>{};
  static final _installing = <String, Future<File>>{};

  Future<File> ensureInstalled(Directory root) async {
    await root.create(recursive: true);
    final rootPath = await root.resolveSymbolicLinks();
    final inFlight = _installing[rootPath];
    if (inFlight != null) return inFlight;
    final installation = _ensureInstalled(Directory(rootPath));
    _installing[rootPath] = installation;
    try {
      return await installation;
    } finally {
      if (identical(_installing[rootPath], installation)) {
        _installing.remove(rootPath);
      }
    }
  }

  Future<File> _ensureInstalled(Directory root) async {
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
    final before = await file.stat();
    if (before.type != FileSystemEntityType.file ||
        before.size != expectedSizeBytes) {
      _verifiedFiles.remove(file.path);
      return false;
    }
    if (_verifiedFiles[file.path]?.matches(before) ?? false) return true;

    // Never cache an unverified file or a file changed during the digest read.
    final digest = await sha256.bind(file.openRead()).first;
    final after = await file.stat();
    final stamp = _VerifiedCatalogStamp.fromStat(before);
    if (digest.toString() != expectedSha256.toLowerCase() ||
        !stamp.matches(after)) {
      _verifiedFiles.remove(file.path);
      return false;
    }
    if (_verifiedFiles.length >= 8) {
      _verifiedFiles.remove(_verifiedFiles.keys.first);
    }
    _verifiedFiles[file.path] = stamp;
    return true;
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
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    if (await registry.exists() &&
        await registry.length() == utf8.encode(encoded).length &&
        await registry.readAsString() == encoded) {
      return;
    }
    await temporary.writeAsString(encoded, flush: true);
    await replaceCatalogFile(temporary, registry);
  }
}

final class _VerifiedCatalogStamp {
  const _VerifiedCatalogStamp(
    this.size,
    this.modified,
    this.changed,
    this.mode,
  );

  factory _VerifiedCatalogStamp.fromStat(FileStat stat) =>
      _VerifiedCatalogStamp(stat.size, stat.modified, stat.changed, stat.mode);

  final int size;
  final DateTime modified;
  final DateTime changed;
  final int mode;

  bool matches(FileStat stat) =>
      stat.type == FileSystemEntityType.file &&
      stat.size == size &&
      stat.modified == modified &&
      stat.changed == changed &&
      stat.mode == mode;
}
