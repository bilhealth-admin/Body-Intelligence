// Exercise real HTTP content negotiation independently of catalog file hashes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/services/catalog_pack_manager.dart';
import 'package:flutter_test/flutter_test.dart';

final _manifestBytes = utf8.encode(
  jsonEncode({
    'packs': [
      {
        'id': 'verified-core',
        'version': '1',
        'title': 'Verified core',
        'download_url': 'https://downloads.example.com/core.sqlite',
        'sha256': 'a' * 64,
        'size_bytes': 32,
        'access': 'free',
      },
    ],
  }),
);

void main() {
  for (final encoding in ['gzip', ' GZIP ']) {
    test('real HTTP $encoding manifest returns validated packs', () async {
      final fixture = await _serve(
        gzip.encode(_manifestBytes),
        encoding: encoding,
      );
      final packs = await fixture.manager.fetchAvailable();
      expect(packs.single.id, 'verified-core');
      expect(packs.single.title, 'Verified core');
      expect(fixture.requestEncoding?.toLowerCase(), contains('gzip'));
      expect(fixture.requests, 1);
    });
  }

  test('identity HTTP manifest remains supported', () async {
    final fixture = await _serve(_manifestBytes, encoding: 'identity');
    final packs = await fixture.manager.fetchAvailable();
    expect(packs.single.id, 'verified-core');
    expect(fixture.requests, 1);
  });

  test('manifest gzip expansion cannot bypass decoded JSON bound', () async {
    final expanded = utf8.encode(
      jsonEncode({
        'packs': [],
        'padding': 'a' * (CatalogPackManager.maximumManifestBytes + 1),
      }),
    );
    final wire = gzip.encode(expanded);
    expect(wire.length, lessThan(CatalogPackManager.maximumManifestBytes));
    final fixture = await _serve(wire, encoding: 'gzip');
    await expectLater(fixture.manager.fetchAvailable(), throwsFormatException);
    expect(fixture.requests, 1);
  });

  test('invalid UTF8 inside valid gzip is rejected', () async {
    final fixture = await _serve(gzip.encode([0xc3, 0x28]), encoding: 'gzip');
    await expectLater(fixture.manager.fetchAvailable(), throwsFormatException);
  });

  for (final damage in ['truncated', 'crc', 'size', 'suffix']) {
    test('$damage gzip cannot become an empty or partial manifest', () async {
      final valid = gzip.encode(_manifestBytes);
      final wire = switch (damage) {
        'truncated' => valid.sublist(0, valid.length - 7),
        'crc' => List<int>.from(valid)..[valid.length - 8] ^= 0xff,
        'size' => List<int>.from(valid)..[valid.length - 1] ^= 0xff,
        _ => <int>[...valid, 1, 2, 3],
      };
      final fixture = await _serve(wire, encoding: 'gzip');
      await expectLater(
        fixture.manager.fetchAvailable(),
        throwsA(isA<Exception>()),
      );
    });
  }

  test('unsupported HTTP content encoding fails closed', () async {
    final fixture = await _serve(_manifestBytes, encoding: 'br');
    await expectLater(fixture.manager.fetchAvailable(), throwsFormatException);
  });

  test(
    'gzip body timeout cancels the manifest without following a retry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.autoCompress = false;
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        request.response.add(gzip.encode(_manifestBytes).sublist(0, 10));
        await request.response.flush();
        // Deliberately leave the body open. The manager must enforce its own
        // transfer deadline, not wait for a test server to finish the response.
      });
      addTearDown(() => server.close(force: true));
      final manager = CatalogPackManager(
        manifestUrlOverride: 'http://127.0.0.1:${server.port}/manifest',
        allowLoopbackHttpForTesting: true,
        transferTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        manager.fetchAvailable(),
        throwsA(isA<TimeoutException>()),
      );
      expect(requests, 1);
    },
  );

  test('manifest redirects remain blocked before a target request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var targetRequests = 0;
    server.listen((request) async {
      if (request.uri.path == '/target') targetRequests++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/target');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final manager = CatalogPackManager(
      manifestUrlOverride: 'http://127.0.0.1:${server.port}/manifest',
      allowLoopbackHttpForTesting: true,
    );
    await expectLater(manager.fetchAvailable(), throwsA(isA<HttpException>()));
    expect(targetRequests, 0);
  });
}

class _ManifestFixture {
  _ManifestFixture(this.server);
  final HttpServer server;
  String? requestEncoding;
  int requests = 0;

  CatalogPackManager get manager => CatalogPackManager(
    manifestUrlOverride: 'http://127.0.0.1:${server.port}/manifest',
    allowLoopbackHttpForTesting: true,
  );
}

Future<_ManifestFixture> _serve(List<int> wire, {String? encoding}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.autoCompress = false;
  final fixture = _ManifestFixture(server);
  server.listen((request) async {
    fixture.requests++;
    fixture.requestEncoding = request.headers.value(
      HttpHeaders.acceptEncodingHeader,
    );
    request.response.headers.contentType = ContentType.json;
    if (encoding != null) {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, encoding);
    }
    request.response.contentLength = wire.length;
    request.response.add(wire);
    await request.response.close();
  });
  addTearDown(() => server.close(force: true));
  return fixture;
}
