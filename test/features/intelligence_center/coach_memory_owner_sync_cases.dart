part of 'coach_memory_owner_sync_test.dart';

void _memoryOwnerSyncCases() {
  late _MemorySyncStore store;
  // Supabase workers and auxiliary subscription disposal belong to the outer
  // test runner, never to a widget test's fake clock.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _MemorySyncStore();
    await store.initialize();
  });
  tearDown(() => store.dispose());

  for (final roundTrip in [false, true]) {
    test(
      'memory consent wait rejects an owner ${roundTrip ? 'A-B-A round trip' : 'A-B switch'}',
      () async {
        store.consentBlock = Completer<void>();
        final pending = store.sync();
        await store.consentEntered.future.timeout(const Duration(seconds: 10));
        if (roundTrip) {
          await store.roundTrip();
        } else {
          await store.client.auth.recoverSession(
            jsonEncode(_memorySession(_ownerB)),
          );
          await store.deliveredB.future.timeout(const Duration(seconds: 10));
        }
        store.consentBlock!.complete();
        await pending;
        expect(store.writes, isEmpty);
        expect(await store.repository.readLocal(), [_savedMemory]);
        expect(
          store.client.auth.currentUser?.id,
          roundTrip ? _ownerA : _ownerB,
        );
      },
    );

    test(
      'memory SDK refresh rejects an owner ${roundTrip ? 'A-B-A round trip' : 'A-B switch'} before data send',
      () async {
        store.expireAfterConsent = true;
        store.refreshBlock = Completer<void>();
        final pending = store.sync();
        await store.refreshEntered.future.timeout(const Duration(seconds: 10));
        expect(store.writes, isEmpty);
        if (roundTrip) {
          await store.roundTrip();
        } else {
          await store.client.auth.recoverSession(
            jsonEncode(_memorySession(_ownerB)),
          );
          await store.deliveredB.future.timeout(const Duration(seconds: 10));
        }
        store.refreshBlock!.complete();
        await pending;
        expect(store.writes, isEmpty);
        expect(await store.repository.readLocal(), [_savedMemory]);
        expect(store.refreshCount, 1);
        expect(
          store.client.auth.currentUser?.id,
          roundTrip ? _ownerA : _ownerB,
        );
      },
    );
  }

  test(
    'same-owner token refresh sends the captured committed memory once',
    () async {
      store.expireAfterConsent = true;
      store.refreshBlock = Completer<void>();
      final pending = store.sync();
      await store.refreshEntered.future.timeout(const Duration(seconds: 10));
      await store.client.auth.recoverSession(
        jsonEncode(_memorySession(_ownerA)),
      );
      store.refreshBlock!.complete();
      await pending;
      expect(store.refreshCount, 1);
      expect(store.writes, hasLength(1));
      final request = store.writes.single;
      expect(request.method, 'POST');
      expect(_memoryRequestOwner(request), _ownerA);
      expect(jsonDecode(request.body), containsPair('owner_id', _ownerA));
      expect(
        jsonDecode(request.body),
        containsPair('memory_text', _savedMemory['text']),
      );
      expect(await store.repository.readLocal(), [_savedMemory]);
    },
  );

  test(
    'local memory changed during consent cannot send the older value',
    () async {
      store.consentBlock = Completer<void>();
      final pending = store.sync();
      await store.consentEntered.future.timeout(const Duration(seconds: 10));
      final updated = {
        ..._savedMemory,
        'text': 'Prefer morning workouts',
        'updatedAt': '2026-10-06T10:05:00.000Z',
      };
      await store.setLocal([updated]);
      store.consentBlock!.complete();
      await pending;
      expect(store.writes, isEmpty);
      expect(await store.repository.readLocal(), [updated]);
    },
  );

  for (final delete in [false, true]) {
    test(
      'local memory ${delete ? 'Undo' : 'edit'} during SDK refresh fences the stale payload',
      () async {
        store.expireAfterConsent = true;
        store.refreshBlock = Completer<void>();
        final pending = store.sync();
        await store.refreshEntered.future.timeout(const Duration(seconds: 10));
        final current = delete
            ? <Map<String, Object?>>[]
            : [
                {
                  ..._savedMemory,
                  'text': 'Prefer morning workouts',
                  'updatedAt': '2026-10-06T10:05:00.000Z',
                },
              ];
        await store.setLocal(current);
        // No sleep or query-watch flush is inserted between the actual local
        // commit and refresh completion. The transport itself must revalidate.
        store.refreshBlock!.complete();
        await pending;
        expect(store.writes, isEmpty);
        expect(await store.repository.readLocal(), current);
        expect(store.client.auth.currentUser?.id, _ownerA);
      },
    );
  }

  test(
    'memory operation cancellation during SDK refresh sends no payload',
    () async {
      store.expireAfterConsent = true;
      store.refreshBlock = Completer<void>();
      final pending = store.sync();
      await store.refreshEntered.future.timeout(const Duration(seconds: 10));
      store.currentOperation = false;
      store.refreshBlock!.complete();
      await pending;
      expect(store.writes, isEmpty);
      expect(await store.repository.readLocal(), [_savedMemory]);
    },
  );

  test('optional cloud failure preserves the committed local memory', () async {
    store.failDataWrite = true;
    await store.sync();
    expect(store.writes, hasLength(1));
    expect(await store.repository.readLocal(), [_savedMemory]);
  });

  test(
    'an older owner cloud read cannot merge into local memory after A-B-A',
    () async {
      store.readBlock = Completer<void>();
      store.remoteRows = [
        {
          'id': _memoryId,
          'memory_text': 'Delayed old session content',
          'kind': 'preference',
          'status': 'confirmed',
          'source': 'explicit_user_confirmation',
          'confidence': 1.0,
          'learned_at': _savedMemory['savedAt'],
          'updated_at': '2026-10-06T11:00:00.000Z',
        },
      ];
      final pending = store.repository.mergeFromCloud();
      await store.readEntered.future.timeout(const Duration(seconds: 10));
      await store.roundTrip();
      store.readBlock!.complete();
      await pending;
      expect(store.reads, hasLength(1));
      expect(store.writes, isEmpty);
      expect(await store.repository.readLocal(), [_savedMemory]);
    },
  );

  for (final cancelParent in [false, true]) {
    test(
      'nested data-send validation ${cancelParent ? 'honors a cancelled parent' : 'awaits parent and child readback'}',
      () async {
        final parentEntered = Completer<void>();
        final releaseParent = Completer<void>();
        addTearDown(() {
          if (!releaseParent.isCompleted) releaseParent.complete();
        });
        final validations = <String>[];
        final pending = expectLater(
          CommunityOwnerOperation.run(
            client: store.client,
            ownerId: _ownerA,
            beforeDataSend: () async {
              validations.add('parent');
              parentEntered.complete();
              await releaseParent.future;
            },
            action: (_) => CommunityOwnerOperation.run(
              client: store.client,
              ownerId: _ownerA,
              beforeDataSend: () async => validations.add('child'),
              action: (_) async {
                await store.client.from('bil_coach_memories').upsert({
                  'id': _memoryId,
                  'owner_id': _ownerA,
                  'memory_text': _savedMemory['text'],
                });
              },
            ),
          ),
          cancelParent
              ? throwsA(isA<CommunityOwnerOperationCancelled>())
              : completes,
        );
        await parentEntered.future.timeout(const Duration(seconds: 10));
        expect(validations, ['parent']);
        expect(store.writes, isEmpty);
        if (cancelParent) await store.roundTrip();
        releaseParent.complete();
        await pending;
        expect(validations, cancelParent ? ['parent'] : ['parent', 'child']);
        expect(store.writes, hasLength(cancelParent ? 0 : 1));
        expect(store.client.auth.currentUser?.id, _ownerA);
      },
    );
  }
}
