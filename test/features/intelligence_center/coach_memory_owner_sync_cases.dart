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

  test(
    'expired and inferred memories remain durable without being presented as confirmed facts',
    () async {
      final expired = {
        ..._savedMemory,
        'id': 'expired',
        'text': 'Old goal',
        'expiresAt': '2000-01-01T00:00:00Z',
      };
      final inferred = {
        ..._savedMemory,
        'id': 'inferred',
        'text': 'Unconfirmed pattern',
        'status': 'inferred',
        'source': 'coach_inference',
      };
      await store.setLocal([_savedMemory, expired, inferred]);
      expect(await store.repository.readLocal(), [_savedMemory]);
      final raw = await store.preferences.get(CoachMemoryRepository.storageKey);
      expect(raw, contains('Old goal'));
      expect(raw, contains('Unconfirmed pattern'));
    },
  );

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
    'offline privacy deletion cannot be resurrected by a later cloud merge',
    () async {
      store.failDataWrite = true;
      await store.repository.deleteSelected([
        CoachMemorySelection(
          id: _memoryId,
          expectedUpdatedAt: _savedMemory['updatedAt']! as String,
        ),
      ]);
      expect(await store.repository.readLocal(), isEmpty);
      store.remoteRows = [
        {
          'id': _memoryId,
          'memory_text': _savedMemory['text'],
          'kind': 'preference',
          'status': 'confirmed',
          'source': 'explicit_user_confirmation',
          'confidence': 1.0,
          'learned_at': _savedMemory['savedAt'],
          'updated_at': '2026-10-23T11:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      expect(await store.repository.readLocal(), isEmpty);
      final raw = await store.preferences.get(CoachMemoryRepository.storageKey);
      expect(raw, isNot(contains(_savedMemory['text'])));
      expect((jsonDecode(raw!) as List).single['status'], 'deleted');
    },
  );

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

  Future<Map> checkpoint() async =>
      jsonDecode(
            (await store.preferences.get('coach.memory.sync.$_memoryId.v1'))!,
          )
          as Map;
  test(
    'actual memory write is read back once and a repeat does not create another write',
    () async {
      store.persistWrites = true;
      await store.sync();
      expect((await checkpoint())['state'], 'verified');
      expect(store.reads, hasLength(2));
      expect(store.writes, hasLength(1));
      await store.sync();
      expect(store.writes, hasLength(1));
      expect((await checkpoint())['state'], 'verified');
    },
  );
  test(
    'conditional memory update refuses a concurrent second-device revision',
    () async {
      store.persistWrites = true;
      await store.sync();
      final changed = {
        ..._savedMemory,
        'text': 'Prefer morning workouts',
        'updatedAt': '2026-10-23T11:00:00Z',
      };
      await store.setLocal([changed]);
      store.raceBeforePatch = true;
      await store.sync(expected: changed);
      expect((await checkpoint())['state'], 'conflict');
      expect(
        store.remoteRows.single['memory_text'],
        'Concurrent other-device fact',
      );
      expect(await store.repository.readLocal(), [changed]);
    },
  );
  test(
    'an unrelated legacy cloud value cannot overwrite or be overwritten without a baseline',
    () async {
      store.persistWrites = true;
      store.remoteRows = [
        {
          'id': _memoryId,
          'owner_id': _ownerA,
          'memory_text': 'Unseen cloud update',
          'kind': 'preference',
          'status': 'confirmed',
          'source': 'explicit_user_confirmation',
          'confidence': 1.0,
          'learned_at': _savedMemory['savedAt'],
          'updated_at': '2026-10-23T11:00:00Z',
        },
      ];
      await store.sync();
      expect(store.writes, isEmpty);
      expect((await checkpoint())['state'], 'conflict');
      expect(await store.repository.readLocal(), [_savedMemory]);
    },
  );
  test(
    'privacy deletion redacts the actual cloud body only after matching the baseline',
    () async {
      store.persistWrites = true;
      await store.sync();
      await store.repository.deleteSelected([
        CoachMemorySelection(
          id: _memoryId,
          expectedUpdatedAt: _savedMemory['updatedAt']! as String,
        ),
      ]);
      expect(store.remoteRows.single['memory_text'], '[deleted]');
      expect(store.remoteRows.single['deleted_at'], isNotNull);
      expect((await checkpoint())['state'], 'verified');
      expect((await checkpoint())['deleted'], isTrue);
      expect(await store.repository.readLocal(), isEmpty);
    },
  );
  test(
    'wrong-owner readback never becomes a verified synchronization receipt',
    () async {
      store.persistWrites = true;
      store.tamperReadbackOwner = true;
      await store.sync();
      expect((await checkpoint())['state'], 'pending');
      expect(await store.repository.readLocal(), [_savedMemory]);
      expect(store.remoteRows.single['owner_id'], _ownerA);
    },
  );

  test(
    'known baseline pulls a verified remote edit while divergent local edits remain intact',
    () async {
      store.persistWrites = true;
      await store.sync();
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Updated on another device',
          'updated_at': '2026-10-23T13:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      expect(
        (await store.repository.readLocal()).single['text'],
        'Updated on another device',
      );
      final changed = {
        ...(await store.repository.readLocal()).single,
        'text': 'Pending local edit',
        'updatedAt': '2026-10-23T14:00:00Z',
      };
      await store.setLocal([changed]);
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Concurrent remote edit',
          'updated_at': '2026-10-23T15:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      expect(await store.repository.readLocal(), [changed]);
      expect((await checkpoint())['state'], 'conflict');
    },
  );
  test(
    'remote deletion propagates only over an unchanged confirmed local baseline',
    () async {
      store.persistWrites = true;
      await store.sync();
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': '[deleted]',
          'deleted_at': '2026-10-23T13:00:00Z',
          'updated_at': '2026-10-23T13:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      expect(await store.repository.readLocal(), isEmpty);
      expect((await checkpoint())['deleted'], isTrue);
      expect(
        await store.preferences.get(CoachMemoryRepository.storageKey),
        isNot(contains(_savedMemory['text'])),
      );
    },
  );
  test(
    'reconnection drains one pending fact with confirmed readback, without a repeated write loop',
    () async {
      store.persistWrites = true;
      store.failDataWrite = true;
      await store.sync();
      expect((await checkpoint())['state'], 'pending');
      store.failDataWrite = false;
      await store.repository.mergeFromCloud();
      expect((await checkpoint())['state'], 'verified');
      expect(store.writes, hasLength(2));
      expect(store.remoteRows, hasLength(1));
    },
  );
  test(
    'native undo retains a deletion intent even when the original cloud outcome is ambiguous',
    () async {
      store.persistWrites = true;
      await store.sync();
      await store.setLocal([]);
      store.failDataWrite = true;
      await store.sync(expected: null);
      expect(await store.repository.readLocal(), isEmpty);
      store.failDataWrite = false;
      await store.repository.mergeFromCloud();
      expect(await store.repository.readLocal(), isEmpty);
      expect(store.remoteRows.single['memory_text'], '[deleted]');
    },
  );

  test(
    'conflict choice reviews both real versions and applies only explicit cloud choice',
    () async {
      store.persistWrites = true;
      await store.sync();
      final local = {..._savedMemory, 'text': 'Local evening preference'};
      await store.setLocal([local]);
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Cloud morning preference',
          'updated_at': '2026-10-23T15:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      final review = await store.repository.reviewSyncConflict(_memoryId);
      addTearDown(review.dispose);
      expect(review.local!['text'], 'Local evening preference');
      expect(review.remote!['text'], 'Cloud morning preference');
      expect(await store.repository.readLocal(), [local]);
      expect(
        await store.repository.resolveSyncConflict(review, useCloud: true),
        isTrue,
      );
      expect(
        (await store.repository.readLocal()).single['text'],
        'Cloud morning preference',
      );
      expect(store.writes, hasLength(1));
    },
  );
  test(
    'confirmed local conflict choice uses remote CAS and independent readback',
    () async {
      store.persistWrites = true;
      await store.sync();
      final local = {
        ..._savedMemory,
        'text': 'Local evening preference',
        'updatedAt': '2026-10-23T14:00:00Z',
      };
      await store.setLocal([local]);
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Cloud morning preference',
          'updated_at': '2026-10-23T15:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      final review = await store.repository.reviewSyncConflict(_memoryId);
      addTearDown(review.dispose);
      expect(
        await store.repository.resolveSyncConflict(review, useCloud: false),
        isTrue,
      );
      expect(
        store.remoteRows.single['memory_text'],
        'Local evening preference',
      );
      expect(store.writes, hasLength(2));
      expect((await checkpoint())['state'], 'verified');
    },
  );
  test(
    'newer remote revision and owner A-B-A invalidate a reviewed conflict',
    () async {
      store.persistWrites = true;
      await store.sync();
      await store.setLocal([
        {..._savedMemory, 'text': 'Local evening preference'},
      ]);
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Cloud morning preference',
          'updated_at': '2026-10-23T15:00:00Z',
        },
      ];
      await store.repository.mergeFromCloud();
      final review = await store.repository.reviewSyncConflict(_memoryId);
      addTearDown(review.dispose);
      store.remoteRows = [
        {
          ...store.remoteRows.single,
          'memory_text': 'Newer cloud preference',
          'updated_at': '2026-10-23T16:00:00Z',
        },
      ];
      await expectLater(
        store.repository.resolveSyncConflict(review, useCloud: false),
        throwsA(isA<CoachMemoryVersionConflict>()),
      );
      final second = await store.repository.reviewSyncConflict(_memoryId);
      addTearDown(second.dispose);
      await store.roundTrip();
      await expectLater(
        store.repository.resolveSyncConflict(second, useCloud: true),
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      expect(store.writes, hasLength(1));
    },
  );

  testWidgets(
    'real memory comparison UI cancels safely and confirms the selected cloud version',
    (tester) async {
      await tester.runAsync(() async {
        store.persistWrites = true;
        await store.sync();
        await store.setLocal([
          {..._savedMemory, 'text': 'Local evening preference'},
        ]);
        store.remoteRows = [
          {
            ...store.remoteRows.single,
            'memory_text': 'Cloud morning preference',
            'updated_at': '2026-10-23T15:00:00Z',
          },
        ];
        await store.repository.mergeFromCloud();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(store.preferences),
            coachMemorySyncRepositoryProvider.overrideWithValue(
              store.repository,
            ),
          ],
          child: MaterialApp(
            theme: BilFlagshipTheme.light(isArabic: false),
            home: Scaffold(
              body: ListView(
                children: [CoachMemorySyncReviewPanel(onChanged: () {})],
              ),
            ),
          ),
        ),
      );
      Future<void> waitFor(String value) async {
        await tester.runAsync(() async {
          final until = DateTime.now().add(const Duration(seconds: 10));
          while (find.text(value).evaluate().isEmpty &&
              DateTime.now().isBefore(until)) {
            await tester.pump(const Duration(milliseconds: 20));
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(value), findsWidgets);
      }

      await waitFor('Compare memory versions');
      await tester.tap(find.text('Compare memory versions'));
      await waitFor('Cloud morning preference');
      expect(find.text('Local evening preference'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.runAsync(() async {
        final until = DateTime.now().add(const Duration(seconds: 10));
        while (find.byType(LinearProgressIndicator).evaluate().isNotEmpty &&
            DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        (await tester.runAsync(store.repository.readLocal))!.single['text'],
        'Local evening preference',
      );
      expect(store.writes, hasLength(1));
      await waitFor('Compare memory versions');
      await tester.tap(find.text('Compare memory versions'));
      await waitFor('Cloud morning preference');
      await tester.tap(find.text('Use cloud version'));
      await waitFor('Memory choice saved and verified.');
      expect(
        (await tester.runAsync(store.repository.readLocal))!.single['text'],
        'Cloud morning preference',
      );
      expect(store.writes, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
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
