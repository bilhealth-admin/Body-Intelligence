// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/repositories/gym_six_month_plan_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  const repository = GymSixMonthPlanRepository();
  late String artifactSource;
  late List<int> releaseManifestBytes;

  setUpAll(() {
    artifactSource = File(
      GymSixMonthPlanRepository.artifactPath,
    ).readAsStringSync();
    releaseManifestBytes = File(
      GymSixMonthPlanRepository.releaseManifestPath,
    ).readAsBytesSync();
  });

  test('tracked runtime artifact is minimal and valid', () {
    final plan = repository.parse(
      artifactSource,
      releaseManifestBytes: releaseManifestBytes,
    );

    expect(
      plan.months.map((month) => month.month),
      orderedEquals([1, 2, 3, 4, 5, 6]),
    );
    expect(plan.sessions, hasLength(6));
    expect(
      plan.sessions.every((session) => session.exerciseIds.length == 5),
      isTrue,
    );
    expect(plan.warmups.exerciseIds, hasLength(16));
    expect(plan.warmups.groups, hasLength(7));
    expect(plan.libraryPages, hasLength(8));
    expect(plan.exerciseIds, hasLength(102));
    expect(plan.exerciseIds.toSet(), hasLength(102));
    expect(plan.exerciseIds.every((id) => !id.contains('--')), isTrue);
    expect(plan.sourceContractId, GymSixMonthPlanRepository.sourceContractId);
    expect(
      plan.releaseManifestSha256,
      GymSixMonthPlanRepository.releaseManifestSha256,
    );

    final raw = jsonDecode(artifactSource) as Map<String, dynamic>;
    expect(raw, isNot(contains('records')));
    expect(raw, isNot(contains('media')));
    expect(artifactSource, isNot(contains('"records"')));
    expect(artifactSource, isNot(contains('"media"')));
  });

  test('all IDs resolve exactly to released catalog asset identities', () {
    expect(
      sha256.convert(releaseManifestBytes).toString(),
      GymSixMonthPlanRepository.releaseManifestSha256,
    );
    final release =
        jsonDecode(utf8.decode(releaseManifestBytes)) as Map<String, dynamic>;
    expect(release['schema'], GymSixMonthPlanRepository.releaseManifestSchema);
    expect(release['bundleId'], GymSixMonthPlanRepository.releaseBundleId);
    expect(
      release['contentPackId'],
      GymSixMonthPlanRepository.releaseContentPackId,
    );
    final releaseIds = _objects(
      release['records'],
    ).map((record) => record['assetId'] as String).toList(growable: false);
    final plan = repository.parse(
      artifactSource,
      releaseManifestBytes: releaseManifestBytes,
    );

    expect(plan.exerciseIds, orderedEquals(releaseIds));
    expect(
      plan.sessions.expand((session) => session.exerciseIds),
      everyElement(isIn(releaseIds)),
    );
    expect(
      plan.warmups.groups.expand((group) => group.exerciseIds),
      everyElement(isIn(releaseIds)),
    );
  });

  test(
    'tracked artifact exactly projects authoritative source when present',
    () {
      final sourceFile = File(GymSixMonthPlanRepository.sourcePath);
      if (!sourceFile.existsSync()) return;

      final sourceBytes = sourceFile.readAsBytesSync();
      expect(
        sha256.convert(sourceBytes).toString(),
        GymSixMonthPlanRepository.sourceSha256,
      );
      final source =
          jsonDecode(utf8.decode(sourceBytes)) as Map<String, dynamic>;
      final plan = repository.parse(
        artifactSource,
        releaseManifestBytes: releaseManifestBytes,
        authoritativeSourceBytes: sourceBytes,
      );
      expect(plan.sourceContractId, source['contract_id']);

      final queue = _objects(source['generation_queue']);
      final movementToId = <String, String>{
        for (final item in queue)
          item['movement']! as String: _releaseId(
            item['exercise_id']! as String,
          ),
      };
      expect(
        plan.exerciseIds.toSet(),
        equals(
          queue
              .map((item) => _releaseId(item['exercise_id'] as String))
              .toSet(),
        ),
      );

      final sourceSessions = _objects(source['sessions']);
      expect(
        plan.sessions.map((session) => session.id),
        orderedEquals(
          sourceSessions.map((session) => _safeId(session['name'] as String)),
        ),
      );
      for (var index = 0; index < sourceSessions.length; index += 1) {
        final exercises = _objects(sourceSessions[index]['exercises']);
        expect(
          plan.sessions[index].exerciseIds,
          orderedEquals(
            exercises.map(
              (exercise) => movementToId[exercise['movement'] as String],
            ),
          ),
        );
      }

      final sourceMonths = _objects(source['months']);
      for (var index = 0; index < sourceMonths.length; index += 1) {
        final sourceMonth = sourceMonths[index];
        expect(plan.months[index].month, sourceMonth['month']);
        expect(plan.months[index].phase, sourceMonth['phase']);
        expect(
          plan.months[index].sessionIds,
          orderedEquals(
            (sourceMonth['schedule'] as List<dynamic>).cast<String>().map(
              _safeId,
            ),
          ),
        );
      }

      final sourceWarmups = source['warmups'] as Map<String, dynamic>;
      final expectedWarmupIds = <String>[];
      final expectedWarmupGroups = <String, List<String>>{};
      for (final entry in sourceWarmups.entries) {
        final ids = _objects(entry.value)
            .map((warmup) => movementToId[warmup['movement'] as String]!)
            .toList(growable: false);
        expectedWarmupGroups[_safeId(entry.key)] = ids;
        for (final id in ids) {
          if (!expectedWarmupIds.contains(id)) expectedWarmupIds.add(id);
        }
      }
      expect(plan.warmups.exerciseIds, orderedEquals(expectedWarmupIds));
      expect(
        plan.warmups.groups.map((group) => group.id),
        orderedEquals(expectedWarmupGroups.keys),
      );
      for (final group in plan.warmups.groups) {
        expect(
          group.exerciseIds,
          orderedEquals(expectedWarmupGroups[group.id]!),
        );
      }

      final sourcePages = _objects(source['library_pages']);
      for (var index = 0; index < sourcePages.length; index += 1) {
        final expected = sourcePages[index];
        final actual = plan.libraryPages[index];
        expect(actual.id, expected['id']);
        expect(actual.title, expected['title']);
        expect(actual.kind, expected['kind']);
        expect(actual.description, expected['description']);
        expect(
          actual.filters,
          orderedEquals((expected['filters'] as List<dynamic>).cast<String>()),
        );
      }
    },
  );

  test('authoritative source digest mismatch fails closed', () {
    expect(
      () => repository.parse(
        artifactSource,
        releaseManifestBytes: releaseManifestBytes,
        authoritativeSourceBytes: utf8.encode('{}'),
      ),
      throwsFormatException,
    );
  });

  test('release manifest digest mismatch fails closed', () {
    expect(
      () => repository.parse(
        artifactSource,
        releaseManifestBytes: [...releaseManifestBytes, 0],
      ),
      throwsFormatException,
    );
  });

  group('malformed runtime artifacts fail closed', () {
    final cases = <String, void Function(Map<String, dynamic>)>{
      'unknown top-level field': (root) => root['unexpected'] = true,
      'wrong schema': (root) => root['schema'] = 'other.v1',
      'non-integer version': (root) => root['version'] = 1.0,
      'wrong source digest': (root) {
        _map(root['source'])['sha256'] = List.filled(64, '0').join();
      },
      'wrong source contract': (root) {
        _map(root['source'])['contract_id'] = 'other-contract-v1';
      },
      'wrong release digest': (root) {
        _map(root['release_manifest'])['sha256'] = List.filled(64, '0').join();
      },
      'missing month': (root) {
        _list(root['months']).removeLast();
      },
      'out-of-order month': (root) {
        _map(_list(root['months'])[0])['month'] = 2;
      },
      'non-integer month': (root) {
        _map(_list(root['months'])[0])['month'] = 1.0;
      },
      'unknown schedule reference': (root) {
        _list(_map(_list(root['months'])[0])['schedule'])[0] = 'unknown';
      },
      'short session': (root) {
        _list(_map(_list(root['sessions'])[0])['exercise_ids']).removeLast();
      },
      'unsafe session ID': (root) {
        _map(_list(root['sessions'])[0])['id'] = '../push-a';
      },
      'unresolved double-hyphen ID': (root) {
        final ids = _list(root['exercise_ids']);
        ids[0] = (ids[0] as String).replaceFirst('-', '--');
      },
      'duplicate exercise ID': (root) {
        final ids = _list(root['exercise_ids']);
        ids[1] = ids[0];
      },
      'unlisted warm-up reference': (root) {
        final warmups = _map(root['warmups']);
        final group = _map(_list(warmups['groups'])[0]);
        _list(group['exercise_ids'])[0] = _list(root['exercise_ids'])[50];
      },
      'duplicate library page': (root) {
        final pages = _list(root['library_pages']);
        _map(pages[1])['id'] = _map(pages[0])['id'];
      },
      'extra exercise': (root) {
        _list(root['exercise_ids']).add('safe-but-uncontracted-exercise');
      },
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final root = jsonDecode(artifactSource) as Map<String, dynamic>;
        entry.value(root);
        expect(
          () => repository.parse(
            jsonEncode(root),
            releaseManifestBytes: releaseManifestBytes,
          ),
          throwsFormatException,
        );
      });
    }
  });
}

List<Map<String, dynamic>> _objects(Object? value) =>
    _list(value).map(_map).toList(growable: false);

Map<String, dynamic> _map(Object? value) => value as Map<String, dynamic>;

List<dynamic> _list(Object? value) => value as List<dynamic>;

String _safeId(String value) =>
    value.toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');

String _releaseId(String sourceExerciseId) =>
    sourceExerciseId.replaceAll('--', '-');
