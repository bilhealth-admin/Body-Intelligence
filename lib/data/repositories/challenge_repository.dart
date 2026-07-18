import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../engine/challenge_engine.dart';

class ChallengeRepository {
  const ChallengeRepository(this.database);
  final AppDatabase database;

  Stream<List<Challenge>> watchAll() =>
      (database.select(database.challenges)
            ..where((row) => row.deletedAt.isNull())
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .watch();

  Future<int> start({
    required String type,
    required String title,
    required int targetDays,
    String audience = 'private',
    DateTime? startedAt,
  }) {
    if (!ChallengeEngine.supportedTypes.contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
    if (audience != 'private') {
      throw StateError(
        'Shared challenges require a configured authenticated service',
      );
    }
    if (targetDays < 1 || targetDays > 90) {
      throw ArgumentError.value(targetDays, 'targetDays');
    }
    final start = startedAt ?? DateTime.now();
    return database
        .into(database.challenges)
        .insert(
          ChallengesCompanion.insert(
            type: type,
            title: title,
            targetDays: targetDays,
            startedAt: start,
            endsAt: start.add(Duration(days: targetDays)),
          ),
        );
  }

  Future<void> markComplete(int id) =>
      (database.update(
        database.challenges,
      )..where((row) => row.id.equals(id))).write(
        ChallengesCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          revision: const Value(2),
          syncStatus: const Value('pending'),
        ),
      );

  Future<void> delete(int id) =>
      (database.update(
        database.challenges,
      )..where((row) => row.id.equals(id))).write(
        ChallengesCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pending'),
        ),
      );
}
