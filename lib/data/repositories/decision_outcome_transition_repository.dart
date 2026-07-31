import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

enum DurableDecisionOutcomeState { pending, succeeded, failed, abandoned }

/// Owns durable, append-only outcome transitions for persisted decisions.
///
/// Legacy `decision_memories.outcome` values are deliberately ignored: they
/// cannot be promoted into trusted success evidence without a new transition.
final class DecisionOutcomeTransitionRepository {
  DecisionOutcomeTransitionRepository(this.database);

  final AppDatabase database;

  Future<DecisionOutcomeTransition> append({
    required int decisionMemoryId,
    required String transitionUuid,
    required DurableDecisionOutcomeState fromState,
    required DurableDecisionOutcomeState toState,
    required String reason,
    required DateTime occurredAt,
    Iterable<String> evidenceIds = const <String>[],
  }) {
    return database.transaction(() async {
      final memory = await (database.select(
        database.decisionMemories,
      )..where((row) => row.id.equals(decisionMemoryId))).getSingleOrNull();
      if (memory == null) {
        throw StateError('Decision memory $decisionMemoryId does not exist.');
      }
      if (transitionUuid.trim().isEmpty) {
        throw ArgumentError.value(transitionUuid, 'transitionUuid');
      }
      if (reason.trim().isEmpty) {
        throw ArgumentError.value(reason, 'reason');
      }

      final history =
          await (database.select(database.decisionOutcomeTransitions)
                ..where((row) => row.decisionMemoryId.equals(decisionMemoryId))
                ..orderBy([
                  (row) => OrderingTerm.desc(row.occurredAt),
                  (row) => OrderingTerm.desc(row.id),
                ])
                ..limit(1))
              .get();
      final latest = history.isEmpty ? null : history.first;
      final current = latest == null
          ? DurableDecisionOutcomeState.pending
          : DurableDecisionOutcomeState.values.byName(latest.toState);

      if (fromState != current) {
        throw StateError(
          'Transition starts at ${fromState.name}; current state is ${current.name}.',
        );
      }
      if (!_isAllowed(fromState, toState)) {
        throw StateError(
          'Illegal outcome transition: ${fromState.name} -> ${toState.name}.',
        );
      }
      final lowerBound = latest?.occurredAt ?? memory.surfacedAt;
      if (occurredAt.isBefore(lowerBound)) {
        throw StateError('Outcome transition time must be append-only.');
      }

      final normalizedEvidence =
          evidenceIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final id = await database
          .into(database.decisionOutcomeTransitions)
          .insert(
            DecisionOutcomeTransitionsCompanion.insert(
              uuid: Value(transitionUuid.trim()),
              decisionMemoryId: decisionMemoryId,
              fromState: fromState.name,
              toState: toState.name,
              reason: reason.trim(),
              evidenceIdsJson: Value(jsonEncode(normalizedEvidence)),
              occurredAt: occurredAt,
            ),
          );
      return (database.select(
        database.decisionOutcomeTransitions,
      )..where((row) => row.id.equals(id))).getSingle();
    });
  }

  Stream<List<DecisionOutcomeTransition>> watchHistory(int decisionMemoryId) {
    return (database.select(database.decisionOutcomeTransitions)
          ..where((row) => row.decisionMemoryId.equals(decisionMemoryId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.occurredAt),
            (row) => OrderingTerm.asc(row.id),
          ]))
        .watch();
  }

  static bool _isAllowed(
    DurableDecisionOutcomeState from,
    DurableDecisionOutcomeState to,
  ) {
    return from == DurableDecisionOutcomeState.pending &&
        (to == DurableDecisionOutcomeState.succeeded ||
            to == DurableDecisionOutcomeState.failed ||
            to == DurableDecisionOutcomeState.abandoned);
  }
}
