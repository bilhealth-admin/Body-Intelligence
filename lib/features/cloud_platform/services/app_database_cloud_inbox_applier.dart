import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../domain/cloud_sync_models.dart';
import 'local_data_account_boundary.dart';

final class CloudInboxApplyReport {
  const CloudInboxApplyReport({
    required this.applied,
    required this.acknowledged,
    required this.localWins,
    required this.unsupported,
    required this.conflicts,
  });

  final int applied;
  final int acknowledged;
  final int localWins;
  final int unsupported;
  final int conflicts;
}

/// Applies decrypted owner-scoped cloud inbox records to the authoritative
/// local BIL database without ever initiating network transport.
///
/// Phase 3C intentionally supports only profile, weight and hydration. Meals
/// remain local-only until their relational merge (meal + item + food
/// snapshots) is closed separately. The local progress-photo path is never
/// read from or overwritten by cloud data.
final class AppDatabaseCloudInboxApplier {
  AppDatabaseCloudInboxApplier({
    required AppDatabase database,
    required LocalDataAccountBoundary accountBoundary,
  }) : _database = database,
       _accountBoundary = accountBoundary;

  final AppDatabase _database;
  final LocalDataAccountBoundary _accountBoundary;

  Future<CloudInboxApplyReport> apply({
    required String ownerId,
    required String localDeviceId,
    required Iterable<CloudRecordEnvelope> records,
  }) async {
    final owner = ownerId.trim();
    final device = localDeviceId.trim();
    if (owner.isEmpty || device.isEmpty) {
      throw ArgumentError('Owner and local device id must not be empty.');
    }
    final boundOwner = await _accountBoundary.readBoundOwnerId();
    if (boundOwner != owner) {
      throw StateError('Local health data is not bound to the cloud owner.');
    }
    final batch = records.toList(growable: false);
    if (batch.any((record) => record.ownerId != owner)) {
      throw StateError('Cross-account cloud inbox batch rejected.');
    }

    var applied = 0;
    var acknowledged = 0;
    var localWins = 0;
    var unsupported = 0;
    var conflicts = 0;

    await _database.transaction(() async {
      for (final record in batch) {
        final outcome = switch (record.entityKind) {
          CloudEntityKind.profile => _applyProfile(record, device),
          CloudEntityKind.weight => _applyWeight(record, device),
          CloudEntityKind.hydration => _applyHydration(record, device),
          _ => Future<_InboxOutcome>.value(_InboxOutcome.unsupported),
        };
        switch (await outcome) {
          case _InboxOutcome.applied:
            applied++;
          case _InboxOutcome.acknowledged:
            acknowledged++;
          case _InboxOutcome.localWins:
            localWins++;
          case _InboxOutcome.unsupported:
            unsupported++;
          case _InboxOutcome.conflict:
            conflicts++;
        }
      }
    });

    return CloudInboxApplyReport(
      applied: applied,
      acknowledged: acknowledged,
      localWins: localWins,
      unsupported: unsupported,
      conflicts: conflicts,
    );
  }

