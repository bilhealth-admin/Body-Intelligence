import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/gym_six_month_plan.dart';

/// Fail-closed decoder for the pinned, media-free six-month gym plan.
final class GymSixMonthPlanRepository {
  const GymSixMonthPlanRepository();

  static const artifactPath =
      'artifacts/workout_media/gym_six_month_plan_runtime_v1.json';
  static const schema = 'bil.workout-media.gym-plan-runtime.v1';
  static const version = 1;
  static const sourcePath =
      'tool/workout_media/pipeline/contracts/gym_six_month_video_plan.json';
  static const sourceContractId = 'bil-gym-six-month-video-plan-v1';
  static const sourceSha256 =
      '24264d0c26ece4398f85954c1e02e52dbd8748479f42ef784d9f1ea742894d14';
  static const releaseManifestPath =
      'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json';
  static const releaseManifestSchema =
      'bil.workout-media.bundle-release-manifest.v1';
  static const releaseBundleId = 'gym-six-month';
  static const releaseContentPackId = 'bil-workouts-gym-six-month-v1';
  static const releaseManifestSha256 =
      '4e531ad6cd31c3ed096257b3db4a3aa4f99b1fa74d2eef3655884de78fdd48cd';

  static const _sessionIds = {
    'push-a',
    'push-b',
    'pull-a',
    'pull-b',
    'legs-a',
    'legs-b',
  };
  static const _warmupGroupIds = {
    'push',
    'pull',
    'legs',
    'chest-triceps',
    'back-biceps',
    'shoulders-arms',
    'full-body',
  };
  static const _libraryPageKinds = {
    'program',
    'session-preparation',
    'reference',
  };
  static const _libraryPageIds = {
    'push-pull-legs',
    'warm-up-mobility',
    'muscle-pair-split',
    'upper-lower',
    'full-body',
    'arnold-split',
    'powerbuilding',
    'exercise-technique',
  };

  GymSixMonthPlan parse(
    String artifactSource, {
    required List<int> releaseManifestBytes,
    List<int>? authoritativeSourceBytes,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(artifactSource);
    } on FormatException {
      rethrow;
    }
    final root = _object(decoded, 'plan');
    _exactKeys(root, const {
      'schema',
      'version',
      'source',
      'release_manifest',
      'months',
      'sessions',
      'warmups',
      'library_pages',
      'exercise_ids',
    });
    if (root['schema'] != schema ||
        root['version'] is! int ||
        root['version'] != version) {
      throw const FormatException('Gym plan schema/version is unsupported.');
    }

    final source = _object(root['source'], 'source');
    _exactKeys(source, const {'path', 'contract_id', 'sha256'});
    if (source['path'] != sourcePath ||
        source['contract_id'] != sourceContractId ||
        source['sha256'] != sourceSha256) {
      throw const FormatException('Gym plan source contract is invalid.');
    }
    if (authoritativeSourceBytes != null &&
        sha256.convert(authoritativeSourceBytes).toString() != sourceSha256) {
      throw const FormatException('Gym plan authoritative source changed.');
    }

    final release = _object(root['release_manifest'], 'release_manifest');
    _exactKeys(release, const {
      'path',
      'schema',
      'bundle_id',
      'content_pack_id',
      'sha256',
    });
    if (release['path'] != releaseManifestPath ||
        release['schema'] != releaseManifestSchema ||
        release['bundle_id'] != releaseBundleId ||
        release['content_pack_id'] != releaseContentPackId ||
        release['sha256'] != releaseManifestSha256 ||
        sha256.convert(releaseManifestBytes).toString() !=
            releaseManifestSha256) {
      throw const FormatException('Gym plan release contract is invalid.');
    }
    final releasedExerciseIds = _parseReleaseExerciseIds(releaseManifestBytes);

    final exerciseIds = _idList(
      root['exercise_ids'],
      'exercise_ids',
      exactLength: 102,
    );
    if (!_sameList(exerciseIds, releasedExerciseIds)) {
      throw const FormatException(
        'Gym plan IDs do not resolve to released asset IDs.',
      );
    }
    final exerciseIdSet = exerciseIds.toSet();

    final sessions = _parseSessions(root['sessions'], exerciseIdSet);
    final sessionIdSet = sessions.map((session) => session.id).toSet();
    if (!_sameSet(sessionIdSet, _sessionIds)) {
      throw const FormatException('Gym plan session identities are invalid.');
    }

    final months = _parseMonths(root['months'], sessionIdSet);
    final scheduled = months.expand((month) => month.sessionIds).toSet();
    if (!_sameSet(scheduled, sessionIdSet)) {
      throw const FormatException('Gym plan leaves an unscheduled session.');
    }

    final warmups = _parseWarmups(root['warmups'], exerciseIdSet);
    final libraryPages = _parseLibraryPages(root['library_pages']);

    return GymSixMonthPlan(
      sourcePath: sourcePath,
      sourceContractId: sourceContractId,
      sourceSha256: sourceSha256,
      releaseManifestPath: releaseManifestPath,
      releaseManifestSha256: releaseManifestSha256,
      months: List.unmodifiable(months),
      sessions: List.unmodifiable(sessions),
      warmups: warmups,
      libraryPages: List.unmodifiable(libraryPages),
      exerciseIds: List.unmodifiable(exerciseIds),
    );
  }

