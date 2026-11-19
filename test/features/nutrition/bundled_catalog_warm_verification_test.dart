import 'package:flutter/foundation.dart' as diagnostics;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/services/bundled_core_catalog_installer.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/active_mobile_catalog_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _OperationCounts {
  int digests = 0;
  int registryWrites = 0;
}

// File factories are observed, not production APIs. Unknown IO fails loudly.
final class _CountingFile implements File {
  _CountingFile(this.file, this.counts);
  final File file;
  final _OperationCounts counts;

  @override
  String get path => file.path;
  @override
  Uri get uri => file.uri;
  @override
  File get absolute => _CountingFile(file.absolute, counts);
  @override
  Directory get parent => file.parent;
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<int> length() => file.length();
  @override
  Future<FileStat> stat() => file.stat();
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      file.open(mode: mode);
  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) =>
      file.openSync(mode: mode);
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      file.readAsString(encoding: encoding);
  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (path.endsWith('bil_food_core.sqlite') ||
        path.endsWith('bil_food_core.sqlite.installing')) {
      counts.digests++;
    }
    return file.openRead(start, end);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (path.endsWith('catalog_registry.json.writing')) counts.registryWrites++;
    return file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => file.writeAsBytes(bytes, mode: mode, flush: flush);
  @override
  Future<File> rename(String newPath) => file.rename(newPath);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnexpectedAssetRead extends CachingAssetBundle {
  int calls = 0;
  @override
  Future<ByteData> load(String key) async {
    calls++;
    throw StateError('Replacement requires a fresh verified bundled install');
  }
}

final class _NetworkMustNotStart extends TrustedFoodNetworkSearchResolver {
  int calls = 0;
  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    calls++;
    throw StateError(
      'Read-only local benchmark must not issue a remote request',
    );
  }
}

Future<({Directory root, File catalog})> _installedFixture() async {
  final root = await Directory.systemTemp.createTemp('bil-catalog-warm-qa-');
  addTearDown(() async {
    final tempRoot = p.normalize(p.absolute(Directory.systemTemp.path));
    final target = p.normalize(p.absolute(root.path));
    expect(p.isWithin(tempRoot, target), isTrue);
    expect(p.basename(target), startsWith('bil-catalog-warm-qa-'));
    await root.delete(recursive: true);
  });
  final catalog = File(
    p.join(
      root.path,
      'catalogs',
      BundledCoreCatalogInstaller.catalogVersion,
      'bil_food_core.sqlite',
    ),
  );
  await catalog.parent.create(recursive: true);
  await File(BundledCoreCatalogInstaller.assetPath).copy(catalog.path);
  return (root: root, catalog: catalog);
}