  Future<_InboxOutcome> _applyProfile(
    CloudRecordEnvelope record,
    String localDeviceId,
  ) async {
    final existing =
        await (_database.select(_database.userProfile)
              ..where((row) => row.uuid.equals(record.recordId))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      if (record.isTombstone) return _InboxOutcome.acknowledged;
      final anyProfile = await (_database.select(
        _database.userProfile,
      )..limit(1)).getSingleOrNull();
      if (anyProfile != null) return _InboxOutcome.conflict;
      final payload = record.payload;
      await _database
          .into(_database.userProfile)
          .insert(
            UserProfileCompanion.insert(
              uuid: Value(record.recordId),
              gender: _requiredString(payload, 'gender'),
              age: _requiredInt(payload, 'age'),
              height: _requiredDouble(payload, 'height'),
              currentWeight: _requiredDouble(payload, 'currentWeight'),
              targetWeight: _requiredDouble(payload, 'targetWeight'),
              activityLevel: _requiredString(payload, 'activityLevel'),
              exercises: _requiredBool(payload, 'exercises'),
              medicalConditions: Value(
                _nullableString(payload, 'medicalConditions'),
              ),
              waist: Value(_nullableDouble(payload, 'waist')),
              neck: Value(_nullableDouble(payload, 'neck')),
              chest: Value(_nullableDouble(payload, 'chest')),
              arm: Value(_nullableDouble(payload, 'arm')),
              thigh: Value(_nullableDouble(payload, 'thigh')),
              createdAt: Value(_requiredDate(payload, 'createdAt')),
              updatedAt: Value(record.updatedAt),
              revision: Value(record.revision.sequence),
              syncStatus: const Value('synced'),
            ),
          );
      return _InboxOutcome.applied;
    }

    final decision = _compareLocal(
      localUpdatedAt: existing.updatedAt,
      localRevision: existing.revision,
      localSyncStatus: existing.syncStatus,
      remote: record,
      localDeviceId: localDeviceId,
    );
    if (decision != _InboxOutcome.applied &&
        decision != _InboxOutcome.acknowledged) {
      return decision;
    }

    if (record.isTombstone) {
      await (_database.update(
        _database.userProfile,
      )..where((row) => row.id.equals(existing.id))).write(
        UserProfileCompanion(
          updatedAt: Value(record.updatedAt),
          deletedAt: Value(record.deletedAt),
          revision: Value(record.revision.sequence),
          syncStatus: const Value('synced'),
        ),
      );
      return decision;
    }

    final payload = record.payload;
    await (_database.update(
      _database.userProfile,
    )..where((row) => row.id.equals(existing.id))).write(
      UserProfileCompanion(
        gender: Value(_requiredString(payload, 'gender')),
        age: Value(_requiredInt(payload, 'age')),
        height: Value(_requiredDouble(payload, 'height')),
        currentWeight: Value(_requiredDouble(payload, 'currentWeight')),
        targetWeight: Value(_requiredDouble(payload, 'targetWeight')),
        activityLevel: Value(_requiredString(payload, 'activityLevel')),
        exercises: Value(_requiredBool(payload, 'exercises')),
        medicalConditions: Value(_nullableString(payload, 'medicalConditions')),
        waist: Value(_nullableDouble(payload, 'waist')),
        neck: Value(_nullableDouble(payload, 'neck')),
        chest: Value(_nullableDouble(payload, 'chest')),
        arm: Value(_nullableDouble(payload, 'arm')),
        thigh: Value(_nullableDouble(payload, 'thigh')),
        updatedAt: Value(record.updatedAt),
        deletedAt: const Value<DateTime?>(null),
        revision: Value(record.revision.sequence),
        syncStatus: const Value('synced'),
      ),
    );
    return decision;
  }

  Future<_InboxOutcome> _applyWeight(
    CloudRecordEnvelope record,
    String localDeviceId,
  ) async {
    final existing =
        await (_database.select(_database.weightEntries)
              ..where((row) => row.uuid.equals(record.recordId))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      if (record.isTombstone) return _InboxOutcome.acknowledged;
      final payload = record.payload;
      await _database
          .into(_database.weightEntries)
          .insert(
            WeightEntriesCompanion.insert(
              uuid: Value(record.recordId),
              date: Value(_requiredDate(payload, 'date')),
              dayKey: Value(_nullableString(payload, 'dayKey')),
              weight: _requiredDouble(payload, 'weight'),
              note: Value(_nullableString(payload, 'note')),
              measurementContext: Value(
                _nullableString(payload, 'measurementContext') ??
                    'differentConditions',
              ),
              createdAt: Value(_requiredDate(payload, 'createdAt')),
              updatedAt: Value(record.updatedAt),
              revision: Value(record.revision.sequence),
              syncStatus: const Value('synced'),
            ),
          );
      return _InboxOutcome.applied;
    }

    final decision = _compareLocal(
      localUpdatedAt: existing.updatedAt,
      localRevision: existing.revision,
      localSyncStatus: existing.syncStatus,
      remote: record,
      localDeviceId: localDeviceId,
    );
    if (decision != _InboxOutcome.applied &&
        decision != _InboxOutcome.acknowledged) {
      return decision;
    }

    if (record.isTombstone) {
      await (_database.update(
        _database.weightEntries,
      )..where((row) => row.id.equals(existing.id))).write(
        WeightEntriesCompanion(
          updatedAt: Value(record.updatedAt),
          deletedAt: Value(record.deletedAt),
          revision: Value(record.revision.sequence),
          syncStatus: const Value('synced'),
        ),
      );
      return decision;
    }

    final payload = record.payload;
    await (_database.update(
      _database.weightEntries,
    )..where((row) => row.id.equals(existing.id))).write(
      WeightEntriesCompanion(
        date: Value(_requiredDate(payload, 'date')),
        dayKey: Value(_nullableString(payload, 'dayKey')),
        weight: Value(_requiredDouble(payload, 'weight')),
        note: Value(_nullableString(payload, 'note')),
        measurementContext: Value(
          _nullableString(payload, 'measurementContext') ??
              'differentConditions',
        ),
        updatedAt: Value(record.updatedAt),
        deletedAt: const Value<DateTime?>(null),
        revision: Value(record.revision.sequence),
        syncStatus: const Value('synced'),
      ),
    );
    return decision;
  }

