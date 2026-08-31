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
