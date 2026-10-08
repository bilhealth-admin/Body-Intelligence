import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_activity_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_plan_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'activity_plan_native_failure_cases.dart';

void main() {
  late _HealthNativeStore store;
  setUp(() => store = _HealthNativeStore());
  tearDown(() => store.database.close());
  _healthNativeFailureCases(() => store);

  test(
    'activity native replay, repository restart and Undo use one journal',
    () async {
      await store.dailyLogs.save(
        date: _now,
        notes: 'Private note',
        sleepHours: 7.5,
        steps: 6000,
        exerciseNotes: 'Legacy history',
      );
      final before = (await store.dailyLogs.getForDay(_now))!.toJson();
      final native = store.native();
      final command = await store.prepare(
        native,
        'log_exercise',
        'exercise-stable',
      );
      final results = await Future.wait([
        native.commit(command: command, scope: store.scope),
        native.commit(command: command, scope: store.scope),
      ]);
      expect(results.where((result) => result.replayed), hasLength(1));
      expect(await store.journals(), hasLength(1));
      final written = (await store.dailyLogs.getForDay(_now))!;
      expect(written.exerciseNotes!.split('\n'), hasLength(2));
      expect(results.first.after.receiptPayload(command)['recorded'], isTrue);

      final restarted = store.native();
      final rehydrated = await store.prepare(
        restarted,
        'log_exercise',
        'exercise-stable',
        now: DateTime(2026, 10, 8, 18),
      );
      expect(rehydrated.argumentsDigest, command.argumentsDigest);
      expect(rehydrated.resolved, command.resolved);
      final replay = await restarted.commit(
        command: rehydrated,
        scope: store.scope,
      );
      expect(replay.replayed, isTrue);
      expect(
        (await store.dailyLogs.getForDay(_now))!.exerciseNotes,
        written.exerciseNotes,
      );
      final read = await restarted.readOperation(
        operationId: 'exercise-stable',
        scope: store.scope,
      );
      expect(read!.state, CoachNativeResultState.committed);

      final undone = await store.undo(restarted, replay);
      expect(undone.state, CoachNativeResultState.undone);
      expect((await store.dailyLogs.getForDay(_now))!.toJson(), before);
      expect((await store.undo(restarted, replay)).replayed, isTrue);
      final afterUndoReplay = await restarted.commit(
        command: rehydrated,
        scope: store.scope,
      );
      expect(afterUndoReplay.state, CoachNativeResultState.undone);
      expect((await store.dailyLogs.getForDay(_now))!.toJson(), before);
      expect(await store.journals(), hasLength(1));
    },
  );

  test(
    'plan preview stays read-only while native activation has replay and Undo',
    () async {
      store.subscription = () async =>
          throw StateError('Free plan needs no subscription');
      final preview = await store.planAdapter().preview(
        pathwayId: 'carb-cycling',
        checkAccess: _allowed,
      );
      expect(preview['active'], isFalse);
      expect(await store.nonJournalPreferences(), isEmpty);
      expect(await store.journals(), isEmpty);
      final native = store.native();
      final command = await store.prepare(
        native,
        'activate_plan',
        'plan-stable',
      );
      expect(await store.nonJournalPreferences(), isEmpty);
      final committed = await native.commit(
        command: command,
        scope: store.scope,
      );
      expect(committed.after.receiptPayload(command)['active'], isTrue);
      expect(await store.plans.readActivePathway(), 'carb-cycling');
      expect((await store.schedule.read()).dayTargets, hasLength(7));

      final restarted = store.native();
      final same = await store.prepare(
        restarted,
        'activate_plan',
        'plan-stable',
      );
      final replay = await restarted.commit(command: same, scope: store.scope);
      expect(replay.replayed, isTrue);
      expect(await store.journals(), hasLength(1));
      final undone = await store.undo(restarted, replay);
      expect(undone.state, CoachNativeResultState.undone);
      expect(await store.plans.readActivePathway(), isNull);
      expect(await store.nonJournalPreferences(), isEmpty);
      expect((await store.schedule.read()).dayTargets, isEmpty);
      final read = await restarted.readOperation(
        operationId: 'plan-stable',
        scope: store.scope,
      );
      expect(read!.state, CoachNativeResultState.undone);
      expect(await store.journals(), hasLength(1));
    },
  );

  for (final tool in const ['log_exercise', 'activate_plan']) {
    test(
      '$tool rolls back its health mutation when the native journal fails',
      () async {
        final native = store.native();
        final command = await store.prepare(native, tool, 'journal-failure');
        await store.database.customStatement(
          "CREATE TRIGGER reject_health_journal BEFORE INSERT ON preferences WHEN NEW.key LIKE 'coachNativeOperationV1.%' BEGIN SELECT RAISE(ABORT, 'health_journal_failure'); END",
        );
        await expectLater(
          native.commit(command: command, scope: store.scope),
          throwsA(
            predicate(
              (error) => error.toString().contains('health_journal_failure'),
            ),
          ),
        );
        expect(await store.dailyLogs.getAll(), isEmpty);
        expect(await store.nonJournalPreferences(), isEmpty);
        expect(await store.journals(), isEmpty);
      },
    );

    test(
      '$tool native readback reports a later edit and denies stale Undo',
      () async {
        final native = store.native();
        final command = await store.prepare(native, tool, 'later-edit');
        final result = await native.commit(
          command: command,
          scope: store.scope,
        );
        if (tool == 'log_exercise') {
          await store.dailyLogs.updateSleepHours(date: _now, sleepHours: 8);
        } else {
          await store.schedule.saveMeal(
            'dinner',
            const NutritionGoalTarget(
              calories: 650,
              carbsPercent: 40,
              proteinPercent: 35,
              fatPercent: 25,
            ),
          );
        }
        final priorValues = await store.nonJournalPreferences();
        final priorLogs = await store.dailyLogs.getAll();
        final read = await native.readOperation(
          operationId: 'later-edit',
          scope: store.scope,
        );
        expect(read!.state, CoachNativeResultState.modified);
        expect(read.canUndo, isFalse);
        await expectLater(
          store.undo(native, result),
          throwsA(
            isA<CoachNativeConflict>().having(
              (error) => error.reason,
              'reason',
              CoachNativeConflictReason.staleRecord,
            ),
          ),
        );
        expect(await store.nonJournalPreferences(), priorValues);
        expect(await store.dailyLogs.getAll(), priorLogs);
        expect(await store.journals(), hasLength(1));
      },
    );
  }

  test(
    'cancelled owner scope cannot recover during a paid activation await',
    () async {
      final entered = Completer<void>();
      final granted = Completer<SubscriptionState>();
      store.subscription = () {
        entered.complete();
        return granted.future;
      };
      final native = store.native();
      final command = await store.prepare(
        native,
        'activate_plan',
        'owner-change',
        arguments: const {'pathwayId': 'high-protein'},
      );
      final pending = native.commit(command: command, scope: store.scope);
      final failure = expectLater(pending, throwsA(isA<CoachNativeConflict>()));
      await entered.future;
      store.scope.cancel();
      granted.complete(_premium());
      await failure;
      expect(await store.nonJournalPreferences(), isEmpty);
      expect(await store.journals(), isEmpty);
    },
  );
}

