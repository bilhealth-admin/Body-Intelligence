import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_durable_ports.dart';
import 'local_data_account_boundary.dart';

/// Summary of one local AppDatabase -> durable cloud outbox production pass.
final class CloudOutboxProductionReport {
  const CloudOutboxProductionReport({
    required this.enqueued,
    required this.skippedByPolicy,
    required this.remainingDirty,
  });

  final int enqueued;
  final int skippedByPolicy;
  final int remainingDirty;
}

/// Converts authoritative local BIL health rows into owner-scoped cloud
/// envelopes and durably enqueues them. It never performs network transport.
///
/// Rows are marked `queued` only after the durable sink accepts the exact row
/// revision. If a concurrent local edit changes that revision first, the row
/// remains dirty and will be produced again on a later pass.
final class AppDatabaseCloudOutboxProducer {
  AppDatabaseCloudOutboxProducer({
    required this._database,
    required this._accountBoundary,
    required this._sink,
  });

  final AppDatabase _database;
  final LocalDataAccountBoundary _accountBoundary;
  final CloudRecordOutboxSink _sink;

  Future<CloudOutboxProductionReport> produce({int maxRecords = 500}) async {
    if (maxRecords <= 0) {
      throw ArgumentError.value(maxRecords, 'maxRecords', 'Must be positive');
    }
    final boundOwner = await _accountBoundary.readBoundOwnerId();
    if (boundOwner == null || boundOwner != _sink.ownerId) {
      throw StateError('Local health data is not bound to the cloud owner.');
    }

    var remaining = maxRecords;
    var enqueued = 0;
    var skippedByPolicy = 0;

    Future<void> handle(
      CloudRecordEnvelope record,
      Future<void> Function() markQueued,
    ) async {
      if (remaining <= 0) return;
      if (!_sink.allows(record.entityKind)) {
        skippedByPolicy++;
        return;
      }
      remaining--;
      await _sink.enqueue(record);
      await markQueued();
      enqueued++;
    }

    final profileRows =
        await (_database.select(_database.userProfile)
              ..where((row) => _dirty(row.syncStatus))
              ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
            .get();
    for (final row in profileRows) {
      if (remaining <= 0) break;
      await handle(_profileEnvelope(row), () => _markProfileQueued(row));
    }

    final weightRows =
        await (_database.select(_database.weightEntries)
              ..where((row) => _dirty(row.syncStatus))
              ..orderBy([
                (row) => OrderingTerm.asc(row.updatedAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in weightRows) {
      if (remaining <= 0) break;
      await handle(_weightEnvelope(row), () => _markWeightQueued(row));
    }

    final waterRows =
        await (_database.select(_database.waterEntries)
              ..where((row) => _dirty(row.syncStatus))
              ..orderBy([
                (row) => OrderingTerm.asc(row.updatedAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in waterRows) {
      if (remaining <= 0) break;
      await handle(_waterEnvelope(row), () => _markWaterQueued(row));
    }

    final mealRows =
        await (_database.select(_database.meals)
              ..where((row) => _dirty(row.syncStatus))
              ..orderBy([
                (row) => OrderingTerm.asc(row.updatedAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in mealRows) {
      if (remaining <= 0) break;
      await handle(_mealEnvelope(row), () => _markMealQueued(row));
    }

    final itemRows =
        await (_database.select(_database.mealItems)
              ..where((row) => _dirty(row.syncStatus))
              ..orderBy([
                (row) => OrderingTerm.asc(row.updatedAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in itemRows) {
      if (remaining <= 0) break;
      final meal =
          await (_database.select(_database.meals)
                ..where((candidate) => candidate.id.equals(row.mealId)))
              .getSingleOrNull();
      final food =
          await (_database.select(_database.foods)
                ..where((candidate) => candidate.id.equals(row.foodId)))
              .getSingleOrNull();
      if (meal == null || food == null) {
        throw StateError(
          'Meal item ${row.uuid} has an invalid local reference.',
        );
      }
      await handle(
        _mealItemEnvelope(row, meal: meal, food: food),
        () => _markMealItemQueued(row),
      );
    }

    return CloudOutboxProductionReport(
      enqueued: enqueued,
      skippedByPolicy: skippedByPolicy,
      remainingDirty: await countDirtyRows(),
    );
  }

  Future<int> countDirtyRows() async {
    Future<int> count(String table) async {
      final row = await _database
          .customSelect(
            "SELECT COUNT(*) AS c FROM $table WHERE sync_status IN ('local','pending','pendingDelete')",
          )
          .getSingle();
      return row.read<int>('c');
    }

    return await count('user_profile') +
        await count('weight_entries') +
        await count('water_entries') +
        await count('meals') +
        await count('meal_items');
  }

  Expression<bool> _dirty(GeneratedColumn<String> status) =>
      status.equals('local') |
      status.equals('pending') |
      status.equals('pendingDelete');

  CloudRecordEnvelope _profileEnvelope(UserProfileData row) =>
      CloudRecordEnvelope(
        entityKind: CloudEntityKind.profile,
        recordId: row.uuid,
        ownerId: _sink.ownerId,
        revision: CloudRevision(
          deviceId: _sink.deviceId,
          sequence: row.revision,
        ),
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        payload: row.deletedAt != null
            ? const <String, Object?>{}
            : <String, Object?>{
                'gender': row.gender,
                'age': row.age,
                'height': row.height,
                'currentWeight': row.currentWeight,
                'targetWeight': row.targetWeight,
                'activityLevel': row.activityLevel,
                'exercises': row.exercises,
                'medicalConditions': row.medicalConditions,
                'waist': row.waist,
                'neck': row.neck,
                'chest': row.chest,
                'arm': row.arm,
                'thigh': row.thigh,
                'createdAt': row.createdAt.toUtc().toIso8601String(),
              },
      );

  CloudRecordEnvelope _weightEnvelope(WeightEntry row) => CloudRecordEnvelope(
    entityKind: CloudEntityKind.weight,
    recordId: row.uuid,
    ownerId: _sink.ownerId,
    revision: CloudRevision(deviceId: _sink.deviceId, sequence: row.revision),
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    payload: row.deletedAt != null
        ? const <String, Object?>{}
        : <String, Object?>{
            'date': row.date.toUtc().toIso8601String(),
            'dayKey': row.dayKey,
            'weight': row.weight,
            'note': row.note,
            'measurementContext': row.measurementContext,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
  );

  CloudRecordEnvelope _waterEnvelope(WaterEntry row) => CloudRecordEnvelope(
    entityKind: CloudEntityKind.hydration,
    recordId: row.uuid,
    ownerId: _sink.ownerId,
    revision: CloudRevision(deviceId: _sink.deviceId, sequence: row.revision),
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    payload: row.deletedAt != null
        ? const <String, Object?>{}
        : <String, Object?>{
            'occurredAt': row.occurredAt.toUtc().toIso8601String(),
            'dayKey': row.dayKey,
            'amountMl': row.amountMl,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
  );

  CloudRecordEnvelope _mealEnvelope(Meal row) => CloudRecordEnvelope(
    entityKind: CloudEntityKind.nutrition,
    recordId: 'meal:${row.uuid}',
    ownerId: _sink.ownerId,
    revision: CloudRevision(deviceId: _sink.deviceId, sequence: row.revision),
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    payload: row.deletedAt != null
        ? const <String, Object?>{}
        : <String, Object?>{
            'recordType': 'meal',
            'mealUuid': row.uuid,
            'date': row.date.toUtc().toIso8601String(),
            'dayKey': row.dayKey,
            'name': row.name,
            'type': row.type,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
  );

  CloudRecordEnvelope _mealItemEnvelope(
    MealItem row, {
    required Meal meal,
    required Food food,
  }) => CloudRecordEnvelope(
    entityKind: CloudEntityKind.nutrition,
    recordId: 'meal_item:${row.uuid}',
    ownerId: _sink.ownerId,
    revision: CloudRevision(deviceId: _sink.deviceId, sequence: row.revision),
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    payload: row.deletedAt != null
        ? const <String, Object?>{}
        : <String, Object?>{
            'recordType': 'mealItem',
            'mealUuid': meal.uuid,
            'itemUuid': row.uuid,
            'foodUuid': food.uuid,
            'foodName': food.name,
            'quantity': row.quantity,
            'position': row.position,
            'calories': row.calories,
            'protein': row.protein,
            'carbs': row.carbs,
            'fats': row.fats,
            'fiber': row.fiber,
            'sodium': row.sodium,
            'potassium': row.potassium,
            'calcium': row.calcium,
            'magnesium': row.magnesium,
            'phosphorus': row.phosphorus,
            'sugar': row.sugar,
            'nutrientEvidenceMask': row.nutrientEvidenceMask,
            'foodSourceSnapshot': row.foodSourceSnapshot,
            'foodVerifiedSnapshot': row.foodVerifiedSnapshot,
            'servingSizeSnapshot': row.servingSizeSnapshot,
            'servingUnitSnapshot': row.servingUnitSnapshot,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
  );

  Future<void> _markProfileQueued(UserProfileData row) async {
    await (_database.update(_database.userProfile)..where(
          (candidate) =>
              candidate.id.equals(row.id) &
              candidate.revision.equals(row.revision),
        ))
        .write(
          UserProfileCompanion(syncStatus: Value(_queuedStatus(row.deletedAt))),
        );
  }

  Future<void> _markWeightQueued(WeightEntry row) async {
    await (_database.update(_database.weightEntries)..where(
          (candidate) =>
              candidate.id.equals(row.id) &
              candidate.revision.equals(row.revision),
        ))
        .write(
          WeightEntriesCompanion(
            syncStatus: Value(_queuedStatus(row.deletedAt)),
          ),
        );
  }

  Future<void> _markWaterQueued(WaterEntry row) async {
    await (_database.update(_database.waterEntries)..where(
          (candidate) =>
              candidate.id.equals(row.id) &
              candidate.revision.equals(row.revision),
        ))
        .write(
          WaterEntriesCompanion(
            syncStatus: Value(_queuedStatus(row.deletedAt)),
          ),
        );
  }

  Future<void> _markMealQueued(Meal row) async {
    await (_database.update(_database.meals)..where(
          (candidate) =>
              candidate.id.equals(row.id) &
              candidate.revision.equals(row.revision),
        ))
        .write(MealsCompanion(syncStatus: Value(_queuedStatus(row.deletedAt))));
  }

  Future<void> _markMealItemQueued(MealItem row) async {
    await (_database.update(_database.mealItems)..where(
          (candidate) =>
              candidate.id.equals(row.id) &
              candidate.revision.equals(row.revision),
        ))
        .write(
          MealItemsCompanion(syncStatus: Value(_queuedStatus(row.deletedAt))),
        );
  }

  String _queuedStatus(DateTime? deletedAt) =>
      deletedAt == null ? 'queued' : 'queuedDelete';
}
