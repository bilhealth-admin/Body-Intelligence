import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'coach_native_command_repository_cases.dart';
part 'coach_native_operation_readback_cases.dart';
part 'coach_native_undo_permission_repository_cases.dart';

final _nativeNow = DateTime(2026, 10, 6, 14, 35, 20, 987, 456);
const _memory = <String, Object?>{
  'id': 'memory-before',
  'text': 'Evening workouts',
  'kind': 'preference',
  'status': 'confirmed',
  'confidence': 1.0,
  'savedAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T09:00:00.000Z',
  'source': 'explicit_user_confirmation',
};

const _nativeInputs = <String, Map<String, Object?>>{
  'log_water': {'amountMl': 250},
  'log_weight': {'weightKg': 82.4, 'date': '2026-10-06'},
  'update_goal': {'targetWeightKg': 79, 'targetDate': '2026-12-15'},
  'save_measurements': {'waistCm': 87, 'date': '2026-10-06'},
  'save_memory': {'text': 'Evening workouts', 'kind': 'routine'},
};

void main() => _nativeRepositoryCases();

class _NativeStore {
  _NativeStore()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
  final AppDatabase database;
  late final repository = CoachNativeCommandRepository(database);
  late final scope = CoachNativeOwnerScope(
    ownerId: 'owner-a',
    isCurrent: () => currentOwner == 'owner-a',
  );
  String? currentOwner = 'owner-a';
  int next = 0;

  Future<void> seed() async {
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 180,
      currentWeight: 88,
      targetWeight: 82,
      activityLevel: 'moderate',
      exercises: true,
      waist: 90,
    );
    await WeightRepository(database).addWeight(
      90,
      date: _nativeNow,
      note: 'Keep the note',
      progressPhotoPath: 'private-progress.jpg',
      measurementContext: 'morning',
    );
    await BodyMeasurementRepository(
      database,
    ).saveForDay(date: _nativeNow, neckCm: 38, waistCm: 90, chestCm: 101);
    await PreferencesRepository(
      database,
    ).set(CoachMemoryRepository.storageKey, jsonEncode([_memory]));
  }

  Future<CoachNativeCommand> prepare(
    String tool, {
    String? operationId,
    Map<String, Object?>? arguments,
    CoachNativeCommandRepository? repository,
  }) => (repository ?? this.repository).prepare(
    toolId: tool,
    operationId: operationId ?? 'native-${next++}',
    arguments: arguments ?? _nativeInputs[tool]!,
    scope: scope,
    now: _nativeNow,
  );

  Future<CoachNativeCommit> undo(CoachNativeCommit committed) =>
      repository.undo(
        operationId: committed.operationId,
        toolId: committed.toolId,
        argumentsDigest: committed.argumentsDigest,
        scope: scope,
      );

  Future<List<String>> journals() async =>
      (await database.select(database.preferences).get())
          .where((row) => row.key.startsWith('coachNativeOperationV1.'))
          .map((row) => row.value)
          .toList(growable: false);

  Future<Map<String, Object?>> snapshot() async => {
    'water': (await database.select(database.waterEntries).get())
        .map((row) => row.toJson())
        .toList(),
    'weight': (await database.select(database.weightEntries).get())
        .map((row) => row.toJson())
        .toList(),
    'profile': (await database.select(database.userProfile).get())
        .map((row) => row.toJson())
        .toList(),
    'goals': (await database.select(database.goals).get())
        .map((row) => row.toJson())
        .toList(),
    'measurements':
        (await database.select(database.bodyMeasurementEntries).get())
            .map((row) => row.toJson())
            .toList(),
    'memories': await PreferencesRepository(
      database,
    ).get(CoachMemoryRepository.storageKey),
  };
}

class _CancelAfterWaterInsert extends WaterRepository {
  _CancelAfterWaterInsert(super.database, this.cancel);
  final void Function() cancel;
  @override
  Future<int> add({required DateTime occurredAt, required int amountMl}) async {
    final id = await super.add(occurredAt: occurredAt, amountMl: amountMl);
    cancel();
    return id;
  }
}

class _LostJournalReadback extends PreferencesRepository {
  _LostJournalReadback(super.database);
  bool armed = false;
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      armed = true;
    }
  }

  @override
  Future<String?> get(String key) {
    if (armed && key.startsWith('coachNativeOperationV1.')) {
      throw StateError('readback unavailable');
    }
    return super.get(key);
  }
}
