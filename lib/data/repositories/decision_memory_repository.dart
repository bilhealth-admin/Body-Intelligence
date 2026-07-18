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
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        response: Value(response),
        respondedAt: Value(DateTime.now()),
        revision: const Value(2),
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
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        helpfulness: Value(helpfulness),
        outcome: Value(outcome),
        evaluatedAt: Value(DateTime.now()),
        revision: const Value(3),
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
    await (database.update(
      database.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        deletedAt: Value(DateTime.now()),
        revision: const Value(2),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }
}
