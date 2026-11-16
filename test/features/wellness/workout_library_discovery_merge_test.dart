import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_localizer.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late List<WorkoutReleaseCatalogItem> release;
  late List<WellnessContentItem> discovery;
  late WorkoutDiscoveryLocalizer localizer;

  setUpAll(() {
    release = _approvedRelease();
    final discoveryBytes = File(
      WorkoutDiscoveryCatalogRepository.assetPath,
    ).readAsBytesSync();
    discovery = const WorkoutDiscoveryCatalogRepository().parse(
      utf8.decode(discoveryBytes),
      release,
    );
    localizer = WorkoutDiscoveryLocalizer.fromDiscovery(discovery);
  });

  test(
    'fresh install returns 302 cards without an MP4 network request',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-workout-discovery-fresh-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final client = _NoNetworkHttpClient();
      final manager = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async => discovery,
      );

      final items = await manager.loadWorkoutLibraryItems(locale: 'en');

      expect(items, hasLength(302));
      expect(items.map((item) => item.stableId).toSet(), hasLength(302));
      expect(items.every((item) => item.instructions.isEmpty), isTrue);
      expect(items.every((item) => item.steps.isEmpty), isTrue);
      expect(items.every((item) => item.segments.isEmpty), isTrue);
      expect(client.requests, 0);
    },
  );

  test(
    'verified exact-version installed item supersedes its redacted card',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-workout-discovery-installed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final installed = await _writeInstalledHomeItem(directory, version: 1);
      final client = _NoNetworkHttpClient();
      final manager = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async => discovery,
      );

      final items = await manager.loadWorkoutLibraryItems(locale: 'en');
      final overridden = items.singleWhere(
        (item) => item.stableId == installed.releaseKey,
      );

      expect(items, hasLength(302));
      expect(items.map((item) => item.stableId).toSet(), hasLength(302));
      expect(overridden.steps, orderedEquals(installed.steps));
      expect(overridden.steps, isNotEmpty);
      expect(client.requests, 0);
    },
  );

  test(
    'iOS container relocation resolves only current protected pack bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-workout-relocated-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final installed = await _writeInstalledHomeItem(directory, version: 1);
      final registry = File(p.join(directory.path, 'installed.json'));
      final rows = jsonDecode(await registry.readAsString()) as List;
      rows.single['path'] =
          '/var/mobile/Containers/Data/Application/'
          'E173E03A-5FCE-4893-BBFC-D08222D8CFF6/Library/Application Support/'
          'wellness_packs/bil-workouts-home-v1-1.json';
      await registry.writeAsString(jsonEncode(rows));
      final manager = WellnessContentPackManager(
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async => discovery,
      );
      final items = await manager.loadWorkoutLibraryItems(locale: 'en');
      expect(items, hasLength(302));
      expect(
        items.singleWhere((v) => v.stableId == installed.releaseKey).steps,
        orderedEquals(installed.steps),
      );
      expect(
        await registry.readAsString(),
        jsonEncode(rows),
      ); // No reset/rewrite on read.
      rows.single['path'] = 'bil-workouts-home-v1-1.json';
      await registry.writeAsString(jsonEncode(rows));
      expect(
        await manager.loadWorkoutLibraryItems(locale: 'ar'),
        hasLength(302),
      );
      rows.single['path'] = '/tmp/bil-workouts-home-v1-1.json';
      await registry.writeAsString(jsonEncode(rows));
      await expectLater(
        manager.loadWorkoutLibraryItems(locale: 'en'),
        throwsFormatException,
      );
      rows.single['path'] =
          '/var/mobile/Containers/Data/Application/'
          'E173E03A-5FCE-4893-BBFC-D08222D8CFF6/Library/Application Support/'
          'wellness_packs/../bil-workouts-home-v1-1.json';
      await registry.writeAsString(jsonEncode(rows));
      await expectLater(
        manager.loadWorkoutLibraryItems(locale: 'en'),
        throwsFormatException,
      );
    },
  );

  test('non-release pack version cannot supersede discovery', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bil-workout-discovery-wrong-version-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final installed = await _writeInstalledHomeItem(directory, version: 2);
    final client = _NoNetworkHttpClient();
    final manager = WellnessContentPackManager(
      client: client,
      packsDirectory: directory,
      workoutReleaseLoader: () async => release,
      workoutDiscoveryLoader: () async => discovery,
    );

    final items = await manager.loadWorkoutLibraryItems(locale: 'en');
    final card = items.singleWhere(
      (item) => item.stableId == installed.releaseKey,
    );

    expect(items, hasLength(302));
    expect(card.steps, isEmpty);
    expect(card.instructions, isEmpty);
    expect(client.requests, 0);
  });

  test(
    'shared library returns all localized cards without a media request',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-workout-discovery-localized-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final client = _NoNetworkHttpClient();
      final manager = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async => discovery,
        workoutDiscoveryLocalizerLoader: (_) async => localizer,
      );

      final items = await manager.loadWorkoutLibraryItems(locale: 'pt_BR');

      expect(items, hasLength(302));
      expect(items.every((item) => item.locale == 'pt-BR'), isTrue);
      expect(items.first.title, discovery.first.title);
      expect(items.first.description, isNot(discovery.first.description));
      expect(
        items.first.categoryDescription,
        isNot(discovery.first.categoryDescription),
      );
      expect(items.first.releaseKey, discovery.first.releaseKey);
      expect(items.first.publisher, discovery.first.publisher);
      expect(items.first.licenseName, discovery.first.licenseName);
      expect(items.first.licenseUrl, discovery.first.licenseUrl);
      expect(items.first.author, discovery.first.author);
      expect(items.first.attribution, discovery.first.attribution);
      expect(items.first.videoMedia, same(discovery.first.videoMedia));
      expect(items.first.equipment, hasLength(1));
      expect(client.requests, 0);
    },
  );

  test(
    'warm immutable packs use reviewed equipment across raw trusted and library reads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-equipment-warm-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final originals = await _writeWarmWorkoutCopies(directory);
      final before = _snapshotFiles(directory);
      final client = _NoNetworkHttpClient();
      var discoveryReads = 0;
      final manager = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async {
          discoveryReads++;
          return discovery;
        },
      );
      final reviewed = {for (final item in discovery) item.stableId: item};
      final raw = await manager.loadInstalledItems(
        WellnessContentType.workouts,
      );
      expect(raw, hasLength(302));
      for (final row in raw) {
        final key = row['_release_key'] as String;
        final content = Map<String, dynamic>.from(row)
          ..removeWhere((key, _) => key.startsWith('_'));
        expect(content, {
          ...originals[key]!,
          'equipment': reviewed[key]!.equipment,
        }, reason: key);
      }
      for (final items in [
        await manager.loadTrustedInstalledItems(
          WellnessContentType.workouts,
          locale: 'en',
        ),
        await manager.loadWorkoutLibraryItems(locale: 'en'),
      ]) {
        expect(items, hasLength(302));
        for (final item in items) {
          final authority = reviewed[item.stableId]!;
          expect(item.equipment, authority.equipment, reason: item.stableId);
          final expected = WellnessContentItem.fromJson(
            {
              ...originals[item.stableId]!,
              '_pack_minimum_access': 'pro',
              '_release_bundle_id': authority.releaseBundleId,
              '_release_key': item.stableId,
              '_primary_plan_group_id': authority.primaryPlanGroupId,
              '_plan_group_ids': authority.planGroupIds,
            },
            expectedType: WellnessContentType.workouts,
            schemaVersion: 2,
          );
          expect(
            _preservedWorkoutFields(item),
            _preservedWorkoutFields(expected),
            reason: item.stableId,
          );
        }
        final bench = items.singleWhere(
          (item) => item.stableId == _benchReleaseKey,
        );
        expect(bench.equipment, ['stable bench']);
        expect(bench.steps.first, contains('locked, non-slip flat bench'));
      }
      expect(originals[_benchReleaseKey]!['equipment'], ['none']);
      expect(_snapshotFiles(directory), before);
      expect(discoveryReads, 1);
      expect(client.requests, 0);
    },
  );

  for (final invalid in <Object?>[
    null,
    'stable bench',
    [],
    ['none', 'none'],
    [''],
  ]) {
    test(
      'original malformed equipment ${jsonEncode(invalid)} is never blessed by reviewed overlay',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'bil-equipment-invalid-',
        );
        addTearDown(() => directory.delete(recursive: true));
        await _writeWarmWorkoutCopies(directory);
        await _mutateWarmBench(directory, (raw) => raw['equipment'] = invalid);
        final before = _snapshotFiles(directory);
        final client = _NoNetworkHttpClient();
        final manager = WellnessContentPackManager(
          client: client,
          packsDirectory: directory,
          workoutReleaseLoader: () async => release,
          workoutDiscoveryLoader: () async => discovery,
        );
        final raw = await manager.loadInstalledItems(
          WellnessContentType.workouts,
        );
        expect(raw, hasLength(301));
        expect(
          raw.where((item) => item['_release_key'] == _benchReleaseKey),
          isEmpty,
        );
        final trusted = await manager.loadTrustedInstalledItems(
          WellnessContentType.workouts,
        );
        expect(
          trusted.where((item) => item.stableId == _benchReleaseKey),
          isEmpty,
        );
        final library = await manager.loadWorkoutLibraryItems(locale: 'en');
        expect(
          library
              .singleWhere((item) => item.stableId == _benchReleaseKey)
              .steps,
          isEmpty,
        );
        expect(_snapshotFiles(directory), before);
        expect(client.requests, 0);
      },
    );
  }

  for (final corruption in ['poster', 'video', 'rights']) {
    test(
      'reviewed equipment never blesses changed $corruption pins or rights',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'bil-equipment-pins-',
        );
        addTearDown(() => directory.delete(recursive: true));
        await _writeWarmWorkoutCopies(directory);
        await _mutateWarmBench(directory, (raw) {
          if (corruption == 'rights') {
            (raw['rights'] as Map<String, dynamic>)['mobile'] = false;
          } else {
            final media = raw['media'] as Map<String, dynamic>;
            (media[corruption == 'poster' ? 'image' : 'video']
                as Map<String, dynamic>)['sha256'] = List.filled(
              64,
              '0',
            ).join();
          }
        });
        final before = _snapshotFiles(directory);
        final client = _NoNetworkHttpClient();
        final manager = WellnessContentPackManager(
          client: client,
          packsDirectory: directory,
          workoutReleaseLoader: () async => release,
          workoutDiscoveryLoader: () async => discovery,
        );
        final raw = await manager.loadInstalledItems(
          WellnessContentType.workouts,
        );
        expect(
          raw.where((item) => item['_release_key'] == _benchReleaseKey),
          isEmpty,
        );
        final trusted = await manager.loadTrustedInstalledItems(
          WellnessContentType.workouts,
        );
        expect(
          trusted.where((item) => item.stableId == _benchReleaseKey),
          isEmpty,
        );
        expect(_snapshotFiles(directory), before);
        expect(client.requests, 0);
      },
    );
  }

  test(
    'missing or failed reviewed authority cannot manufacture trusted equipment',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-equipment-authority-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await _writeWarmWorkoutCopies(directory);
      final before = _snapshotFiles(directory);
      final client = _NoNetworkHttpClient();
      final missing = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async => discovery
            .where((item) => item.stableId != _benchReleaseKey)
            .toList(),
      );
      final raw = await missing.loadInstalledItems(
        WellnessContentType.workouts,
      );
      expect(
        raw.where((item) => item['_release_key'] == _benchReleaseKey),
        isEmpty,
      );
      final failed = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async => release,
        workoutDiscoveryLoader: () async =>
            throw StateError('review authority unavailable'),
      );
      await expectLater(
        failed.loadTrustedInstalledItems(WellnessContentType.workouts),
        throwsStateError,
      );
      expect(_snapshotFiles(directory), before);
      expect(client.requests, 0);
    },
  );

  test(
    'recipe reads do not load reviewed workout discovery or approvals',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-equipment-non-workout-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(p.join(directory.path, 'recipe-fixture-1.json'));
      await file.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'pack_id': 'recipe-fixture',
          'version': 1,
          'type': 'recipes',
          'items': [
            {
              'id': 'fixture-recipe',
              'type': 'recipes',
              'locale': 'en',
              'title': 'Existing recipe fixture',
              'description': 'Recipe unchanged by workout metadata.',
              'publisher': 'BIL Health',
              'source_url': 'https://www.bilhealth.com/terms',
              'license_name': 'Existing fixture',
              'verified': true,
            },
          ],
        }),
      );
      final installed = InstalledWellnessContentPack(
        id: 'recipe-fixture',
        version: 1,
        path: p.basename(file.path),
        installedAt: DateTime.utc(2026, 11, 1),
      );
      await File(
        p.join(directory.path, 'installed.json'),
      ).writeAsString(jsonEncode([installed.toJson()]));
      var authorityReads = 0;
      final client = _NoNetworkHttpClient();
      final manager = WellnessContentPackManager(
        client: client,
        packsDirectory: directory,
        workoutReleaseLoader: () async {
          authorityReads++;
          throw StateError('not for recipes');
        },
        workoutDiscoveryLoader: () async {
          authorityReads++;
          throw StateError('not for recipes');
        },
      );
      expect(
        await manager.loadInstalledItems(WellnessContentType.recipes),
        hasLength(1),
      );
      expect(
        await manager.loadTrustedInstalledItems(WellnessContentType.recipes),
        hasLength(1),
      );
      expect(authorityReads, 0);
      expect(client.requests, 0);
    },
  );
}

