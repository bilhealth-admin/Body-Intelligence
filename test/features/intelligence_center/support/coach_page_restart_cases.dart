part of '../coach_page_lifecycle_regression_test.dart';

class _RestartPreferences extends PreferencesRepository {
  _RestartPreferences(super.database);
  String? fault;
  Completer<void>? archiveWait;
  int archiveAttempts = 0;
  int switchAttempts = 0;
  bool switchCommitted = false;

  @override
  Future<String?> get(String key) {
    if (fault == 'post-commit-read' &&
        switchCommitted &&
        key == 'intelligenceConversationHistoryV1') {
      fault = null;
      return Future.error(StateError('controlled verification read'));
    }
    return super.get(key);
  }

  @override
  Future<String> update(
    String key,
    String Function(String? current) derive, {
    bool Function()? isCurrent,
  }) async {
    if (key == 'intelligenceConversationHistoryV1') {
      archiveAttempts++;
      await archiveWait?.future;
      if (fault == 'archive-write') {
        throw StateError('controlled archive write');
      }
      if (fault == 'archive-readback') return derive(await get(key));
    }
    return super.update(key, derive, isCurrent: isCurrent);
  }

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) async {
    switchAttempts++;
    if (fault == 'switch-write') {
      return Future.error(StateError('controlled switch write'));
    }
    if (fault == 'concurrent-change') return Future.value(false);
    final result = await super.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
      isCurrent: isCurrent,
    );
    switchCommitted = result;
    return result;
  }
}