Future<T> _observeIo<T>(_OperationCounts counts, Future<T> Function() body) {
  final realIoZone = Zone.current;
  return IOOverrides.runZoned(
    body,
    createFile: (path) =>
        _CountingFile(realIoZone.run(() => File(path)), counts),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one cold verification, no full-file digests or registry writes on warm searches',
    () async {
      final fixture = await _installedFixture();
      final counts = _OperationCounts();
      final bundle = _UnexpectedAssetRead();
      final installer = BundledCoreCatalogInstaller(bundle: bundle);
      final cold = Stopwatch()..start();
      await _observeIo(counts, () => installer.ensureInstalled(fixture.root));
      cold.stop();
      expect(
        counts.digests,
        1,
        reason: 'Initial SHA verification is mandatory',
      );
      expect(counts.registryWrites, 1);
      final warm = Stopwatch()..start();
      await _observeIo(counts, () async {
        for (var query = 0; query < 10; query++) {
          await installer.ensureInstalled(fixture.root);
        }
      });
      warm.stop();
      expect(counts.digests, 1, reason: 'Unchanged verified content is reused');
      expect(
        counts.registryWrites,
        1,
        reason: 'Identical registry is not rewritten',
      );
      expect(bundle.calls, 0);
      // This is a read-only fixture operation benchmark, not a device claim.
      diagnostics.debugPrint(
        jsonEncode({
          'benchmark': 'bundled_catalog_integrity_cold_then_ten_warm',
          'cold_us': cold.elapsedMicroseconds,
          'ten_warm_us': warm.elapsedMicroseconds,
          'digest_reads_total': counts.digests,
          'registry_writes_total': counts.registryWrites,
          'catalog_bytes': BundledCoreCatalogInstaller.expectedSizeBytes,
        }),
      );
    },
  );

  test(
    'concurrent first searches share a single verification and atomic registry write',
    () async {
      final fixture = await _installedFixture();
      final counts = _OperationCounts();
      final installer = BundledCoreCatalogInstaller(
        bundle: _UnexpectedAssetRead(),
      );
      await _observeIo(
        counts,
        () => Future.wait([
          installer.ensureInstalled(fixture.root),
          installer.ensureInstalled(fixture.root),
          installer.ensureInstalled(fixture.root),
        ]),
      );
      expect(counts.digests, 1);
      expect(counts.registryWrites, 1);
    },
  );

  test('changed file metadata forces SHA verification again', () async {
    final fixture = await _installedFixture();
    final counts = _OperationCounts();
    final installer = BundledCoreCatalogInstaller(
      bundle: _UnexpectedAssetRead(),
    );
    await _observeIo(counts, () => installer.ensureInstalled(fixture.root));
    await fixture.catalog.setLastModified(DateTime.utc(2025, 1, 2));
    await _observeIo(counts, () => installer.ensureInstalled(fixture.root));
    expect(counts.digests, 2);
    expect(counts.registryWrites, 1);
  });

  test(
    'same-size corrupted replacement never inherits the previous verification',
    () async {
      final fixture = await _installedFixture();
      final counts = _OperationCounts();
      final bundle = _UnexpectedAssetRead();
      final installer = BundledCoreCatalogInstaller(bundle: bundle);
      await _observeIo(counts, () => installer.ensureInstalled(fixture.root));
      final bytes = await fixture.catalog.readAsBytes();
      bytes[0] ^= 0xff;
      await fixture.catalog.writeAsBytes(bytes, flush: true);
      await fixture.catalog.setLastModified(DateTime.utc(2025, 2, 3));
      await expectLater(
        _observeIo(counts, () => installer.ensureInstalled(fixture.root)),
        throwsStateError,
      );
      expect(counts.digests, 2);
      expect(
        bundle.calls,
        1,
        reason: 'Invalid content requires a new verified asset',
      );
    },
  );

  test(
    'real Arabic local and installed phases produce a bounded cold-warm report',
    () async {
      final fixture = await _installedFixture();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final resolver = ActiveMobileCatalogResolver(
        rootResolver: () async => fixture.root,
      );
      final network = _NetworkMustNotStart();
      final authority = FoodRuntimeSearchAuthority(
        FoodRepository(database),
        catalogResolver: resolver.openIfAvailable,
        networkSearchResolver: network,
      );
      final counts = _OperationCounts();
      final samples = <Map<String, Object?>>[];
      await _observeIo(counts, () async {
        for (final query in const ['خيار', 'طماطم', 'بام', 'باميه', 'خيار']) {
          final watch = Stopwatch()..start();
          final phases = <Map<String, Object?>>[];
          await for (final result
              in authority
                  .searchResultsProgressively(query, limit: 10)
                  .take(2)) {
            phases.add({
              'source': result.source.name,
              'rows': result.foods.length,
              'elapsed_us': watch.elapsedMicroseconds,
            });
          }
          watch.stop();
          samples.add({'query': query, 'phases': phases});
        }
      });
      expect(
        network.calls,
        0,
        reason: 'Local phases must not wait for remote enrichment',
      );
      expect(
        counts.digests,
        1,
        reason: 'All unchanged catalog opens share verified bytes',
      );
      expect(counts.registryWrites, 1);
      diagnostics.debugPrint(
        jsonEncode({
          'benchmark': 'real_runtime_authority_arabic_local_installed_only',
          'samples': samples,
          'digest_reads_total': counts.digests,
          'registry_writes_total': counts.registryWrites,
          'remote_calls': network.calls,
          'device_timing_claim': false,
        }),
      );
    },
  );
}
