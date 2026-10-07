part of 'coach_native_command_behavior_test.dart';

void _nativeRecoveryLifecycleCases() {
  testWidgets('native recovery keeps one Undo for duplicated receipt evidence', (
    tester,
  ) async {
    await _withCoach(
      tester,
      [
        _tool('log_water', {'amountMl': 250}),
      ],
      (fixture) async {
        await _saveRecoveryWater(tester, fixture);
        await _unmountNativeCoach(tester);
        final preferences = PreferencesRepository(fixture.database);
        final messages =
            jsonDecode((await preferences.get('intelligenceConversationV1'))!)
                as List;
        final original = messages.cast<Map>().lastWhere(
          (m) => m['kind'] == 'action',
        );
        messages.add({...original, 'id': '${original['id']}-duplicate'});
        // A separate damaged candidate must not mask the original valid journal.
        final damaged = jsonDecode(jsonEncode(original)) as Map;
        damaged['id'] = '${original['id']}-unavailable';
        final evidence = damaged['evidence'] as List;
        final receipt = jsonDecode(evidence.last as String) as Map;
        receipt['operation_id'] = 'missing-operation';
        evidence[evidence.length - 1] = jsonEncode(receipt);
        messages.add(damaged);
        await preferences.set(
          'intelligenceConversationV1',
          jsonEncode(messages),
        );
        final before = await _nativeRecoverySnapshot(fixture);
        await tester.pumpWidget(_nativeCoachApp(fixture));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
        expect(await _nativeRecoverySnapshot(fixture), before);
        await _undoNative(tester);
        await _waitNativeReceipts(tester, fixture, 4);
        final water = await fixture.database
            .select(fixture.database.waterEntries)
            .getSingle();
        expect(water.revision, 2);
        expect(water.deletedAt, isNotNull);
        expect(fixture.gateway.calls, 1);
        expect(tester.takeException(), isNull);
      },
      ownerId: 'owner-a',
    );
  });

  testWidgets(
    'native recovery rejects copied receipt with equal operation digest and integer ID',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (a) async {
          await _saveRecoveryWater(tester, a);
          final original = (await a.receipts()).single;
          await _unmountNativeCoach(tester);
          final b = _NativeFixture([], ownerId: 'owner-b');
          addTearDown(b.database.close);
          addTearDown(b.owners.close);
          final repository = CoachNativeCommandRepository(b.database);
          final scope = CoachNativeOwnerScope(
            ownerId: 'owner-b',
            isCurrent: () => true,
          );
          final command = await repository.prepare(
            toolId: 'log_water',
            operationId: original['operation_id']! as String,
            arguments: {'amountMl': 250},
            scope: scope,
            now: DateTime.parse(
              (original['after']! as Map)['occurred_at'] as String,
            ),
          );
          final committed = await repository.commit(
            command: command,
            scope: scope,
          );
          expect(
            committed.argumentsDigest,
            (original['after'] as Map)['arguments_digest'],
          );
          expect(committed.after.water!.id.toString(), original['entity_id']);
          expect(
            committed.after.water!.uuid,
            isNot((original['after'] as Map)['uuid']),
          );
          final raw = (await PreferencesRepository(
            a.database,
          ).get('intelligenceConversationV1'))!;
          final messages = jsonDecode(raw) as List;
          var copiedReceipts = 0;
          for (final message in messages.whereType<Map>()) {
            final evidence = message['evidence'];
            if (evidence is! List || message['kind'] != 'action') continue;
            for (var i = 0; i < evidence.length; i++) {
              final rawEvidence = evidence[i];
              if (rawEvidence is! String || !rawEvidence.startsWith('{')) {
                continue;
              }
              final receipt = jsonDecode(rawEvidence) as Map;
              if (receipt['committed'] != true) continue;
              receipt['completed_at'] = committed.committedAt
                  .toUtc()
                  .toIso8601String();
              evidence[i] = jsonEncode(receipt);
              copiedReceipts++;
            }
          }
          expect(copiedReceipts, 1);
          await PreferencesRepository(
            b.database,
          ).set('intelligenceConversationV1', jsonEncode(messages));
          final beforeA = await _nativeRecoverySnapshot(a);
          final beforeB = await _nativeRecoverySnapshot(b);
          await tester.pumpWidget(_nativeCoachApp(b));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(await _nativeRecoverySnapshot(a), beforeA);
          expect(await _nativeRecoverySnapshot(b), beforeB);
          expect(b.gateway.calls, 0);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    },
  );

  for (final boundary in ['restore', 'Undo']) {
    testWidgets(
      'native recovery fences A B A while $boundary reads the journal',
      (tester) async {
        await _withCoach(
          tester,
          [
            _tool('log_water', {'amountMl': 250}),
          ],
          (fixture) async {
            await _saveRecoveryWater(tester, fixture);
            await _unmountNativeCoach(tester);
            final before = await _nativeRecoverySnapshot(fixture);
            final preferences = _PausedNativeRecoveryPreferences(
              fixture.database,
            );
            fixture.recoveryPreferences = preferences;
            if (boundary == 'restore') preferences.arm();
            await tester.pumpWidget(_nativeCoachApp(fixture));
            await tester.pumpAndSettle();
            if (boundary == 'Undo') {
              expect(
                find.widgetWithText(OutlinedButton, 'Undo'),
                findsOneWidget,
              );
              preferences.arm();
              final undo = find.widgetWithText(OutlinedButton, 'Undo');
              await Scrollable.ensureVisible(tester.element(undo));
              await tester.pump(const Duration(milliseconds: 350));
              await tester.tap(undo);
              for (
                var attempt = 0;
                attempt < 20 && !preferences.started!.isCompleted;
                attempt++
              ) {
                await tester.pump(const Duration(milliseconds: 100));
              }
            }
            expect(preferences.started!.isCompleted, isTrue);
            fixture.owner = 'owner-b';
            fixture.owners.add('owner-b');
            fixture.owner = 'owner-a';
            fixture.owners.add('owner-a');
            preferences.release();
            await tester.pumpAndSettle();
            if (boundary == 'restore') {
              expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
            }
            expect(await _nativeRecoverySnapshot(fixture), before);
            expect(
              (await fixture.receipts()).where((r) => r['undone_at'] != null),
              isEmpty,
            );
            expect(fixture.gateway.calls, 1);
            expect(tester.takeException(), isNull);
          },
          ownerId: 'owner-a',
        );
      },
    );
  }

  testWidgets(
    'native recovery closes its visit during a delayed read without disposed ref use',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (fixture) async {
          await _saveRecoveryWater(tester, fixture);
          await _unmountNativeCoach(tester);
          final before = await _nativeRecoverySnapshot(fixture);
          final preferences = _PausedNativeRecoveryPreferences(fixture.database)
            ..arm();
          fixture.recoveryPreferences = preferences;
          await tester.pumpWidget(_nativeCoachApp(fixture));
          await tester.pumpAndSettle();
          expect(preferences.started!.isCompleted, isTrue);
          await _unmountNativeCoach(tester);
          preferences.release();
          await tester.pumpAndSettle();
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    },
  );

  testWidgets(
    'native recovered callback cannot survive repository replacement',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (fixture) async {
          await _saveRecoveryWater(tester, fixture);
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(IntelligenceCenterPage)),
          );
          final original = container.read(waterRepositoryProvider);
          container.invalidate(waterRepositoryProvider);
          expect(
            identical(container.read(waterRepositoryProvider), original),
            isFalse,
          );
          await tester.pump();
          final before = await _nativeRecoverySnapshot(fixture);
          await _undoNative(tester);
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(
            (await fixture.receipts()).where((r) => r['undone_at'] != null),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    },
  );

  testWidgets(
    'native Undo belongs to the selected conversation and is revalidated on return',
    (tester) async {
      await _withCoach(
        tester,
        [
          _tool('log_water', {'amountMl': 250}),
        ],
        (fixture) async {
          await _saveRecoveryWater(tester, fixture);
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          final preferences = PreferencesRepository(fixture.database);
          final conversationId = await preferences.get(
            'intelligenceConversationActiveIdV1',
          );
          expect(conversationId, isNotNull);
          final before = await _nativeRecoverySnapshot(fixture);
          await tester.tap(
            find.byKey(const Key('ai-coach-conversation-history-button')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('New conversation'));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(await _nativeRecoverySnapshot(fixture), before);
          await tester.tap(
            find.byKey(const Key('ai-coach-conversation-history-button')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(Key('ai-coach-conversation-$conversationId')),
          );
          await tester.pumpAndSettle();
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          expect(await _nativeRecoverySnapshot(fixture), before);
          expect(fixture.gateway.calls, 1);
          expect(tester.takeException(), isNull);
        },
        ownerId: 'owner-a',
      );
    },
  );
}

Future<void> _saveRecoveryWater(
  WidgetTester tester,
  _NativeFixture fixture,
) async {
  await _openNativeAction(tester, 'addWater', 'log_water');
  await _confirmNative(tester);
  await _waitNativeReceipts(tester, fixture, 1);
}

class _PausedNativeRecoveryPreferences extends PreferencesRepository {
  _PausedNativeRecoveryPreferences(super.database);
  Completer<void>? started;
  Completer<void>? pending;
  void arm() {
    started = Completer<void>();
    pending = Completer<void>();
  }

  void release() {
    pending!.complete();
  }

  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    final waiting = pending;
    if (key.startsWith('coachNativeOperationV1.') &&
        waiting != null &&
        !waiting.isCompleted) {
      if (!started!.isCompleted) started!.complete();
      await waiting.future;
    }
    return value;
  }
}
