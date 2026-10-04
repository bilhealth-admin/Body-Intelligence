import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/domain/catalog_pack.dart';
import 'package:body_intelligence_log/features/nutrition/services/catalog_pack_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manifest contract rejects traversal, insecure URLs, and invalid integrity metadata',
    () {
      final valid = <String, dynamic>{
        'id': 'usda-core',
        'version': '2026.08',
        'title': 'USDA core',
        'download_url': 'https://downloads.example.com/catalog.sqlite',
        'sha256': 'a' * 64,
        'size_bytes': 100,
        'access': 'plus',
      };
      for (final patch in <Map<String, dynamic>>[
        {'id': '../outside'},
        {'version': '..'},
        {'id': r'C:\outside'},
        {'download_url': 'http://downloads.example.com/catalog.sqlite'},
        {
          'download_url':
              'https://user:password@downloads.example.com/catalog.sqlite',
        },
        {'download_url': 'file:///outside.sqlite'},
        {'sha256': 'invalid'},
        {'size_bytes': -1},
        {'size_bytes': CatalogPack.maximumDownloadBytes + 1},
        {'compression': 'zip'},
        {'compression': 'gzip'},
      ]) {
        expect(
          () => CatalogPack.fromJson({...valid, ...patch}),
          throwsFormatException,
          reason: patch.toString(),
        );
      }
    },
  );

  test(
    'default manager rejects plaintext even for direct constructor callers',
    () async {
      final root = await _root();
      await expectLater(
        CatalogPackManager(
          rootResolver: () async => root,
        ).install(_pack(Uri.parse('http://127.0.0.1:1/catalog'), [1])),
        throwsFormatException,
      );
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('redirect response is rejected without requesting its target', () async {
    final root = await _root();
    var targetRequests = 0;
    final server = await _server((request) async {
      if (request.uri.path == '/target') targetRequests++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/target');
      await request.response.close();
    });
    await expectLater(
      _manager(root).install(_pack(_url(server), [1])),
      throwsA(isA<HttpException>()),
    );
    expect(targetRequests, 0);
    expect(await _manager(root).installed(), isEmpty);
  });

  test('chunked stream cannot write beyond its declared size', () async {
    final root = await _root();
    final server = await _server((request) async {
      request.response.add(List.filled(4096, 1));
      await request.response.close();
    });
    await expectLater(
      _manager(root).install(_pack(_url(server), [1, 1])),
      throwsStateError,
    );
    expect(await _manager(root).installed(), isEmpty);
    expect(
      await root.list(recursive: true).where((entry) => entry is File).toList(),
      isEmpty,
    );
  });

  test(
    'stalled payload is cancelled, timed out, and leaves no temporary file',
    () async {
      final root = await _root();
      final server = await _server((request) async {
        request.response.add([1]);
        await request.response.flush();
      });
      final manager = CatalogPackManager(
        rootResolver: () async => root,
        allowLoopbackHttpForTesting: true,
        transferTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        manager.install(_pack(_url(server), [1, 2])),
        throwsA(isA<TimeoutException>()),
      );
      expect(
        await root
            .list(recursive: true)
            .where((entry) => entry is File)
            .toList(),
        isEmpty,
      );
    },
  );

  test('manifest payload is bounded before decoding', () async {
    final root = await _root();
    final server = await _server((request) async {
      request.response.add(
        List.filled(CatalogPackManager.maximumManifestBytes + 1, 32),
      );
      await request.response.close();
    });
    final manager = CatalogPackManager(
      rootResolver: () async => root,
      allowLoopbackHttpForTesting: true,
      manifestUrlOverride: _url(server).toString(),
    );
    await expectLater(manager.fetchAvailable(), throwsFormatException);
  });

  test(
    'gzip expansion is bounded and a failed replacement retains verified data',
    () async {
      final root = await _root();
      final original = utf8.encode(
        'SQLite format 3\u0000previous verified catalog',
      );
      final expanded = List.filled(4096, 9);
      final compressed = gzip.encode(expanded);
      List<int> payload = original;
      final server = await _server((request) async {
        request.response.add(payload);
        await request.response.close();
      });
      final manager = _manager(root);
      final installed = await manager.install(_pack(_url(server), original));
      payload = compressed;
      final replacement = CatalogPack(
        id: 'verified',
        version: '1',
        title: 'Verified',
        downloadUri: _url(server),
        sha256: sha256.convert(compressed).toString(),
        sizeBytes: compressed.length,
        access: CatalogPackAccess.plus,
        compression: 'gzip',
        installedSizeBytes: 2,
        databaseSha256: sha256.convert([9, 9]).toString(),
      );
      await expectLater(manager.install(replacement), throwsStateError);
      expect(await File(installed.path).readAsBytes(), original);
      expect((await manager.installed()).single.path, installed.path);
    },
  );

  test('registry path injection cannot be loaded or deleted', () async {
    final root = await _root();
    final outside = File('${root.path}.outside.sqlite');
    await outside.writeAsBytes([7, 8, 9]);
    addTearDown(() => outside.delete());
    await File('${root.path}/catalog_packs.json').writeAsString(
      jsonEncode({
        'packs': [
          {
            'id': 'verified',
            'version': '1',
            'path': outside.path,
            'size_bytes': 3,
            'installed_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      }),
    );
    final manager = _manager(root);
    expect(await manager.installed(), isEmpty);
    await expectLater(
      manager.remove(
        InstalledCatalogPack(
          id: 'verified',
          version: '1',
          path: outside.path,
          sizeBytes: 3,
          installedAt: DateTime.now(),
        ),
      ),
      throwsStateError,
    );
    expect(await outside.readAsBytes(), [7, 8, 9]);
  });

  test(
    'concurrent installs serialize their durable registry updates',
    () async {
      final root = await _root();
      final bytes = [1, 2, 3];
      final server = await _server((request) async {
        request.response.add(bytes);
        await request.response.close();
      });
      final manager = _manager(root);
      await Future.wait([
        manager.install(_pack(_url(server), bytes)),
        _manager(root).install(_pack(_url(server), bytes, id: 'second')),
      ]);
      expect(
        (await manager.installed()).map((pack) => pack.id),
        containsAll(['verified', 'second']),
      );
    },
  );
}

Future<Directory> _root() async {
  final root = await Directory.systemTemp.createTemp('bil_catalog_security_');
  addTearDown(() => root.delete(recursive: true));
  return root;
}

Future<HttpServer> _server(Future<void> Function(HttpRequest) respond) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await respond(request);
    } on HttpException {
      /* Client cancellation is intentional. */
    }
  });
  addTearDown(() => server.close(force: true));
  return server;
}

Uri _url(HttpServer server) =>
    Uri.parse('http://127.0.0.1:${server.port}/catalog');
CatalogPackManager _manager(Directory root) => CatalogPackManager(
  rootResolver: () async => root,
  allowLoopbackHttpForTesting: true,
);
CatalogPack _pack(Uri uri, List<int> bytes, {String id = 'verified'}) =>
    CatalogPack(
      id: id,
      version: '1',
      title: 'Verified',
      downloadUri: uri,
      sha256: sha256.convert(bytes).toString(),
      sizeBytes: bytes.length,
      access: CatalogPackAccess.plus,
    );
