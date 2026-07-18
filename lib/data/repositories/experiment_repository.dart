import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ExperimentRepository {
  const ExperimentRepository(this.database);
  final AppDatabase database;

  Stream<List<PersonalExperiment>> watchAll() =>
      (database.select(database.personalExperiments)
            ..where((row) => row.deletedAt.isNull())
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .watch();

  Future<int> create({
    required String hypothesis,
    required String changedVariable,
    required String controlledFactors,
    required String requiredData,
    required DateTime startedAt,
    required int durationDays,
  }) {
    if (hypothesis.trim().isEmpty || changedVariable.trim().isEmpty) {
      throw ArgumentError('Hypothesis and changed variable are required');
    }
    if (durationDays < 3 || durationDays > 90) {
      throw ArgumentError('Duration must be between 3 and 90 days');
    }
    return database
        .into(database.personalExperiments)
        .insert(
          PersonalExperimentsCompanion.insert(
            hypothesis: hypothesis.trim(),
            changedVariable: changedVariable.trim(),
            controlledFactors: Value(controlledFactors.trim()),
            requiredData: Value(requiredData.trim()),
            startedAt: startedAt,
            endsAt: startedAt.add(Duration(days: durationDays)),
          ),
        );
  }

  Future<void> complete({
    required int id,
    required double adherence,
    required String result,
    required String limitations,
    required String confidence,
  }) {
    if (adherence < 0 || adherence > 100) {
      throw ArgumentError.value(adherence, 'adherence');
    }
    if (!const {'insufficient', 'low', 'moderate'}.contains(confidence)) {
      throw ArgumentError.value(confidence, 'confidence');
    }
    return (database.update(
      database.personalExperiments,
    )..where((row) => row.id.equals(id))).write(
      PersonalExperimentsCompanion(
        adherence: Value(adherence),
        result: Value(result.trim()),
        limitations: Value(limitations.trim()),
        confidence: Value(confidence),
        status: const Value('completed'),
        updatedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> delete(int id) =>
      (database.update(
        database.personalExperiments,
      )..where((row) => row.id.equals(id))).write(
        PersonalExperimentsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pending'),
        ),
      );
}