final _now = DateTime(2026, 10, 7, 14, 35, 20, 987, 456);

class _HealthNativeStore {
  _HealthNativeStore()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );

  final AppDatabase database;
  late final preferences = PreferencesRepository(database);
  late final dailyLogs = DailyLogRepository(database);
  late final weights = WeightRepository(database);
  late final schedule = NutritionGoalScheduleRepository(preferences);
  late final plans = DietPlanRepository(
    preferences: preferences,
    schedule: schedule,
  );
  late final scope = CoachNativeOwnerScope(
    ownerId: 'owner-a',
    isCurrent: () => owner == 'owner-a',
  );
  String? owner = 'owner-a';
  VerifiedSubscriptionLoader subscription = () async => _premium();

  CoachPlanCommandAdapter planAdapter() => CoachPlanCommandAdapter(
    database: database,
    command: DietPlanCommand(
      repository: plans,
      verifiedSubscription: () => subscription(),
    ),
  );

  CoachNativeCommandRepository native({
    PreferencesRepository? journalPreferences,
  }) => CoachNativeCommandRepository(
    database,
    preferences: journalPreferences ?? preferences,
    healthCommands: CoachHealthAdapters([
      CoachActivityCommandAdapter(
        dailyLogs: dailyLogs,
        restoreDailyLog: dailyLogs.restoreCoachRecord,
        weights: weights,
      ),
      planAdapter(),
    ]),
  );

  Future<CoachNativeCommand> prepare(
    CoachNativeCommandRepository repository,
    String toolId,
    String operationId, {
    Map<String, Object?>? arguments,
    DateTime? now,
  }) => repository.prepare(
    toolId: toolId,
    operationId: operationId,
    arguments:
        arguments ??
        (toolId == 'log_exercise'
            ? const {'date': '2026-10-07', 'workoutId': 'walk', 'minutes': 30}
            : const {'pathwayId': 'carb-cycling'}),
    scope: scope,
    now: now ?? _now,
  );

  Future<CoachNativeCommit> undo(
    CoachNativeCommandRepository repository,
    CoachNativeCommit operation,
  ) => repository.undo(
    operationId: operation.operationId,
    toolId: operation.toolId,
    argumentsDigest: operation.argumentsDigest,
    scope: scope,
  );

  Future<Map<String, String>> journals() async => {
    for (final row in await database.select(database.preferences).get())
      if (row.key.startsWith('coachNativeOperationV1.')) row.key: row.value,
  };

  Future<Map<String, String>> nonJournalPreferences() async => {
    for (final row in await database.select(database.preferences).get())
      if (!row.key.startsWith('coachNativeOperationV1.')) row.key: row.value,
  };
}

void _allowed() {}

SubscriptionState _premium() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {CommerceEntitlement.premiumPrograms},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: true,
);
