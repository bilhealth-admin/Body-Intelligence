import 'package:drift/drift.dart';

import '../database/app_database.dart';

class GoalRepository {
  GoalRepository(this._database);

  final AppDatabase _database;

  Future<int> save({
    String? uuid,
    required String profileUuid,
    required String type,
    required double targetWeight,
    DateTime? targetDate,
  }) async {
    if (!const {'lose', 'maintain', 'gain'}.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported goal type');
    }
    if (targetWeight < 20 || targetWeight > 500) {
      throw ArgumentError.value(
        targetWeight,
        'targetWeight',
        'Must be 20–500 kg',
      );
    }
    final existing = uuid == null
        ? null
        : await (_database.select(
            _database.goals,
          )..where((row) => row.uuid.equals(uuid))).getSingleOrNull();
    final companion = GoalsCompanion(
      id: existing == null ? const Value.absent() : Value(existing.id),
      uuid: uuid == null ? const Value.absent() : Value(uuid),
      profileUuid: Value(profileUuid),
      type: Value(type),
      targetWeight: Value(targetWeight),
      targetDate: Value(targetDate),
      createdAt: existing == null
          ? const Value.absent()
          : Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
      revision: Value((existing?.revision ?? 0) + 1),
      syncStatus: const Value('pending'),
    );
    return _database.into(_database.goals).insertOnConflictUpdate(companion);
  }

  Stream<Goal?> watchActive() {
    return (_database.select(_database.goals)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }
}
