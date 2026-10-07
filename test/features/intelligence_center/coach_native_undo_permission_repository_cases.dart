part of 'coach_native_command_repository_test.dart';

void _nativeUndoPermissionRepositoryCases(_NativeStore Function() current) {
  for (final tool in _nativeInputs.keys) {
    for (final afterWrite in [false, true]) {
      test(
        '$tool Undo permission rolls back rows and journal afterWrite=$afterWrite',
        () async {
          final store = current();
          final command = await store.prepare(tool);
          final saved = await store.repository.commit(
            command: command,
            scope: store.scope,
          );
          final before = await store.snapshot();
          final journal = await store.journals();
          var permitted = afterWrite;
          final preferences = _RevokeUndoAfterJournal(
            store.database,
            () => permitted = false,
          );
          final repository = CoachNativeCommandRepository(
            store.database,
            preferences: preferences,
          );
          await expectLater(
            repository.undo(
              operationId: saved.operationId,
              toolId: saved.toolId,
              argumentsDigest: saved.argumentsDigest,
              scope: store.scope,
              checkWritePermission: () {
                if (!permitted) throw StateError('write_permission_revoked');
              },
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'reason',
                'write_permission_revoked',
              ),
            ),
          );
          expect(preferences.undoWrites, afterWrite ? 1 : 0);
          expect(await store.snapshot(), before);
          expect(await store.journals(), journal);
          final readback = await store.repository.readOperation(
            operationId: saved.operationId,
            scope: store.scope,
          );
          expect(readback!.canUndo, isTrue);
          final undone = await store.repository.undo(
            operationId: saved.operationId,
            toolId: saved.toolId,
            argumentsDigest: saved.argumentsDigest,
            scope: store.scope,
            checkWritePermission: () {},
          );
          expect(undone.state, CoachNativeResultState.undone);
          expect(undone.undoneAt, isNotNull);
        },
      );
    }
  }
}

class _RevokeUndoAfterJournal extends PreferencesRepository {
  _RevokeUndoAfterJournal(super.database, this.revoke);
  final void Function() revoke;
  int undoWrites = 0;
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    if (values.keys.any((key) => key.startsWith('coachNativeOperationV1.'))) {
      undoWrites++;
      revoke();
    }
  }
}
