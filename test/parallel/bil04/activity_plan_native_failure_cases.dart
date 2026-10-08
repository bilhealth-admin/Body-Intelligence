part of 'activity_plan_native_test.dart';

void _healthNativeFailureCases(_HealthNativeStore Function() currentStore) {
  for (final tool in const ['log_exercise', 'activate_plan']) {
    test(
      '$tool durable commit survives lost readback without replaying health data',
      () async {
        final store = currentStore();
        final faulty = store.native(
          journalPreferences: _HealthLostReadbackPreferences(store.database),
        );
        final command = await store.prepare(faulty, tool, 'lost-readback');
        await expectLater(
          faulty.commit(command: command, scope: store.scope),
          throwsA(
            isA<CoachNativeConflict>()
                .having(
                  (error) => error.reason,
                  'reason',
                  CoachNativeConflictReason.readbackUnavailable,
                )
                .having((error) => error.committed, 'committed', true),
          ),
        );
        expect(await store.journals(), hasLength(1));
        if (tool == 'log_exercise') {
          expect(
            (await store.dailyLogs.getForDay(_now))!.exerciseNotes!.split('\n'),
            hasLength(1),
          );
        } else {
          expect(await store.plans.readActivePathway(), 'carb-cycling');
        }
        final durableLogs = await store.dailyLogs.getAll();
        final durableValues = await store.nonJournalPreferences();
        final restarted = store.native();
        final recovered = await restarted.readOperation(
          operationId: 'lost-readback',
          scope: store.scope,
        );
        expect(recovered!.state, CoachNativeResultState.committed);
        final rehydrated = await store.prepare(
          restarted,
          tool,
          'lost-readback',
        );
        final replay = await restarted.commit(
          command: rehydrated,
          scope: store.scope,
        );
        expect(replay.replayed, isTrue);
        expect(await store.dailyLogs.getAll(), durableLogs);
        expect(await store.nonJournalPreferences(), durableValues);
        expect(await store.journals(), hasLength(1));
      },
    );

    test(
      '$tool owner A-B-A observed during journal write cannot regain authority',
      () async {
        final store = currentStore();
        final native = store.native(
          journalPreferences: _HealthAfterJournalPreferences(store.database, () {
            store.owner = 'owner-b';
            // The native scope latches an observed owner transition; returning to
            // the old owner cannot authorize the old in-flight operation again.
            expect(store.scope.isCurrent, isFalse);
            store.owner = 'owner-a';
          }),
        );
        final command = await store.prepare(native, tool, 'owner-aba');
        await expectLater(
          native.commit(command: command, scope: store.scope),
          throwsA(
            isA<CoachNativeConflict>().having(
              (error) => error.reason,
              'reason',
              CoachNativeConflictReason.ownerChanged,
            ),
          ),
        );
        expect(store.owner, 'owner-a');
        expect(store.scope.isCurrent, isFalse);
        expect(await store.dailyLogs.getAll(), isEmpty);
        expect(await store.nonJournalPreferences(), isEmpty);
        expect(await store.journals(), isEmpty);
      },
    );

    test(
      '$tool permission epoch revocation after journal write rolls everything back',
      () async {
        final store = currentStore();
        var permissionEpoch = 0;
        final acceptedEpoch = permissionEpoch;
        final native = store.native(
          journalPreferences: _HealthAfterJournalPreferences(
            store.database,
            () {
              permissionEpoch += 1; // Allowed -> read-only.
              permissionEpoch +=
                  1; // Read-only -> allowed, a different attempt.
            },
          ),
        );
        final command = await store.prepare(native, tool, 'permission-aba');
        await expectLater(
          native.commit(
            command: command,
            scope: store.scope,
            checkWritePermission: () {
              if (permissionEpoch != acceptedEpoch) {
                throw StateError('health_permission_epoch_revoked');
              }
            },
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'health_permission_epoch_revoked',
            ),
          ),
        );
        expect(permissionEpoch, 2);
        expect(await store.dailyLogs.getAll(), isEmpty);
        expect(await store.nonJournalPreferences(), isEmpty);
        expect(await store.journals(), isEmpty);
      },
    );
  }

  test(
    'later identical plan activation fences Undo even when row timestamps share a second',
    () async {
      final store = currentStore();
      final second = _now.toUtc().millisecondsSinceEpoch ~/ 1000;
      const affectedKeys =
          "'activeNutritionPathway','goals.nutritionSchedule.v1','nutrition.dietDraft.v1.carb-cycling'";
      // Drift's default DateTime column stores whole seconds. Fix those three
      // timestamps deterministically to reproduce two rapid real activations
      // without a flaky wall-clock race. The native journal stays untouched.
      for (final event in const ['INSERT', 'UPDATE']) {
        await store.database.customStatement(
          'CREATE TRIGGER fixed_plan_time_${event.toLowerCase()} AFTER $event ON preferences '
          'WHEN NEW.key IN ($affectedKeys) AND NEW.updated_at != $second '
          'BEGIN UPDATE preferences SET updated_at = $second WHERE key = NEW.key; END',
        );
      }
      final native = store.native();
      final firstCommand = await store.prepare(
        native,
        'activate_plan',
        'plan-earlier',
      );
      final first = await native.commit(
        command: firstCommand,
        scope: store.scope,
      );
      final laterCommand = await store.prepare(
        native,
        'activate_plan',
        'plan-later',
      );
      final later = await native.commit(
        command: laterCommand,
        scope: store.scope,
      );
      expect(
        first.after.health!['preferences'],
        later.after.health!['preferences'],
      );
      expect(await store.journals(), hasLength(2));
      final read = await native.readOperation(
        operationId: first.operationId,
        scope: store.scope,
      );
      expect(read!.state, CoachNativeResultState.modified);
      expect(read.canUndo, isFalse);
      await expectLater(
        store.undo(native, first),
        throwsA(
          isA<CoachNativeConflict>().having(
            (error) => error.reason,
            'reason',
            CoachNativeConflictReason.staleRecord,
          ),
        ),
      );
      expect(await store.plans.readActivePathway(), 'carb-cycling');
      final latest = await native.readOperation(
        operationId: later.operationId,
        scope: store.scope,
      );
      expect(latest!.state, CoachNativeResultState.committed);
      expect(latest.canUndo, isTrue);
      await store.undo(native, later);
      final afterLaterUndo = await native.readOperation(
        operationId: first.operationId,
        scope: store.scope,
      );
      expect(afterLaterUndo!.state, CoachNativeResultState.modified);
      expect(afterLaterUndo.canUndo, isFalse);
    },
  );

  test(
    'unrelated health and foreign-owner journals preserve valid plan Undo',
    () async {
      final store = currentStore();
      final native = store.native();
      final planCommand = await store.prepare(
        native,
        'activate_plan',
        'plan-independent',
      );
      final plan = await native.commit(
        command: planCommand,
        scope: store.scope,
      );
      final activity = await store.prepare(
        native,
        'log_exercise',
        'exercise-independent',
      );
      await native.commit(command: activity, scope: store.scope);
      await store.preferences.set(
        'coachNativeOperationV1.account_foreign.foreign',
        '{foreign data}',
      );
      final read = await native.readOperation(
        operationId: plan.operationId,
        scope: store.scope,
      );
      expect(read!.state, CoachNativeResultState.committed);
      final beforeExercise = (await store.dailyLogs.getForDay(_now))!.toJson();
      final undo = await store.undo(native, plan);
      expect(undo.state, CoachNativeResultState.undone);
      expect(await store.plans.readActivePathway(), isNull);
      expect((await store.dailyLogs.getForDay(_now))!.toJson(), beforeExercise);
    },
  );

  test(
    'health overlap scan fails closed beyond 128 later same-owner journals',
    () async {
      final store = currentStore();
      final native = store.native();
      final planCommand = await store.prepare(
        native,
        'activate_plan',
        'bounded-plan',
      );
      final plan = await native.commit(
        command: planCommand,
        scope: store.scope,
      );
      CoachNativeCommit? lastWater;
      for (var index = 0; index < 129; index++) {
        final water = await store.prepare(
          native,
          'log_water',
          'bounded-water-$index',
          arguments: const {'amountMl': 250},
        );
        lastWater = await native.commit(command: water, scope: store.scope);
        if (index == 127) {
          final atLimit = await native.readOperation(
            operationId: plan.operationId,
            scope: store.scope,
          );
          expect(atLimit!.state, CoachNativeResultState.committed);
        }
      }
      final overLimit = await native.readOperation(
        operationId: plan.operationId,
        scope: store.scope,
      );
      expect(overLimit!.state, CoachNativeResultState.modified);
      expect(overLimit.canUndo, isFalse);
      await expectLater(
        store.undo(native, plan),
        throwsA(isA<CoachNativeConflict>()),
      );
      final legacyRead = await native.readOperation(
        operationId: lastWater!.operationId,
        scope: store.scope,
      );
      expect(legacyRead!.state, CoachNativeResultState.committed);
      expect(legacyRead.canUndo, isTrue);
      expect(await store.plans.readActivePathway(), 'carb-cycling');
    },
  );
}

class _HealthLostReadbackPreferences extends PreferencesRepository {
  _HealthLostReadbackPreferences(super.database);
  bool armed = false;

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      armed = true;
    }
  }

  @override
  Future<String?> get(String key) {
    if (armed && key.startsWith('coachNativeOperationV1.')) {
      throw StateError('Health commit readback unavailable');
    }
    return super.get(key);
  }
}

class _HealthAfterJournalPreferences extends PreferencesRepository {
  _HealthAfterJournalPreferences(super.database, this.afterJournal);
  final void Function() afterJournal;

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      afterJournal();
    }
  }
}
