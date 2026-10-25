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
        await openCoachConversationFromOverview(tester);
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
          await openCoachConversationFromOverview(tester);
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
            await openCoachConversationFromOverview(tester);
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
          await openCoachConversationFromOverview(tester);
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
          final trace = _TracingNativeHistoryPreferences(fixture.database);
          fixture.recoveryPreferences = trace;
          await _remountNativeCoach(tester, fixture);
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
          final preferences = trace;
          final conversationId = await preferences.get(
            'intelligenceConversationActiveIdV1',
          );
          expect(conversationId, isNotNull);
          final before = await _nativeRecoverySnapshot(fixture);
          final newConversation = find.widgetWithText(
            ListTile,
            'New conversation',
          );
          await _openNativeHistoryChoice(
            tester,
            newConversation,
            fixture: fixture,
            originalConversationId: conversationId,
          );
          await tester.tap(newConversation);
          // The picker archives via actual SQLite before replacing the chat.
          // pumpAndSettle alone cannot await an unframed repository Future.
          for (var attempt = 0; attempt < 80; attempt++) {
            await _pumpNativeHistoryIo(tester);
            if (await preferences.get('intelligenceConversationActiveIdV1') ==
                null) {
              break;
            }
          }
          expect(
            await preferences.get('intelligenceConversationActiveIdV1'),
            isNull,
          );
          await tester.pumpAndSettle();
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(await _nativeRecoverySnapshot(fixture), before);
          final previousConversation = find.byKey(
            Key('ai-coach-conversation-$conversationId'),
          );
          await _openNativeHistoryChoice(
            tester,
            previousConversation,
            fixture: fixture,
            originalConversationId: conversationId,
          );
          await tester.tap(previousConversation);
          for (var attempt = 0; attempt < 80; attempt++) {
            await _pumpNativeHistoryIo(tester);
            if (await preferences.get('intelligenceConversationActiveIdV1') ==
                    conversationId &&
                find
                    .widgetWithText(OutlinedButton, 'Undo')
                    .evaluate()
                    .isNotEmpty) {
              break;
            }
          }
          expect(
            await preferences.get('intelligenceConversationActiveIdV1'),
            conversationId,
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

Future<void> _openNativeHistoryChoice(
  WidgetTester tester,
  Finder choice, {
  required _NativeFixture fixture,
  required String? originalConversationId,
}) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await _pumpNativeHistoryIo(tester);
  final history = find.byWidgetPredicate(
    (widget) =>
        widget is IconButton && widget.tooltip == 'Conversation history',
  );
  for (var attempt = 0; attempt < 80; attempt++) {
    if (history.evaluate().length == 1 &&
        tester.widget<IconButton>(history).onPressed != null) {
      break;
    }
    await _pumpNativeHistoryIo(tester);
  }
  expect(history, findsOneWidget);
  expect(tester.widget<IconButton>(history).onPressed, isNotNull);
  expect(history.hitTestable(), findsOneWidget);
  _recordNativeHistoryDiagnostic(
    tester,
    fixture,
    history,
    choice,
    originalConversationId,
    stage: 'before_real_header_tap',
  );
  await tester.tap(history);
  for (var attempt = 0; attempt < 80 && choice.evaluate().isEmpty; attempt++) {
    await _pumpNativeHistoryIo(tester);
    if (attempt == 0 || attempt == 9 || attempt == 39 || attempt == 79) {
      _recordNativeHistoryDiagnostic(
        tester,
        fixture,
        history,
        choice,
        originalConversationId,
        stage: 'await_actual_sheet',
        attempt: attempt + 1,
      );
    }
  }
  _recordNativeHistoryDiagnostic(
    tester,
    fixture,
    history,
    choice,
    originalConversationId,
    stage: 'actual_sheet_wait_finished',
  );
  expect(choice, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(choice), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(choice.hitTestable(), findsOneWidget);
}

Future<void> _pumpNativeHistoryIo(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  // Pump advances the widget-test clock. Native SQLite's real asynchronous
  // continuation also needs an actual event-loop turn; keep this yield bounded.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
}

void _recordNativeHistoryDiagnostic(
  WidgetTester tester,
  _NativeFixture fixture,
  Finder history,
  Finder choice,
  String? originalConversationId, {
  required String stage,
  int? attempt,
}) {
  final preferences = fixture.recoveryPreferences;
  final trace = preferences is _TracingNativeHistoryPreferences
      ? preferences
      : null;
  final snapshot = <String, Object?>{
    'stage': stage,
    'attempt': attempt,
    'header_count': history.evaluate().length,
    'header_enabled':
        history.evaluate().length == 1 &&
        tester.widget<IconButton>(history).onPressed != null,
    'sheet_count': find.byType(BottomSheet).evaluate().length,
    'modal_bottom_sheet_runtime_count': find
        .byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString().startsWith('_ModalBottomSheet'),
        )
        .evaluate()
        .length,
    'list_tile_count': find.byType(ListTile).evaluate().length,
    'try_again_count': find.text('Try again').evaluate().length,
    'conversations_title_count': find.text('Conversations').evaluate().length,
    'no_previous_conversations_count': find
        .text('No previous conversations yet.')
        .evaluate()
        .length,
    'choice_count': choice.evaluate().length,
    'keyboard_visible': tester.testTextInput.isVisible,
    'primary_focus_present': FocusManager.instance.primaryFocus != null,
    'gateway_calls': fixture.gateway.calls,
    'native_preferences_pending': trace?.pending,
    // This is the last completed actual repository read, not an
    // invented current ID or a private page-state getter.
    'active_id_read_completed': trace?.activeIdReadCompleted,
    'last_read_active_id_present': trace?.lastReadActiveId != null,
    'last_read_active_id_matches_original':
        trace != null &&
        trace.activeIdReadCompleted &&
        trace.lastReadActiveId == originalConversationId,
    'repository_events': trace?.events,
  };
  debugPrint('NATIVE_HISTORY_DIAGNOSTIC ${jsonEncode(snapshot)}');
}