  Future<_InboxOutcome> _applyHydration(
    CloudRecordEnvelope record,
    String localDeviceId,
  ) async {
    final existing =
        await (_database.select(_database.waterEntries)
              ..where((row) => row.uuid.equals(record.recordId))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      if (record.isTombstone) return _InboxOutcome.acknowledged;
      final payload = record.payload;
      await _database
          .into(_database.waterEntries)
          .insert(
            WaterEntriesCompanion.insert(
              uuid: Value(record.recordId),
              occurredAt: _requiredDate(payload, 'occurredAt'),
              dayKey: _requiredString(payload, 'dayKey'),
              amountMl: _requiredInt(payload, 'amountMl'),
              createdAt: Value(_requiredDate(payload, 'createdAt')),
              updatedAt: Value(record.updatedAt),
              revision: Value(record.revision.sequence),
              syncStatus: const Value('synced'),
            ),
          );
      return _InboxOutcome.applied;
    }

    final decision = _compareLocal(
      localUpdatedAt: existing.updatedAt,
      localRevision: existing.revision,
      localSyncStatus: existing.syncStatus,
      remote: record,
      localDeviceId: localDeviceId,
    );
    if (decision != _InboxOutcome.applied &&
        decision != _InboxOutcome.acknowledged) {
      return decision;
    }

    if (record.isTombstone) {
      await (_database.update(
        _database.waterEntries,
      )..where((row) => row.id.equals(existing.id))).write(
        WaterEntriesCompanion(
          updatedAt: Value(record.updatedAt),
          deletedAt: Value(record.deletedAt),
          revision: Value(record.revision.sequence),
          syncStatus: const Value('synced'),
        ),
      );
      return decision;
    }

    final payload = record.payload;
    await (_database.update(
      _database.waterEntries,
    )..where((row) => row.id.equals(existing.id))).write(
      WaterEntriesCompanion(
        occurredAt: Value(_requiredDate(payload, 'occurredAt')),
        dayKey: Value(_requiredString(payload, 'dayKey')),
        amountMl: Value(_requiredInt(payload, 'amountMl')),
        updatedAt: Value(record.updatedAt),
        deletedAt: const Value<DateTime?>(null),
        revision: Value(record.revision.sequence),
        syncStatus: const Value('synced'),
      ),
    );
    return decision;
  }

  _InboxOutcome _compareLocal({
    required DateTime localUpdatedAt,
    required int localRevision,
    required String localSyncStatus,
    required CloudRecordEnvelope remote,
    required String localDeviceId,
  }) {
    final timeOrder = localUpdatedAt.toUtc().compareTo(remote.updatedAt);
    if (timeOrder > 0) return _InboxOutcome.localWins;
    if (timeOrder < 0) return _InboxOutcome.applied;
    if (localRevision > remote.revision.sequence) {
      return _InboxOutcome.localWins;
    }
    if (localRevision < remote.revision.sequence) {
      return _InboxOutcome.applied;
    }
    if (remote.revision.deviceId == localDeviceId) {
      return _InboxOutcome.acknowledged;
    }
    if (_isDirtyOrQueued(localSyncStatus)) {
      return _InboxOutcome.conflict;
    }
    return _InboxOutcome.conflict;
  }

  bool _isDirtyOrQueued(String value) => const <String>{
    'local',
    'pending',
    'pendingDelete',
    'queued',
    'queuedDelete',
  }.contains(value);

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value;
  }

  static String? _nullableString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num || value.toInt() != value) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value.toInt();
  }

  static double _requiredDouble(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value.toDouble();
  }

  static double? _nullableDouble(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value.toDouble();
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! bool) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null) {
      throw FormatException('Invalid cloud payload field: $key');
    }
    return parsed;
  }
}

enum _InboxOutcome { applied, acknowledged, localWins, unsupported, conflict }
