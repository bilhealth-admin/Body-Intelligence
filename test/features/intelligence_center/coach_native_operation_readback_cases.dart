part of 'coach_native_command_repository_test.dart';

void _nativeOperationReadbackCases(_NativeStore Function() currentStore) {
  for (final tool in _nativeInputs.keys) {
    test(
      'readback of $tool is read-only before commit and after Undo',
      () async {
        final store = currentStore();
        final command = await store.prepare(tool);
        final before = await store.snapshot();
        expect(
          await store.repository.readOperation(
            operationId: command.operationId,
            scope: store.scope,
          ),
          isNull,
        );
        expect(await store.snapshot(), before);
        expect(await store.journals(), isEmpty);
        final committed = await store.repository.commit(
          command: command,
          scope: store.scope,
        );
        final saved = await store.snapshot();
        final journals = await store.journals();
        final reopened = CoachNativeCommandRepository(store.database);
        final result = (await reopened.readOperation(
          operationId: committed.operationId,
          scope: store.scope,
        ))!;
        expect(result.canUndo, isTrue);
        expect(result.replayed, isFalse);
        expect(result.operationId, committed.operationId);
        expect(result.toolId, committed.toolId);
        expect(result.argumentsDigest, committed.argumentsDigest);
        expect(result.committedAt, committed.committedAt);
        expect(result.current.toJson(), committed.after.toJson());
        expect(await store.snapshot(), saved);
        expect(await store.journals(), journals);
        await store.undo(committed);
        final compensated = await store.snapshot();
        final undoJournals = await store.journals();
        final undone = (await reopened.readOperation(
          operationId: committed.operationId,
          scope: store.scope,
        ))!;
        expect(undone.state, CoachNativeResultState.undone);
        expect(undone.canUndo, isFalse);
        expect(undone.undoneAt, isNotNull);
        expect(undone.after.toJson(), committed.after.toJson());
        expect(await store.snapshot(), compensated);
        expect(await store.journals(), undoJournals);
      },
    );
  }

  test(
    'readback marks a later row version modified without repairing it',
    () async {
      final store = currentStore();
      final command = await store.prepare('log_weight');
      await store.repository.commit(command: command, scope: store.scope);
      await WeightRepository(store.database).addWeight(95, date: _nativeNow);
      final before = await store.snapshot();
      final journals = await store.journals();
      final result = (await store.repository.readOperation(
        operationId: command.operationId,
        scope: store.scope,
      ))!;
      expect(result.state, CoachNativeResultState.modified);
      expect(result.canUndo, isFalse);
      expect(result.after.weight!.weight, 82.4);
      expect(result.current.weight!.weight, 95);
      expect(await store.snapshot(), before);
      expect(await store.journals(), journals);
    },
  );

  for (final damage in [
    'broken JSON',
    'wrong owner',
    'wrong operation',
    'wrong digest',
  ]) {
    test('readback rejects $damage as uncommitted read failure', () async {
      final store = currentStore();
      final command = await store.prepare('log_water');
      await store.repository.commit(command: command, scope: store.scope);
      final row =
          (await store.database.select(store.database.preferences).get())
              .singleWhere(
                (row) => row.key.startsWith('coachNativeOperationV1.'),
              );
      final json = jsonDecode(row.value) as Map;
      switch (damage) {
        case 'wrong owner':
          json['ownerScope'] = 'foreign-scope';
        case 'wrong operation':
          (json['command'] as Map)['operationId'] = 'other-operation';
        case 'wrong digest':
          json['argumentsDigest'] = '0' * 64;
      }
      await PreferencesRepository(
        store.database,
      ).set(row.key, damage == 'broken JSON' ? '{broken' : jsonEncode(json));
      final before = await store.snapshot();
      final journals = await store.journals();
      await expectLater(
        store.repository.readOperation(
          operationId: command.operationId,
          scope: store.scope,
        ),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (e) => e.reason,
                'reason',
                CoachNativeConflictReason.invalidJournal,
              )
              .having((e) => e.committed, 'committed', isFalse),
        ),
      );
      expect(await store.snapshot(), before);
      expect(await store.journals(), journals);
    });
  }

  test('readback rejects owner change delivered inside journal read', () async {
    final store = currentStore();
    final command = await store.prepare('log_water');
    await store.repository.commit(command: command, scope: store.scope);
    final before = await store.snapshot();
    final journals = await store.journals();
    final repository = CoachNativeCommandRepository(
      store.database,
      preferences: _ReadbackOwnerChangePreferences(
        store.database,
        store.scope.cancel,
      ),
    );
    await expectLater(
      repository.readOperation(
        operationId: command.operationId,
        scope: store.scope,
      ),
      throwsA(
        isA<CoachNativeConflict>()
            .having(
              (e) => e.reason,
              'reason',
              CoachNativeConflictReason.ownerChanged,
            )
            .having((e) => e.committed, 'committed', isFalse),
      ),
    );
    expect(await store.snapshot(), before);
    expect(await store.journals(), journals);
  });

  test('readback failure does not claim that a new write committed', () async {
    final store = currentStore();
    final preferences = _LostJournalReadback(store.database)..armed = true;
    final before = await store.snapshot();
    final repository = CoachNativeCommandRepository(
      store.database,
      preferences: preferences,
    );
    await expectLater(
      repository.readOperation(
        operationId: 'missing-but-unavailable',
        scope: store.scope,
      ),
      throwsA(
        isA<CoachNativeConflict>()
            .having(
              (e) => e.reason,
              'reason',
              CoachNativeConflictReason.readbackUnavailable,
            )
            .having((e) => e.committed, 'committed', isFalse),
      ),
    );
    expect(await store.snapshot(), before);
    expect(await store.journals(), isEmpty);
  });

  test('foreign owner cannot read even a missing operation', () async {
    final store = currentStore();
    final before = await store.snapshot();
    await expectLater(
      store.repository.readOperation(
        operationId: 'missing',
        scope: CoachNativeOwnerScope(ownerId: 'owner-b', isCurrent: () => true),
      ),
      throwsA(
        isA<CoachNativeConflict>()
            .having(
              (e) => e.reason,
              'reason',
              CoachNativeConflictReason.ownerChanged,
            )
            .having((e) => e.committed, 'committed', isFalse),
      ),
    );
    expect(await store.snapshot(), before);
    expect(await store.journals(), isEmpty);
  });
}

class _ReadbackOwnerChangePreferences extends PreferencesRepository {
  _ReadbackOwnerChangePreferences(super.database, this.onRead);
  final void Function() onRead;
  @override
  Future<String?> get(String key) async {
    final result = await super.get(key);
    if (key.startsWith('coachNativeOperationV1.')) onRead();
    return result;
  }
}
