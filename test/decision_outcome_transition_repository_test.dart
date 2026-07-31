import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/decision_outcome_transition_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DecisionOutcomeTransitionRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DecisionOutcomeTransitionRepository(database);
  });
  tearDown(() => database.close());

  test(
    'persists normalized append-only evidence without rewriting memory',
    () async {
      final memoryId = await _insertMemory(database, legacyOutcome: 'helped');
      final occurredAt = DateTime.utc(2026, 7, 31, 12);

      final transition = await repository.append(
        decisionMemoryId: memoryId,
        transitionUuid: 'transition-0001',
        fromState: DurableDecisionOutcomeState.pending,
        toState: DurableDecisionOutcomeState.succeeded,
        reason: 'Hydration target was completed.',
        occurredAt: occurredAt,
        evidenceIds: const ['water-entry-2', 'water-entry-1', 'water-entry-2'],
      );

      expect(transition.toState, 'succeeded');
      expect(jsonDecode(transition.evidenceIdsJson), [
        'water-entry-1',
        'water-entry-2',
      ]);
      final memory = await (database.select(
        database.decisionMemories,
      )..where((row) => row.id.equals(memoryId))).getSingle();
      expect(memory.outcome, 'helped');
      expect(memory.revision, 1);
    },
  );

  test('legacy outcome never becomes trusted success implicitly', () async {
    final memoryId = await _insertMemory(database, legacyOutcome: 'success');
    await repository.append(
      decisionMemoryId: memoryId,
      transitionUuid: 'transition-legacy-safe',
      fromState: DurableDecisionOutcomeState.pending,
      toState: DurableDecisionOutcomeState.failed,
      reason: 'New trusted evidence contradicted the legacy value.',
      occurredAt: DateTime.utc(2026, 7, 31, 12),
    );
    final rows = await database
        .select(database.decisionOutcomeTransitions)
        .get();
    expect(rows.single.fromState, 'pending');
    expect(rows.single.toState, 'failed');
  });

  test(
    'rejects duplicate, reverse-time, mismatched and illegal transitions',
    () async {
      final memoryId = await _insertMemory(database);
      final at = DateTime.utc(2026, 7, 31, 12);
      await repository.append(
        decisionMemoryId: memoryId,
        transitionUuid: 'transition-0002',
        fromState: DurableDecisionOutcomeState.pending,
        toState: DurableDecisionOutcomeState.abandoned,
        reason: 'User declined further tracking.',
        occurredAt: at,
      );

      await expectLater(
        repository.append(
          decisionMemoryId: memoryId,
          transitionUuid: 'transition-0003',
          fromState: DurableDecisionOutcomeState.pending,
          toState: DurableDecisionOutcomeState.failed,
          reason: 'Wrong starting state.',
          occurredAt: at,
        ),
        throwsStateError,
      );

      final otherMemory = await _insertMemory(database, key: 'walk');
      await expectLater(
        repository.append(
          decisionMemoryId: otherMemory,
          transitionUuid: 'transition-0002',
          fromState: DurableDecisionOutcomeState.pending,
          toState: DurableDecisionOutcomeState.succeeded,
          reason: 'Duplicate UUID.',
          occurredAt: at,
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.append(
          decisionMemoryId: otherMemory,
          transitionUuid: 'transition-0004',
          fromState: DurableDecisionOutcomeState.pending,
          toState: DurableDecisionOutcomeState.pending,
          reason: 'No state change.',
          occurredAt: at,
        ),
        throwsStateError,
      );
      await expectLater(
        repository.append(
          decisionMemoryId: otherMemory,
          transitionUuid: 'transition-0005',
          fromState: DurableDecisionOutcomeState.pending,
          toState: DurableDecisionOutcomeState.failed,
          reason: 'Predates the decision.',
          occurredAt: DateTime.utc(2026, 7, 30),
        ),
        throwsStateError,
      );
    },
  );
}

Future<int> _insertMemory(
  AppDatabase database, {
  String key = 'hydrate',
  String? legacyOutcome,
}) {
  return database
      .into(database.decisionMemories)
      .insert(
        DecisionMemoriesCompanion.insert(
          dayKey: '2026-07-31',
          recommendationKey: key,
          title: 'Test decision',
          reason: 'Test reason',
          surfacedAt: Value(DateTime.utc(2026, 7, 31, 10)),
          outcome: Value<String?>(legacyOutcome),
        ),
      );
}
