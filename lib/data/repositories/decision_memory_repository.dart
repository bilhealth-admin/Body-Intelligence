import 'dart:convert';

import 'package:drift/drift.dart';

import '../../engine/one_best_action_engine.dart';
import '../database/app_database.dart';
import '../database/date_keys.dart';

class DecisionMemoryRepository {
  DecisionMemoryRepository(this.database);

  final AppDatabase database;

  Future<int> rememberAction(BestAction action, {DateTime? date}) async {
    final occurredAt = date ?? DateTime.now();
    final key = dayKeyFor(occurredAt);
    final existing =
        await (database.select(database.decisionMemories)..where(
              (row) =>
                  row.dayKey.equals(key) &
                  row.recommendationKey.equals(action.type.name),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (database.update(
        database.decisionMemories,
      )..where((row) => row.id.equals(existing.id))).write(
        DecisionMemoriesCompanion(
          title: Value(action.title),
          reason: Value(action.reason),
          evidenceJson: Value(jsonEncode(action.evidence)),
          surfacedAt: Value(occurredAt),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
      return existing.id;
    }
    return database
        .into(database.decisionMemories)
        .insert(
          DecisionMemoriesCompanion.insert(
            dayKey: key,
            recommendationKey: action.type.name,
            title: action.title,
            reason: action.reason,
            evidenceJson: Value(jsonEncode(action.evidence)),
            surfacedAt: Value(occurredAt),
          ),
        );
  }

  Future<void> respond(int id, String response) async {
    if (!const {
      'accepted',
      'dismissed',
      'notSuitable',
      'done',
    }.contains(response)) {
      throw ArgumentError.value(response, 'response');
    }
    final revision = await _nextRevision(id);
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        response: Value(response),
        respondedAt: Value(DateTime.now()),
        revision: Value(revision),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> evaluate({
    required int id,
    required int helpfulness,
    String? outcome,
  }) async {
    if (helpfulness < 1 || helpfulness > 5) {
      throw ArgumentError.value(helpfulness, 'helpfulness', 'Must be 1–5');
    }
    final revision = await _nextRevision(id);
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        helpfulness: Value(helpfulness),
        outcome: Value(outcome),
        evaluatedAt: Value(DateTime.now()),
        revision: Value(revision),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Stream<List<DecisionMemory>> watchAll() {
    return (database.select(database.decisionMemories)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.surfacedAt)]))
        .watch();
  }

  Future<void> delete(int id) async {
    final revision = await _nextRevision(id);
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        deletedAt: Value(DateTime.now()),
        revision: Value(revision),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }

  /// Forgets only memories the user explicitly rated as unhelpful. Nothing is
  /// removed automatically, and sync metadata retains a deletion tombstone.
  Future<int> forgetUnhelpful() async {
    final rows =
        await (database.select(database.decisionMemories)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.helpfulness.isSmallerOrEqualValue(2),
            ))
            .get();
    for (final row in rows) {
      await delete(row.id);
    }
    return rows.length;
  }

  Future<int> _nextRevision(int id) async {
    final row = await (database.select(
      database.decisionMemories,
    )..where((entry) => entry.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('Decision memory $id does not exist');
    return row.revision + 1;
  }
}
