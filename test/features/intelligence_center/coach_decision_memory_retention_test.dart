import 'dart:io';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/decision_memory_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_privacy_boundary.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory directory;
  late File file;
  final baseline = DateTime.utc(2025, 1, 1);
  const hydration = BestAction(
    type: BestActionType.hydration,
    title: 'Drink water gradually',
    reason: 'Recorded water is below your saved target',
    evidence: ['saved water target'],
  );
  const weigh = BestAction(
    type: BestActionType.weighIn,
    title: 'Log today’s weight',
    reason: 'A measurement supports the weight trend',
    evidence: ['weight history'],
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bil-coach-decision-');
    file = File('${directory.path}${Platform.pathSeparator}retention.sqlite');
    db = AppDatabase.forTesting(
      NativeDatabase(file),
      localOwnerId: 'decision-owner',
    );
  });
  tearDown(() async {
    await db.close();
    final resolved = await directory.resolveSymbolicLinks();
    final parent = await Directory.systemTemp.resolveSymbolicLinks();
    if (!resolved.startsWith('$parent${Platform.pathSeparator}')) {
      throw StateError('Unsafe fixture cleanup');
    }
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final owned = File('${file.path}$suffix');
      if (await owned.exists()) await owned.delete();
    }
    await directory.delete();
  });
  Future<int> respondOld(
    BestAction action,
    DateTime at,
    String response,
  ) async {
    final repository = DecisionMemoryRepository(db);
    final id = await repository.rememberAction(action, date: at);
    await repository.respond(id, response);
    await (db.update(
      db.decisionMemories,
    )..where((row) => row.id.equals(id))).write(
      DecisionMemoriesCompanion(
        respondedAt: Value(at.add(const Duration(minutes: 1))),
      ),
    );
    return id;
  }

  Future<void> addUnanswered() async {
    for (var day = 3; day < 33; day++) {
      await DecisionMemoryRepository(
        db,
      ).rememberAction(weigh, date: baseline.add(Duration(days: day)));
    }
  }

  Future<List<Map<String, Object?>>> compact() async =>
      compactCoachDecisionMemories(
        await DecisionMemoryRepository(db).watchAll().first,
      );

  test(
    'recorded old refusal survives newer unrelated rows and real SQLite reopen within the same budget',
    () async {
      await respondOld(hydration, baseline, 'notSuitable');
      await addUnanswered();
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: 'decision-owner',
      );
      final rows = await compact();
      expect(rows.length, 10);
      expect(rows.first['recommendationKey'], 'hydration');
      expect(rows.first['response'], 'notSuitable');
      expect(
        rows.first['respondedAt'],
        baseline.add(const Duration(minutes: 1)).toIso8601String(),
      );
      expect(rows.first['source'], 'owner_decision_memory');
      expect(rows.first['responseScope'], 'recommendation_kind');
      final context = CoachContextSnapshot(
        generatedAt: DateTime.now(),
        profile: const {},
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
        decisionMemory: rows,
      );
      final water = projectCoachCloudContext(
        question: 'How much water did I drink?',
        context: context,
        conversation: const [],
      ).context;
      final shared = (water['decisionMemory'] as List).cast<Map>();
      expect(shared.single['response'], 'notSuitable');
      expect(
        shared.every((row) => row['recommendationKey'] != 'weighIn'),
        isTrue,
      );
      for (final question in ['Show my workout today', 'What is BIL?']) {
        expect(
          projectCoachCloudContext(
            question: question,
            context: context,
            conversation: const [],
          ).context.containsKey('decisionMemory'),
          isFalse,
        );
      }
    },
  );
  test(
    'a newer explicit acceptance supersedes an older refusal without treating resurfacing as a new decision',
    () async {
      final old = await respondOld(hydration, baseline, 'dismissed');
      await respondOld(
        hydration,
        baseline.add(const Duration(days: 1)),
        'accepted',
      );
      await addUnanswered();
      await (db.update(
        db.decisionMemories,
      )..where((row) => row.id.equals(old))).write(
        DecisionMemoriesCompanion(
          surfacedAt: Value(baseline.add(const Duration(days: 40))),
        ),
      );
      final rows = await compact();
      final memory = rows
          .where((row) => row['recommendationKey'] == 'hydration')
          .single;
      expect(memory['response'], 'accepted');
      expect(
        memory['respondedAt'],
        baseline.add(const Duration(days: 1, minutes: 1)).toIso8601String(),
      );
      expect(rows.length, lessThanOrEqualTo(10));
    },
  );
  test(
    'deleted refusal is never restored even when a raw tombstone reaches the selector',
    () async {
      final id = await respondOld(hydration, baseline, 'notSuitable');
      await addUnanswered();
      await DecisionMemoryRepository(db).delete(id);
      final raw = await db.select(db.decisionMemories).get();
      expect(raw.any((row) => row.id == id && row.deletedAt != null), isTrue);
      expect(
        compactCoachDecisionMemories(
          raw,
        ).any((row) => row['recommendationKey'] == 'hydration'),
        isFalse,
      );
    },
  );
}