List<WorkoutReleaseCatalogItem> _approvedRelease() {
  final repository = const WorkoutReleaseCatalogRepository();
  final home = WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_home_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'home-training',
    expectedContentPackId: 'bil-workouts-home-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.homeRecordCount,
  );
  final gym = WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'gym-six-month',
    expectedContentPackId: 'bil-workouts-gym-six-month-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.gymRecordCount,
  );
  // Keep a reference so this test also proves the production repository type
  // remains constructible while exercising its strict static decoders.
  expect(repository, isA<WorkoutReleaseCatalogRepository>());
  return [...home, ...gym];
}

Future<({String releaseKey, List<String> steps})> _writeInstalledHomeItem(
  Directory directory, {
  required int version,
}) async {
  final source =
      jsonDecode(
            File(
              'artifacts/workout_media/cloudflare_runtime_v2/packs/'
              'bil-workouts-home-v1-v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final sourceItems = (source['items'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final raw = sourceItems.first;
  final id = raw['id'] as String;
  final releaseKey = 'home-training:$id';
  final steps = (raw['steps'] as List<dynamic>).cast<String>();
  final packPath = p.join(
    directory.absolute.path,
    'bil-workouts-home-v1-$version.json',
  );
  await File(packPath).writeAsString(
    jsonEncode({
      'schema_version': 2,
      'pack_id': 'bil-workouts-home-v1',
      'version': version,
      'type': 'workouts',
      'items': sourceItems,
    }),
  );
  final installed = InstalledWellnessContentPack(
    id: 'bil-workouts-home-v1',
    version: version,
    path: packPath,
    installedAt: DateTime.utc(2026, 8, 31),
    minimumAccess: WellnessContentAccess.pro,
  );
  await File(
    p.join(directory.path, 'installed.json'),
  ).writeAsString(jsonEncode([installed.toJson()]));
  return (releaseKey: releaseKey, steps: steps);
}

final class _NoNetworkHttpClient implements HttpClient {
  var requests = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requests += 1;
    throw StateError('Workout discovery must not request $url');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _benchReleaseKey =
    'gym-six-month:resistance-upper-body-bench-push-up-technique';

Future<Map<String, Map<String, dynamic>>> _writeWarmWorkoutCopies(
  Directory directory,
) async {
  final originals = <String, Map<String, dynamic>>{};
  final registry = <Map<String, dynamic>>[];
  for (final bundle in const [
    ('home-training', 'bil-workouts-home-v1'),
    ('gym-six-month', 'bil-workouts-gym-six-month-v1'),
  ]) {
    final source = File(
      'artifacts/workout_media/cloudflare_runtime_v2/packs/${bundle.$2}-v1.json',
    );
    final bytes = await source.readAsBytes();
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    for (final raw in (root['items'] as List).cast<Map<String, dynamic>>()) {
      originals['${bundle.$1}:${raw['id']}'] = raw;
    }
    final name = '${bundle.$2}-1.json';
    await File(p.join(directory.path, name)).writeAsBytes(bytes);
    registry.add(
      InstalledWellnessContentPack(
        id: bundle.$2,
        version: 1,
        path: name,
        installedAt: DateTime.utc(2026, 11, 1),
        minimumAccess: WellnessContentAccess.pro,
      ).toJson(),
    );
  }
  await File(
    p.join(directory.path, 'installed.json'),
  ).writeAsString(jsonEncode(registry));
  return originals;
}

Map<String, List<int>> _snapshotFiles(Directory directory) => {
  for (final file in directory.listSync().whereType<File>())
    p.basename(file.path): file.readAsBytesSync(),
};

Future<void> _mutateWarmBench(
  Directory directory,
  void Function(Map<String, dynamic>) mutate,
) async {
  final file = File(
    p.join(directory.path, 'bil-workouts-gym-six-month-v1-1.json'),
  );
  final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final raw = (root['items'] as List).cast<Map<String, dynamic>>().singleWhere(
    (raw) => 'gym-six-month:${raw['id']}' == _benchReleaseKey,
  );
  mutate(raw);
  await file.writeAsString(jsonEncode(root));
}

Object? _mediaFingerprint(WellnessMediaAsset? asset) => asset == null
    ? null
    : (
        asset.url,
        asset.sha256,
        asset.sizeBytes,
        asset.mimeType,
        asset.mediaRole,
      );

Map<String, Object?> _preservedWorkoutFields(WellnessContentItem item) => {
  'id': item.id,
  'type': item.type,
  'locale': item.locale,
  'title': item.title,
  'description': item.description,
  'publisher': item.publisher,
  'sourceUrl': item.sourceUrl,
  'licenseName': item.licenseName,
  'licenseUrl': item.licenseUrl,
  'verified': item.verified,
  'imageUrl': item.imageUrl,
  'videoUrl': item.videoUrl,
  'durationMinutes': item.durationMinutes,
  'durationSeconds': item.durationSeconds,
  'difficulty': item.difficulty,
  'tags': item.tags,
  'instructions': item.instructions,
  'category': item.category,
  'categoryDescription': item.categoryDescription,
  'categoryOrder': item.categoryOrder,
  'steps': item.steps,
  'imageMedia': _mediaFingerprint(item.imageMedia),
  'videoMedia': _mediaFingerprint(item.videoMedia),
  'rights': item.rights == null
      ? null
      : (item.rights!.mobile, item.rights!.paid, item.rights!.offline),
  'author': item.author,
  'attribution': item.attribution,
  'reviewedAt': item.reviewedAt,
  'safetyReviewed': item.safetyReviewed,
  'segments': item.segments,
  'minimumAccess': item.minimumAccess,
  'audience': item.audience,
  'presenter': item.presenter,
  'syntheticPerformer': item.syntheticPerformer,
  'releaseBundleId': item.releaseBundleId,
  'releaseKey': item.releaseKey,
  'primaryPlanGroupId': item.primaryPlanGroupId,
  'planGroupIds': item.planGroupIds,
};
