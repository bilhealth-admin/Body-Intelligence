import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/domain/catalog_pack.dart';
import 'package:body_intelligence_log/features/nutrition/services/catalog_pack_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog contract accepts the Plus access tier', () {
    final pack = CatalogPack.fromJson(const <String, dynamic>{
      'id': 'usda-core',
      'version': '2026.08',
      'title': 'USDA core',
      'download_url': 'https://downloads.example.com/usda.sqlite',
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'size_bytes': 1024,
      'access': 'plus',
    });
    expect(pack.access, CatalogPackAccess.plus);
  });

  test('catalog pack install verifies bytes and persists registry', () async {
    final root = await Directory.systemTemp.createTemp('bil_catalog_pack_');
    final bytes = <int>[1, 2, 3, 4, 5, 6];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(bytes);
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    final pack = CatalogPack(
      id: 'world-branded',
      version: '1',
      title: 'World branded foods',
      downloadUri: Uri.parse('http://127.0.0.1:${server.port}/catalog.sqlite'),
      sha256: sha256.convert(bytes).toString(),
      sizeBytes: bytes.length,
      access: CatalogPackAccess.pro,
    );
    final manager = CatalogPackManager(rootResolver: () async => root);

    final installed = await manager.install(pack);
    expect(await File(installed.path).readAsBytes(), bytes);
    expect((await manager.installed()).single.id, 'world-branded');

    await manager.remove(installed);
    expect(await manager.installed(), isEmpty);
  });

  test('catalog pack rejects a payload with the wrong hash', () async {
    final root = await Directory.systemTemp.createTemp('bil_catalog_pack_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(const <int>[9, 9, 9]);
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    final manager = CatalogPackManager(rootResolver: () async => root);
    final pack = CatalogPack(
      id: 'tampered',
      version: '1',
      title: 'Tampered',
      downloadUri: Uri.parse('http://127.0.0.1:${server.port}/catalog.sqlite'),
      sha256: sha256.convert(const <int>[1, 2, 3]).toString(),
      sizeBytes: 3,
      access: CatalogPackAccess.pro,
    );

    await expectLater(manager.install(pack), throwsStateError);
    expect(await manager.installed(), isEmpty);
  });

  test('gzip catalog is streamed, expanded, and verified', () async {
    final root = await Directory.systemTemp.createTemp('bil_catalog_gzip_');
    final databaseBytes = utf8.encode('SQLite format 3\u0000verified catalog');
    final compressedBytes = gzip.encode(databaseBytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(compressedBytes);
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    final manager = CatalogPackManager(rootResolver: () async => root);
    final pack = CatalogPack(
      id: 'usda-core',
      version: '2026.08',
      title: 'USDA verified core',
      downloadUri: Uri.parse('http://127.0.0.1:${server.port}/usda.sqlite.gz'),
      sha256: sha256.convert(compressedBytes).toString(),
      sizeBytes: compressedBytes.length,
      access: CatalogPackAccess.plus,
      compression: 'gzip',
      installedSizeBytes: databaseBytes.length,
      databaseSha256: sha256.convert(databaseBytes).toString(),
    );

    final installed = await manager.install(pack);

    expect(await File(installed.path).readAsBytes(), databaseBytes);
    expect(installed.sizeBytes, databaseBytes.length);
    expect(File('${installed.path}.download').existsSync(), isFalse);
  });

  test('production catalog manifest is configured by default', () {
    final manager = CatalogPackManager();

    expect(manager.downloadsConfigured, isTrue);
    expect(
      CatalogPackManager.manifestUrl,
      CatalogPackManager.productionManifestUrl,
    );
  });
}