class _TracingNativeHistoryPreferences extends PreferencesRepository {
  _TracingNativeHistoryPreferences(super.database);
  final events = <Map<String, Object?>>[];
  int pending = 0;
  bool activeIdReadCompleted = false;
  String? lastReadActiveId;

  String _keyClass(String key) => switch (key) {
    'intelligenceConversationHistoryV1' => 'archive',
    'intelligenceConversationV1' => 'transcript',
    'intelligenceConversationContextV1' => 'context',
    'intelligenceConversationActiveIdV1' => 'active_id',
    _ when key.startsWith('coachNativeOperationV1.') => 'native_journal',
    _ => 'other',
  };

  Future<T> _record<T>(String operation, Future<T> Function() run) async {
    pending++;
    events.add({'operation': operation, 'stage': 'started'});
    try {
      final result = await run();
      events.add({'operation': operation, 'stage': 'completed'});
      return result;
    } on Object catch (error) {
      events.add({
        'operation': operation,
        'stage': 'failed',
        'error_type': error.runtimeType.toString(),
      });
      rethrow;
    } finally {
      pending--;
    }
  }

  @override
  Future<String?> get(String key) => _record('get:${_keyClass(key)}', () async {
    final value = await super.get(key);
    if (key == 'intelligenceConversationActiveIdV1') {
      activeIdReadCompleted = true;
      lastReadActiveId = value;
    }
    return value;
  });

  @override
  Future<void> set(String key, String value) =>
      _record('set:${_keyClass(key)}', () => super.set(key, value));

  @override
  Future<void> setMany(Map<String, String> values) =>
      _record('set_many', () => super.setMany(values));

  @override
  Future<String> update(
    String key,
    String Function(String? current) derive, {
    bool Function()? isCurrent,
  }) => _record(
    'update:${_keyClass(key)}',
    () => super.update(key, derive, isCurrent: isCurrent),
  );

  @override
  Future<void> mutate({
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) => _record('mutate', () => super.mutate(set: set, remove: remove));
}