  static List<String> _parseReleaseExerciseIds(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      rethrow;
    }
    final release = _object(decoded, 'release manifest');
    final records = _list(release['records'], 'release manifest.records');
    if (release['schema'] != releaseManifestSchema ||
        release['bundleId'] != releaseBundleId ||
        release['contentPackId'] != releaseContentPackId ||
        release['recordCount'] is! int ||
        release['recordCount'] != 102 ||
        records.length != 102) {
      throw const FormatException('Gym release manifest is incompatible.');
    }
    final ids = <String>[];
    final unique = <String>{};
    for (final raw in records) {
      final record = _object(raw, 'release manifest record');
      final id = _safeId(record['assetId'], 'release manifest assetId');
      if (record['exerciseId'] != id || !unique.add(id)) {
        throw const FormatException('Gym release asset identity is invalid.');
      }
      ids.add(id);
    }
    return ids;
  }

  static List<GymPlanSession> _parseSessions(
    Object? value,
    Set<String> allExerciseIds,
  ) {
    final rawSessions = _list(value, 'sessions');
    if (rawSessions.length != 6) {
      throw const FormatException('Gym plan must contain six sessions.');
    }
    final ids = <String>{};
    final sessions = <GymPlanSession>[];
    for (final raw in rawSessions) {
      final session = _object(raw, 'session');
      _exactKeys(session, const {'id', 'exercise_ids'});
      final id = _safeId(session['id'], 'session.id');
      final exerciseIds = _idList(
        session['exercise_ids'],
        'session.exercise_ids',
        exactLength: 5,
      );
      if (!ids.add(id) || !allExerciseIds.containsAll(exerciseIds)) {
        throw const FormatException('Gym plan session references are invalid.');
      }
      sessions.add(
        GymPlanSession(id: id, exerciseIds: List.unmodifiable(exerciseIds)),
      );
    }
    return sessions;
  }

  static List<GymPlanMonth> _parseMonths(
    Object? value,
    Set<String> sessionIds,
  ) {
    final rawMonths = _list(value, 'months');
    if (rawMonths.length != 6) {
      throw const FormatException('Gym plan must contain six months.');
    }
    final months = <GymPlanMonth>[];
    for (var index = 0; index < rawMonths.length; index += 1) {
      final raw = _object(rawMonths[index], 'month');
      _exactKeys(raw, const {'month', 'phase', 'schedule'});
      final number = raw['month'];
      final phase = _text(raw['phase'], 'month.phase');
      final schedule = _idList(raw['schedule'], 'month.schedule');
      if (number is! int ||
          number != index + 1 ||
          schedule.isEmpty ||
          schedule.length > sessionIds.length ||
          !sessionIds.containsAll(schedule)) {
        throw const FormatException('Gym plan month schedule is invalid.');
      }
      months.add(
        GymPlanMonth(
          month: number,
          phase: phase,
          sessionIds: List.unmodifiable(schedule),
        ),
      );
    }
    return months;
  }

  static GymPlanWarmups _parseWarmups(
    Object? value,
    Set<String> allExerciseIds,
  ) {
    final warmups = _object(value, 'warmups');
    _exactKeys(warmups, const {'exercise_ids', 'groups'});
    final exerciseIds = _idList(
      warmups['exercise_ids'],
      'warmups.exercise_ids',
      exactLength: 16,
    );
    if (!allExerciseIds.containsAll(exerciseIds)) {
      throw const FormatException(
        'Gym warm-up exercise is not in the library.',
      );
    }

    final rawGroups = _list(warmups['groups'], 'warmups.groups');
    if (rawGroups.length != _warmupGroupIds.length) {
      throw const FormatException('Gym warm-up groups are incomplete.');
    }
    final groupIds = <String>{};
    final referencedIds = <String>{};
    final groups = <GymPlanWarmupGroup>[];
    for (final raw in rawGroups) {
      final group = _object(raw, 'warmup.group');
      _exactKeys(group, const {'id', 'exercise_ids'});
      final id = _safeId(group['id'], 'warmup.group.id');
      final refs = _idList(group['exercise_ids'], 'warmup.group.exercise_ids');
      if (!groupIds.add(id) ||
          refs.isEmpty ||
          !exerciseIds.toSet().containsAll(refs)) {
        throw const FormatException('Gym warm-up group is invalid.');
      }
      referencedIds.addAll(refs);
      groups.add(
        GymPlanWarmupGroup(id: id, exerciseIds: List.unmodifiable(refs)),
      );
    }
    if (!_sameSet(groupIds, _warmupGroupIds) ||
        !_sameSet(referencedIds, exerciseIds.toSet())) {
      throw const FormatException('Gym warm-up references are incomplete.');
    }
    return GymPlanWarmups(
      exerciseIds: List.unmodifiable(exerciseIds),
      groups: List.unmodifiable(groups),
    );
  }

  static List<GymPlanLibraryPage> _parseLibraryPages(Object? value) {
    final rawPages = _list(value, 'library_pages');
    if (rawPages.length != 8) {
      throw const FormatException('Gym plan library pages are incomplete.');
    }
    final ids = <String>{};
    final pages = <GymPlanLibraryPage>[];
    for (final raw in rawPages) {
      final page = _object(raw, 'library_page');
      _exactKeys(page, const {'id', 'title', 'kind', 'description', 'filters'});
      final id = _safeId(page['id'], 'library_page.id');
      final kind = _safeId(page['kind'], 'library_page.kind');
      final filters = _textList(page['filters'], 'library_page.filters');
      if (!ids.add(id) ||
          !_libraryPageKinds.contains(kind) ||
          filters.isEmpty) {
        throw const FormatException('Gym plan library page is invalid.');
      }
      pages.add(
        GymPlanLibraryPage(
          id: id,
          title: _text(page['title'], 'library_page.title'),
          kind: kind,
          description: _text(page['description'], 'library_page.description'),
          filters: List.unmodifiable(filters),
        ),
      );
    }
    if (!_sameSet(ids, _libraryPageIds)) {
      throw const FormatException('Gym plan library page identities changed.');
    }
    return pages;
  }

  static List<String> _idList(Object? value, String field, {int? exactLength}) {
    final values = _list(value, field);
    if (exactLength != null && values.length != exactLength) {
      throw FormatException('$field has an invalid length.');
    }
    final ids = <String>[];
    final unique = <String>{};
    for (final value in values) {
      final id = _safeId(value, field);
      if (!unique.add(id)) {
        throw FormatException('$field contains a duplicate ID.');
      }
      ids.add(id);
    }
    return ids;
  }

  static List<String> _textList(Object? value, String field) {
    final values = _list(value, field);
    final result = <String>[];
    final unique = <String>{};
    for (final value in values) {
      final text = _text(value, field);
      if (!unique.add(text)) {
        throw FormatException('$field contains a duplicate value.');
      }
      result.add(text);
    }
    return result;
  }

  static Map<String, dynamic> _object(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$field must be an object.');
    }
    return value;
  }

  static List<dynamic> _list(Object? value, String field) {
    if (value is! List<dynamic>) {
      throw FormatException('$field must be a list.');
    }
    return value;
  }

  static String _safeId(Object? value, String field) {
    final id = _text(value, field);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id)) {
      throw FormatException('$field is not a safe ID.');
    }
    return id;
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      throw FormatException('$field must be non-empty trimmed text.');
    }
    return value;
  }

  static void _exactKeys(Map<String, dynamic> value, Set<String> expected) {
    final keys = value.keys.toSet();
    if (!_sameSet(keys, expected)) {
      throw const FormatException('Gym plan fields are invalid.');
    }
  }

  static bool _sameSet<T>(Set<T> left, Set<T> right) =>
      left.length == right.length && left.containsAll(right);

  static bool _sameList<T>(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