Future<void> _pullForNewConversation(WidgetTester tester) async {
  final viewport = tester.widget<ChatHistoryViewport>(
    find.byType(ChatHistoryViewport),
  );
  viewport.controller.jumpTo(viewport.controller.position.minScrollExtent);
  await tester.pump();
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(ChatHistoryViewport)),
  );
  await gesture.moveBy(const Offset(0, -150));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _drainRestart(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find
        .byKey(const Key('coach-new-conversation-pull-status'))
        .evaluate()
        .isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void registerCoachRestartCases() {
  testWidgets('retained starter cannot replace a draft during a pending reply', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _HeldGateway();
    try {
      await _mount(
        tester,
        database: database,
        gateway: gateway,
        waitForBrief: true,
      );
      await _send(tester, gateway);
      const draft = 'A second question I am still writing.';
      final field = find.byKey(const Key('ai-coach-question-field'));
      await tester.enterText(field, draft);
      await tester.pump();
      final starter = find.descendant(
        of: find.byKey(const ValueKey('ai-coach-starter-prompts')),
        matching: find.text('Review my day'),
      );
      await tester.ensureVisible(starter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(starter.hitTestable(), findsOneWidget);
      await tester.tap(starter);
      await tester.pump();
      expect(
        gateway.calls,
        1,
        reason: 'A pending first reply stays single-flight.',
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        draft,
        reason:
            'Retaining the opening surface must not let a busy starter erase a new draft.',
      );
      final history = tester.widget<CoachAnchoredHistory>(
        find.byType(CoachAnchoredHistory),
      );
      expect(
        history.rowIds.where((id) => id == 'coach-session-brief'),
        hasLength(1),
      );
      expect(
        history.rowIds.where((id) => id == 'coach-reply-thinking'),
        hasLength(1),
      );
      gateway.finish(text: 'Only one first reply is delivered.');
      await tester.pumpAndSettle();
      expect(gateway.calls, 1);
      expect(tester.widget<TextField>(field).controller!.text, draft);
      expect(tester.takeException(), isNull);
    } finally {
      for (final reply in gateway.replies) {
        if (!reply.isCompleted) {
          reply.complete(
            const LocalModelResult.answer(
              LocalModelAnswer(text: 'Synthetic cleanup', action: null),
            ),
          );
        }
      }
      await _unmount(tester);
      await tester.runAsync(database.close);
    }
  });

  testWidgets('opening Coach surface remains a scrollable row after sending', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _HeldGateway();
    try {
      await _mount(
        tester,
        database: database,
        gateway: gateway,
        waitForBrief: true,
      );
      CoachAnchoredHistory history() => tester.widget<CoachAnchoredHistory>(
        find.byType(CoachAnchoredHistory),
      );
      expect(history().rowIds, contains('coach-session-brief'));
      expect(find.text('Check nutrition'), findsOneWidget);
      await _send(tester, gateway);
      expect(history().rowIds, contains('coach-session-brief'));
      gateway.finish(text: 'This reply stays below the original introduction.');
      await tester.pumpAndSettle();
      expect(history().rowIds.first, 'coach-session-brief');
      expect(history().rowIds.length, greaterThanOrEqualTo(3));
      history().controller.jumpTo(
        history().controller.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      expect(find.text('Check nutrition'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(history().rowIds.first, 'coach-session-brief');
      expect(tester.takeException(), isNull);
    } finally {
      for (final reply in gateway.replies) {
        if (!reply.isCompleted) {
          reply.complete(
            const LocalModelResult.answer(
              LocalModelAnswer(text: 'Synthetic cleanup', action: null),
            ),
          );
        }
      }
      await _unmount(tester);
      await tester.runAsync(database.close);
    }
  });

  for (final arabic in [false, true]) {
    testWidgets(
      'newest-edge pull archives and can restore all turns Arabic=$arabic',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final preferences = _RestartPreferences(database);
        final gateway = _HeldGateway();
        try {
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            preferences: preferences,
            historyCount: 8,
            arabic: arabic,
          );
          final original = await preferences.get('intelligenceConversationV1');
          final originalId = await preferences.get(
            'intelligenceConversationActiveIdV1',
          );
          expect(
            tester
                .widget<CoachConversationRestartPull>(
                  find.byType(CoachConversationRestartPull),
                )
                .enabled,
            isTrue,
          );
          await _pullForNewConversation(tester);
          await _drainRestart(tester);
          expect(preferences.switchAttempts, 1);
          expect(await preferences.get('intelligenceConversationV1'), isNull);
          expect(
            await preferences.get('intelligenceConversationActiveIdV1'),
            isNull,
          );
          final archive = decodeCoachConversationHistory(
            await preferences.get('intelligenceConversationHistoryV1'),
          );
          expect(archive.activeConversationId, isNull);
          expect(archive.conversations, hasLength(1));
          expect(archive.conversations.single['id'], originalId);
          expect(
            archive.conversations.single['messages'],
            jsonDecode(original!),
          );
          expect(
            tester
                .widget<CoachAnchoredHistory>(find.byType(CoachAnchoredHistory))
                .rowIds,
            ['coach-session-brief'],
          );
          await tester.tap(
            find.byKey(const Key('ai-coach-conversation-history-button')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(Key('ai-coach-conversation-$originalId')),
          );
          await tester.pumpAndSettle();
          expect(await preferences.get('intelligenceConversationV1'), original);
          expect(
            tester
                .widget<CoachAnchoredHistory>(find.byType(CoachAnchoredHistory))
                .rowIds,
            containsAll(List.generate(8, (i) => 'fixture-$i')),
          );
          expect(gateway.calls, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester);
          await tester.runAsync(database.close);
        }
      },
    );
  }

  for (final fault in [
    'archive-write',
    'archive-readback',
    'switch-write',
    'concurrent-change',
    'post-commit-read',
  ]) {
    testWidgets(
      'restart $fault preserves the actual transcript and permits retry',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final preferences = _RestartPreferences(database);
        final gateway = _HeldGateway();
        try {
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            preferences: preferences,
            historyCount: 8,
          );
          final original = await preferences.get('intelligenceConversationV1');
          preferences.fault = fault;
          await _pullForNewConversation(tester);
          await _drainRestart(tester);
          if (fault == 'post-commit-read') {
            // The atomic switch committed, but verification failed. Keep the
            // visible transcript and its durable archive available for retry.
            final archive = decodeCoachConversationHistory(
              await preferences.get('intelligenceConversationHistoryV1'),
            );
            expect(
              archive.conversations.single['messages'],
              jsonDecode(original!),
            );
          } else {
            expect(
              await preferences.get('intelligenceConversationV1'),
              original,
            );
          }
          expect(
            tester
                .widget<CoachAnchoredHistory>(find.byType(CoachAnchoredHistory))
                .rowIds,
            contains('fixture-7'),
          );
          expect(find.text('Try again'), findsOneWidget);
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const Key('ai-coach-question-field')),
                )
                .enabled,
            isTrue,
          );
          preferences.fault = null;
          await _pullForNewConversation(tester);
          await _drainRestart(tester);
          expect(await preferences.get('intelligenceConversationV1'), isNull);
          final archive = decodeCoachConversationHistory(
            await preferences.get('intelligenceConversationHistoryV1'),
          );
          expect(archive.conversations, hasLength(1));
          expect(
            archive.conversations.single['messages'],
            jsonDecode(original!),
          );
          expect(gateway.calls, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester);
          await tester.runAsync(database.close);
        }
      },
    );
  }

  testWidgets(
    'owner A B A while archiving retires the restart without deleting turns',
    (tester) async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      final changes = StreamController<String?>.broadcast(sync: true);
      var owner = 'owner-a';
      final preferences = _RestartPreferences(database);
      try {
        await _mount(
          tester,
          database: database,
          gateway: _HeldGateway(),
          preferences: preferences,
          historyCount: 8,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => owner,
            changes: changes.stream,
          ),
        );
        final original = await preferences.get('intelligenceConversationV1');
        preferences.archiveWait = Completer<void>();
        await _pullForNewConversation(tester);
        expect(preferences.archiveAttempts, 1);
        owner = 'owner-b';
        changes.add(owner);
        owner = 'owner-a';
        changes.add(owner);
        preferences.archiveWait!.complete();
        await _drainRestart(tester);
        expect(preferences.switchAttempts, 0);
        expect(await preferences.get('intelligenceConversationV1'), original);
        expect(tester.takeException(), isNull);
      } finally {
        if (preferences.archiveWait != null &&
            !preferences.archiveWait!.isCompleted) {
          preferences.archiveWait!.complete();
        }
        await _unmount(tester);
        await changes.close();
        await tester.runAsync(database.close);
      }
    },
  );

  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('pull preview visual Arabic=$arabic dark=$dark', (
        tester,
      ) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          await tester.runAsync(loadVisualEvidenceFont);
          await _mount(
            tester,
            database: database,
            gateway: _HeldGateway(),
            historyCount: 8,
            arabic: arabic,
            dark: dark,
            evidenceFonts: true,
            textScale: dark ? 1.8 : 1,
          );
          final viewport = tester.widget<ChatHistoryViewport>(
            find.byType(ChatHistoryViewport),
          );
          viewport.controller.jumpTo(
            viewport.controller.position.minScrollExtent,
          );
          await tester.pump();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(ChatHistoryViewport)),
          );
          try {
            await gesture.moveBy(const Offset(0, -35));
            await tester.pump();
            expect(
              find.byKey(const Key('coach-new-conversation-pull-status')),
              findsOneWidget,
            );
            expect(
              find.text(arabic ? 'بدء محادثة جديدة' : 'Start new conversation'),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('ai-coach-composer-surface')),
              findsOneWidget,
            );
            const output = String.fromEnvironment('BIL_COACH_PULL_CAPTURE_DIR');
            if (output.isNotEmpty) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('coach-screen-capture-root')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                try {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(output).create(recursive: true);
                  await File(
                    '$output/pull-${arabic ? 'ar' : 'en'}-${dark ? 'dark' : 'light'}.png',
                  ).writeAsBytes(png!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
          } finally {
            await gesture.cancel();
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester);
          await tester.runAsync(database.close);
        }
      });
    }
  }
}
