// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  const repository = WorkoutDiscoveryCatalogRepository();
  late String source;
  late List<WorkoutReleaseCatalogItem> release;

  setUpAll(() {
    source = File(
      WorkoutDiscoveryCatalogRepository.assetPath,
    ).readAsStringSync();
    release = _releaseFromArtifacts();
  });

  test('fresh discovery exposes exactly 302 redacted stable cards', () {
    final items = repository.parse(source, release);

    expect(items, hasLength(302));
    expect(items.map((item) => item.stableId).toSet(), hasLength(302));
    expect(items.map((item) => item.stableId).toSet(), {
      for (final item in release) item.releaseKey,
    });
    expect(
      items,
      everyElement(
        isA<WellnessContentItem>()
            .having(
              (item) => item.minimumAccess,
              'access',
              WellnessContentAccess.pro,
            )
            .having((item) => item.instructions, 'instructions', isEmpty)
            .having((item) => item.steps, 'steps', isEmpty)
            .having((item) => item.segments, 'segments', isEmpty),
      ),
    );
  });

  test('catalog source pins match the exact registry, manifests and packs', () {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final catalogSource = root['source'] as Map<String, dynamic>;
    expect(
      catalogSource['registrySha256'],
      _sha('artifacts/workout_media/workout_release_bundle_registry_v1.json'),
    );
    final paths = <String, (String, String)>{
      'home-training': (
        'artifacts/workout_media/workout_release_bundle_home_v1.json',
        'artifacts/workout_media/cloudflare_runtime_v2/packs/'
            'bil-workouts-home-v1-v1.json',
      ),
      'gym-six-month': (
        'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
        'artifacts/workout_media/cloudflare_runtime_v2/packs/'
            'bil-workouts-gym-six-month-v1-v1.json',
      ),
    };
    for (final raw in catalogSource['bundles'] as List<dynamic>) {
      final bundle = raw as Map<String, dynamic>;
      final pinned = paths[bundle['bundleId']]!;
      expect(bundle['manifestSha256'], _sha(pinned.$1));
      expect(bundle['packSha256'], _sha(pinned.$2));
    }
  });

  test('parser is metadata-only and has no network client', () {
    final implementation = File(
      'lib/features/wellness/repositories/'
      'workout_discovery_catalog_repository.dart',
    ).readAsStringSync();

    expect(implementation, isNot(contains('HttpClient')));
    expect(implementation, isNot(contains('.getUrl(')));
    expect(implementation, isNot(contains('dart:io')));
  });

  group('discovery mutations fail closed', () {
    final cases = <String, void Function(Map<String, dynamic>)>{
      'unknown root field': (root) => root['unknown'] = true,
      'source pin': (root) {
        _map(root['source'])['registrySha256'] = List.filled(64, '0').join();
      },
      'unknown item field': (root) {
        _firstItem(root)['unknown'] = true;
      },
      'steps': (root) {
        _firstItem(root)['steps'] = ['premium instruction'];
      },
      'instructions': (root) {
        _firstItem(root)['instructions'] = ['premium instruction'];
      },
      'segments': (root) {
        _firstItem(root)['segments'] = <Object>[];
      },
      'release key': (root) {
        _firstItem(root)['_release_key'] = 'home-training:unknown';
      },
      'group membership': (root) {
        _list(_firstItem(root)['_plan_group_ids'])[0] = 'home-unknown';
      },
      'video object': (root) {
        _video(root)['url'] = 'https://workouts.bilhealth.com/wrong.mp4';
      },
      'video digest': (root) {
        _video(root)['sha256'] = List.filled(64, '0').join();
      },
      'video size': (root) {
        _video(root)['size_bytes'] = 1;
      },
      'unknown poster field': (root) {
        _image(root)['unknown'] = true;
      },
      'duplicate record': (root) {
        final items = _list(root['items']);
        items[1] = jsonDecode(jsonEncode(items[0]));
      },
      'missing record': (root) {
        _list(root['items']).removeLast();
        root['itemCount'] = 301;
      },
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final root = jsonDecode(source) as Map<String, dynamic>;
        entry.value(root);
        expect(
          () => repository.parse(jsonEncode(root), release),
          throwsFormatException,
        );
      });
    }
  });

  test('release media changes cannot redefine discovery pins', () {
    final first = release.first;
    final changed = WorkoutReleaseCatalogItem(
      bundleId: first.bundleId,
      contentPackId: first.contentPackId,
      assetId: first.assetId,
      exerciseId: first.exerciseId,
      releaseKey: first.releaseKey,
      slot: first.slot,
      objectPath: first.objectPath,
      primaryGroupId: first.primaryGroupId,
      planGroupIds: first.planGroupIds,
      expectedSha256: first.expectedSha256,
      expectedBytes: first.expectedBytes! + 1,
      durationMilliseconds: first.durationMilliseconds,
      frameCount: first.frameCount,
      fpsNumerator: first.fpsNumerator,
      fpsDenominator: first.fpsDenominator,
      width: first.width,
      height: first.height,
      codecName: first.codecName,
      availability: first.availability,
    );

    expect(
      () => repository.parse(source, [changed, ...release.skip(1)]),
      throwsFormatException,
    );
  });
}

List<WorkoutReleaseCatalogItem> _releaseFromArtifacts() {
  final result = <WorkoutReleaseCatalogItem>[];
  for (final path in const [
    'artifacts/workout_media/workout_release_bundle_home_v1.json',
    'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
  ]) {
    final manifest =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    for (final raw in manifest['records'] as List<dynamic>) {
      final record = raw as Map<String, dynamic>;
      result.add(
        WorkoutReleaseCatalogItem(
          bundleId: record['bundleId'] as String,
          contentPackId: manifest['contentPackId'] as String,
          assetId: record['assetId'] as String,
          exerciseId: record['exerciseId'] as String,
          releaseKey: record['releaseKey'] as String,
          slot: record['primaryGroupId'] as String,
          objectPath: record['objectPath'] as String,
          primaryGroupId: record['primaryGroupId'] as String,
          planGroupIds: (record['planGroupIds'] as List<dynamic>)
              .cast<String>(),
          expectedSha256: record['sha256'] as String,
          expectedBytes: record['byteLength'] as int,
          durationMilliseconds: record['durationMilliseconds'] as int,
          frameCount: record['frameCount'] as int,
          fpsNumerator: record['fpsNumerator'] as int,
          fpsDenominator: record['fpsDenominator'] as int,
          width: record['width'] as int,
          height: record['height'] as int,
          codecName: record['codecName'] as String,
          availability: WorkoutReleaseAvailability.approved,
        ),
      );
    }
  }
  return result;
}

String _sha(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

Map<String, dynamic> _firstItem(Map<String, dynamic> root) =>
    _map(_list(root['items']).first);

Map<String, dynamic> _video(Map<String, dynamic> root) =>
    _map(_map(_firstItem(root)['media'])['video']);

Map<String, dynamic> _image(Map<String, dynamic> root) =>
    _map(_map(_firstItem(root)['media'])['image']);

Map<String, dynamic> _map(Object? value) => value as Map<String, dynamic>;

List<dynamic> _list(Object? value) => value as List<dynamic>;
