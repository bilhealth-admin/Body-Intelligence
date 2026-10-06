part of 'coach_native_command_repository_test.dart';

void _nativeRepositoryCases() {
  late _NativeStore store;
  setUp(() async {
    store = _NativeStore();
    await store.seed();
  });
  tearDown(() => store.database.close());

  for (final tool in _nativeInputs.keys) {
    test(
      '$tool commits a durable readback and compensates its exact snapshot',
      () async {
        final command = await store.prepare(tool);
        final result = await store.repository.commit(
          command: command,
          scope: store.scope,
        );
        expect(result.state, CoachNativeResultState.committed);
        expect(result.operationId, command.operationId);
        expect(result.toolId, tool);
        expect(result.argumentsDigest, command.argumentsDigest);
        expect(result.canUndo, isTrue);
        expect(await store.journals(), hasLength(1));
        final after = result.after.receiptPayload(command);
        switch (tool) {
          case 'log_water':
            expect(after['amount_ml'], 250);
            expect(after['uuid'], isNotEmpty);
            expect(after['revision'], 1);
            expect(
              await WaterRepository(store.database).totalForDay(_nativeNow),
              250,
            );
          case 'log_weight':
            expect(after['weight_kg'], 82.4);
            expect(after['note'], 'Keep the note');
            expect(after['progress_photo_path'], 'private-progress.jpg');
            expect(after['measurement_context'], 'morning');
          case 'update_goal':
            expect(after['target_weight_kg'], 79);
            expect(after['goal_type'], 'lose');
            expect(
              (await GoalRepository(store.database).getActive())!.targetDate,
              DateTime(2026, 12, 15),
            );
          case 'save_measurements':
            expect(after['waistCm'], 87);
            expect(after['neckCm'], 38);
            expect(after['chestCm'], 101);
          case 'save_memory':
            expect(after['id'], 'memory-before');
            expect(after['kind'], 'routine');
            expect(result.before.receiptPayload(command)['exists'], isTrue);
        }
        final undone = await store.undo(result);
        expect(undone.state, CoachNativeResultState.undone);
        expect(undone.undoneAt, isNotNull);
        expect(undone.canUndo, isFalse);
        final current = undone.current.receiptPayload(command);
        switch (tool) {
          case 'log_water':
            expect(current['exists'], isFalse);
            expect(
              await WaterRepository(store.database).totalForDay(_nativeNow),
              0,
            );
          case 'log_weight':
            expect(current['weight_kg'], 90);
            expect(current['revision'], 3);
            expect(current['note'], 'Keep the note');
          case 'update_goal':
            expect(current['target_weight_kg'], 82);
            expect(await GoalRepository(store.database).getActive(), isNull);
          case 'save_measurements':
            expect(current['waistCm'], 90);
            expect(current['neckCm'], 38);
            expect(current['chestCm'], 101);
          case 'save_memory':
            expect(undone.current.memories, [_memory]);
        }
        expect(await store.journals(), hasLength(1));
      },
    );

    test(
      '$tool rolls back every data write when journal insertion fails',
      () async {
        final command = await store.prepare(tool);
        final before = await store.snapshot();
        await store.database.customStatement(
          "CREATE TRIGGER reject_native_journal BEFORE INSERT ON preferences WHEN NEW.key LIKE 'coachNativeOperationV1.%' BEGIN SELECT RAISE(ABORT, 'native_journal_failure'); END",
        );
        await expectLater(
          store.repository.commit(command: command, scope: store.scope),
          throwsA(
            predicate(
              (error) => error.toString().contains('native_journal_failure'),
            ),
          ),
        );
        expect(await store.snapshot(), before);
        expect(await store.journals(), isEmpty);
      },
    );
  }

  test(
    'same operation coalesces in the repository and survives repository recreation',
    () async {
      final command = await store.prepare(
        'log_water',
        operationId: 'water-stable',
      );
      final results = await Future.wait([
        store.repository.commit(command: command, scope: store.scope),
        store.repository.commit(command: command, scope: store.scope),
      ]);
      expect(results.where((value) => value.replayed), hasLength(1));
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        250,
      );
      final reopened = CoachNativeCommandRepository(store.database);
      final restored = await reopened.prepare(
        toolId: 'log_water',
        operationId: 'water-stable',
        arguments: {'amountMl': 250},
        scope: store.scope,
        now: _nativeNow.add(const Duration(days: 1)),
      );
      expect(restored.argumentsDigest, command.argumentsDigest);
      expect(restored.resolved, command.resolved);
      final replay = await reopened.commit(
        command: restored,
        scope: store.scope,
      );
      expect(replay.replayed, isTrue);
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        250,
      );
      final undos = await Future.wait([
        store.undo(results.first),
        store.undo(results.first),
      ]);
      expect(
        undos.every((result) => result.state == CoachNativeResultState.undone),
        isTrue,
      );
      expect(undos.where((result) => result.replayed), hasLength(1));
      final row = await store.database
          .select(store.database.waterEntries)
          .getSingle();
      expect(row.revision, 2);
      final afterUndoReplay = await reopened.commit(
        command: restored,
        scope: store.scope,
      );
      expect(afterUndoReplay.state, CoachNativeResultState.undone);
      expect(await WaterRepository(store.database).totalForDay(_nativeNow), 0);
    },
  );

  test(
    'equal requests with distinct operation IDs remain separate writes',
    () async {
      for (var index = 0; index < 2; index++) {
        final command = await store.prepare('log_water');
        await store.repository.commit(command: command, scope: store.scope);
      }
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        500,
      );
      expect(await store.journals(), hasLength(2));
    },
  );

  test(
    'a persisted operation rejects changed tool or changed arguments',
    () async {
      final command = await store.prepare(
        'log_water',
        operationId: 'bound-operation',
      );
      await store.repository.commit(command: command, scope: store.scope);
      for (final changed in [
        ('log_water', <String, Object?>{'amountMl': 500}),
        ('log_weight', <String, Object?>{'weightKg': 70}),
      ]) {
        await expectLater(
          store.prepare(
            changed.$1,
            operationId: 'bound-operation',
            arguments: changed.$2,
          ),
          throwsA(
            isA<CoachNativeConflict>().having(
              (error) => error.reason,
              'reason',
              CoachNativeConflictReason.operationMismatch,
            ),
          ),
        );
      }
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        250,
      );
      expect(
        (await WeightRepository(store.database).getForDay(_nativeNow))!.weight,
        90,
      );
    },
  );

  test(
    'owner change after an insert rolls back the insert and journal together',
    () async {
      final repository = CoachNativeCommandRepository(
        store.database,
        water: _CancelAfterWaterInsert(store.database, store.scope.cancel),
      );
      final command = await store.prepare('log_water', repository: repository);
      await expectLater(
        repository.commit(command: command, scope: store.scope),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.ownerChanged,
              )
              .having((error) => error.committed, 'committed', isFalse),
        ),
      );
      expect(
        await store.database.select(store.database.waterEntries).get(),
        isEmpty,
      );
      expect(await store.journals(), isEmpty);
    },
  );

  test('another owner cannot prepare against this database', () async {
    final scope = CoachNativeOwnerScope(
      ownerId: 'owner-b',
      isCurrent: () => true,
    );
    await expectLater(
      store.repository.prepare(
        toolId: 'log_water',
        operationId: 'foreign',
        arguments: {'amountMl': 250},
        scope: scope,
        now: _nativeNow,
      ),
      throwsA(
        isA<CoachNativeConflict>().having(
          (error) => error.reason,
          'reason',
          CoachNativeConflictReason.ownerChanged,
        ),
      ),
    );
    expect(
      await store.database.select(store.database.waterEntries).get(),
      isEmpty,
    );
  });

  test(
    'UUID replacement rejects Undo even when numeric ID and revision match',
    () async {
      final command = await store.prepare('log_weight');
      final result = await store.repository.commit(
        command: command,
        scope: store.scope,
      );
      final saved = result.after.weight!;
      await (store.database.update(store.database.weightEntries)
            ..where((row) => row.id.equals(saved.id)))
          .write(const WeightEntriesCompanion(uuid: Value('different-record')));
      await expectLater(
        store.undo(result),
        throwsA(
          isA<CoachNativeConflict>().having(
            (error) => error.reason,
            'reason',
            CoachNativeConflictReason.staleRecord,
          ),
        ),
      );
      final current = (await WeightRepository(
        store.database,
      ).getForDay(_nativeNow))!;
      expect(current.uuid, 'different-record');
      expect(current.weight, 82.4);
      expect(current.revision, saved.revision);
    },
  );

  test(
    'void measurement save cannot generate a receipt after an ignored database write',
    () async {
      final command = await store.prepare('save_measurements');
      final before = await store.snapshot();
      await store.database.customStatement(
        'CREATE TRIGGER ignore_measurement BEFORE INSERT ON body_measurement_entries BEGIN SELECT RAISE(IGNORE); END',
      );
      await expectLater(
        store.repository.commit(command: command, scope: store.scope),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.readbackUnavailable,
              )
              .having((error) => error.committed, 'committed', isFalse),
        ),
      );
      expect(await store.snapshot(), before);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'lost commit readback reports committed and a retry never duplicates data',
    () async {
      final preferences = _LostJournalReadback(store.database);
      final repository = CoachNativeCommandRepository(
        store.database,
        preferences: preferences,
      );
      final command = await store.prepare(
        'log_water',
        operationId: 'lost-readback',
        repository: repository,
      );
      await expectLater(
        repository.commit(command: command, scope: store.scope),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.readbackUnavailable,
              )
              .having((error) => error.committed, 'committed', isTrue),
        ),
      );
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        250,
      );
      expect(await store.journals(), hasLength(1));
      final replay = await store.repository.commit(
        command: command,
        scope: store.scope,
      );
      expect(replay.replayed, isTrue);
      expect(replay.after.water!.amountMl, 250);
      expect(
        await WaterRepository(store.database).totalForDay(_nativeNow),
        250,
      );
    },
  );

  test(
    'Undo verifies the compensated row and rolls back a changed readback',
    () async {
      final command = await store.prepare('log_weight');
      final committed = await store.repository.commit(
        command: command,
        scope: store.scope,
      );
      final saved = await store.snapshot();
      final journals = await store.journals();
      await store.database.customStatement(
        'CREATE TRIGGER rewrite_weight_undo AFTER UPDATE ON weight_entries '
        'WHEN NEW.weight = 90 BEGIN UPDATE weight_entries SET weight = 91 '
        'WHERE id = NEW.id; END',
      );
      await expectLater(
        store.undo(committed),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.readbackUnavailable,
              )
              .having((error) => error.committed, 'committed', isFalse),
        ),
      );
      expect(await store.snapshot(), saved);
      expect(await store.journals(), journals);
    },
  );

  test(
    'a changed memory collection cannot be overwritten by an older Undo',
    () async {
      final command = await store.prepare('save_memory');
      final result = await store.repository.commit(
        command: command,
        scope: store.scope,
      );
      final preferences = PreferencesRepository(store.database);
      final current =
          jsonDecode((await preferences.get(CoachMemoryRepository.storageKey))!)
              as List;
      current.add({..._memory, 'id': 'new-memory', 'text': 'A separate fact'});
      await preferences.set(
        CoachMemoryRepository.storageKey,
        jsonEncode(current),
      );
      await expectLater(
        store.undo(result),
        throwsA(
          isA<CoachNativeConflict>().having(
            (error) => error.reason,
            'reason',
            CoachNativeConflictReason.staleRecord,
          ),
        ),
      );
      expect(
        jsonDecode((await preferences.get(CoachMemoryRepository.storageKey))!),
        current,
      );
    },
  );
}
