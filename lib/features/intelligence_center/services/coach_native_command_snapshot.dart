part of 'coach_native_command_repository.dart';

final class CoachNativeSnapshot {
  CoachNativeSnapshot({
    this.water,
    this.weight,
    this.profile,
    this.goal,
    this.measurement,
    List<Map<String, Object?>>? memories,
  }) : memories = memories == null
           ? null
           : List<Map<String, Object?>>.unmodifiable(
               memories.map(
                 (entry) => _freezeNativeJson(entry) as Map<String, Object?>,
               ),
             );

  final WaterEntry? water;
  final WeightEntry? weight;
  final UserProfileData? profile;
  final Goal? goal;
  final BodyMeasurementEntry? measurement;
  final List<Map<String, Object?>>? memories;

  Map<String, Object?>? memory(String id) {
    for (final entry in memories ?? const <Map<String, Object?>>[]) {
      if (entry['id'] == id) return entry;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'water': water?.toJson(),
    'weight': weight?.toJson(),
    'profile': profile?.toJson(),
    'goal': goal?.toJson(),
    'measurement': measurement?.toJson(),
    'memories': memories,
  };

  factory CoachNativeSnapshot._fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> row(String key) =>
        Map<String, dynamic>.from(raw[key] as Map);
    return CoachNativeSnapshot(
      water: raw['water'] == null ? null : WaterEntry.fromJson(row('water')),
      weight: raw['weight'] == null
          ? null
          : WeightEntry.fromJson(row('weight')),
      profile: raw['profile'] == null
          ? null
          : UserProfileData.fromJson(row('profile')),
      goal: raw['goal'] == null ? null : Goal.fromJson(row('goal')),
      measurement: raw['measurement'] == null
          ? null
          : BodyMeasurementEntry.fromJson(row('measurement')),
      memories: raw['memories'] == null
          ? null
          : (raw['memories'] as List)
                .map((entry) => Map<String, Object?>.from(entry as Map))
                .toList(growable: false),
    );
  }

  Map<String, Object?> receiptPayload(CoachNativeCommand command) {
    switch (command.kind) {
      case CoachNativeCommandKind.water:
        final value = water;
        return value == null
            ? const {'exists': false}
            : {
                'exists': value.deletedAt == null,
                'uuid': value.uuid,
                'revision': value.revision,
                'amount_ml': value.amountMl,
                'occurred_at': value.occurredAt.toIso8601String(),
                'day': value.dayKey,
              };
      case CoachNativeCommandKind.weight:
        final value = weight;
        return value == null
            ? const {'exists': false}
            : {
                'exists': value.deletedAt == null,
                'uuid': value.uuid,
                'revision': value.revision,
                'weight_kg': value.weight,
                'date': value.date.toIso8601String(),
                'note': value.note,
                'progress_photo_path': value.progressPhotoPath,
                'measurement_context': value.measurementContext,
              };
      case CoachNativeCommandKind.goal:
        return {
          'exists': goal != null && goal!.deletedAt == null,
          'uuid': goal?.uuid,
          'revision': goal?.revision,
          'goal_id': goal?.id,
          'goal_type': goal?.type,
          'profile_uuid': profile?.uuid,
          'profile_revision': profile?.revision,
          'target_weight_kg': profile?.targetWeight,
          'current_weight_kg': profile?.currentWeight,
          'target_date': goal?.targetDate?.toIso8601String(),
        };
      case CoachNativeCommandKind.measurements:
        final value = measurement;
        return value == null
            ? const {'exists': false}
            : {
                'exists': value.deletedAt == null,
                'uuid': value.uuid,
                'revision': value.revision,
                'date': value.date.toIso8601String(),
                'neckCm': value.neckCm,
                'waistCm': value.waistCm,
                'hipsCm': value.hipsCm,
                'chestCm': value.chestCm,
                'armCm': value.armCm,
                'thighCm': value.thighCm,
              };
      case CoachNativeCommandKind.memory:
        final value = memory(command.resolved['memoryId']! as String);
        return value == null
            ? const {'exists': false}
            : {'exists': true, ...value, 'version': _nativeDigest(value)};
    }
  }
}

extension _NativeSnapshotReads on CoachNativeCommandRepository {
  Future<T> _awaitOwner<T>(
    Future<T> Function() action,
    CoachNativeOwnerScope scope, {
    bool committed = false,
  }) async {
    scope.check(database.localOwnerId, committed: committed);
    final result = await action();
    scope.check(database.localOwnerId, committed: committed);
    return result;
  }

  Future<CoachNativeSnapshot> _readSnapshot(
    CoachNativeCommandKind kind,
    Map<String, Object?> resolved,
    CoachNativeOwnerScope scope, {
    int? waterId,
    bool committed = false,
  }) async {
    Future<T> read<T>(Future<T> Function() action) =>
        _awaitOwner(action, scope, committed: committed);
    switch (kind) {
      case CoachNativeCommandKind.water:
        return CoachNativeSnapshot(
          water: waterId == null
              ? null
              : await read(
                  () => (database.select(
                    database.waterEntries,
                  )..where((row) => row.id.equals(waterId))).getSingleOrNull(),
                ),
        );
      case CoachNativeCommandKind.weight:
        return CoachNativeSnapshot(
          weight: await read(
            () =>
                weights.getForDay(DateTime.parse(resolved['date']! as String)),
          ),
        );
      case CoachNativeCommandKind.goal:
        return CoachNativeSnapshot(
          profile: await read(profiles.getProfile),
          goal: await read(goals.getActive),
        );
      case CoachNativeCommandKind.measurements:
        return CoachNativeSnapshot(
          measurement: await read(
            () =>
                (database.select(database.bodyMeasurementEntries)..where(
                      (row) => row.dayKey.equals(resolved['date']! as String),
                    ))
                    .getSingleOrNull(),
          ),
        );
      case CoachNativeCommandKind.memory:
        final raw = await read(
          () => preferences.get(CoachMemoryRepository.storageKey),
        );
        return CoachNativeSnapshot(memories: _decodeNativeMemories(raw));
    }
  }
}

List<Map<String, Object?>> _decodeNativeMemories(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final parsed = jsonDecode(raw);
  if (parsed is! List || parsed.length > 50) {
    throw const FormatException('Invalid memory collection');
  }
  final result = <Map<String, Object?>>[];
  for (final entry in parsed) {
    if (entry is! Map ||
        entry['id'] is! String ||
        (entry['id'] as String).isEmpty ||
        entry['text'] is! String ||
        (entry['text'] as String).trim().isEmpty) {
      throw const FormatException('Invalid memory entry');
    }
    result.add(Map<String, Object?>.from(entry));
  }
  if (result.map((entry) => entry['id']).toSet().length != result.length) {
    throw const FormatException('Duplicate memory identity');
  }
  return result;
}

/// Sync acknowledgements may change transport metadata. Identity, revision,
/// deletion and every business field remain part of the comparison.
bool _sameNativeSnapshot(
  CoachNativeSnapshot expected,
  CoachNativeSnapshot actual,
) {
  Map<String, Object?> canonical(CoachNativeSnapshot snapshot) {
    final data = snapshot.toJson();
    for (final key in const [
      'water',
      'weight',
      'profile',
      'goal',
      'measurement',
    ]) {
      final row = data[key];
      if (row is Map) {
        data[key] = {...row}
          ..remove('updatedAt')
          ..remove('syncStatus');
      }
    }
    return data;
  }

  return _nativeDigest(canonical(expected)) == _nativeDigest(canonical(actual));
}
