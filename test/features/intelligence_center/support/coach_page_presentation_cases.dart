part of '../coach_page_lifecycle_regression_test.dart';

Future<void> _presentationPageReady(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  for (var i = 0; i < 100; i++) {
    final fields = find.byKey(const Key('ai-coach-question-field')).evaluate();
    if (fields.isNotEmpty &&
        tester
                .widget<TextField>(
                  find.byKey(const Key('ai-coach-question-field')),
                )
                .enabled ==
            true) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Actual Coach conversation did not become ready');
}

Future<void> _presentationSendRead(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    text,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byType(CoachMessagePresentationView).evaluate().isNotEmpty) return;
  }
  fail('Actual parsed local read did not render a typed body');
}

Finder _presentationCopyButton() => find.byWidgetPredicate(
  (widget) =>
      widget is IconButton &&
      widget.key.toString().contains('ai-coach-copy-tool-meal-read-'),
);
Finder _presentationShareButton() => find.byWidgetPredicate(
  (widget) =>
      widget is IconButton &&
      widget.key.toString().contains('ai-coach-share-tool-meal-read-'),
);
Future<void> _presentationTapVisible(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  final header = tester.widget<Widget>(target) is ExpansionTile;
  // The key belongs to the entire ExpansionTile, including its details. Its
  // center need not be a tappable header. Target the actual ListTile instead.
  final physical = header
      ? find.descendant(of: target, matching: find.byType(ListTile)).first
      : target;
  expect(physical, findsOneWidget);
  final viewportFinder = find.byType(ChatHistoryViewport);
  void trace(String phase) {
    final viewport = tester.getRect(viewportFinder);
    final rect = tester.getRect(physical);
    final view = tester.widget<ChatHistoryViewport>(viewportFinder);
    final position = view.controller.hasClients
        ? view.controller.position
        : null;
    debugPrint(
      'BIL_PRESENTATION_TAP ${jsonEncode({
        'phase': phase,
        'target': header ? 'details_header' : 'message_tool',
        'rect': [rect.left, rect.top, rect.width, rect.height],
        'viewport': [viewport.left, viewport.top, viewport.width, viewport.height],
        'pixels': position?.pixels,
        'latestTarget': position != null && position.hasContentDimensions ? view.latestTargetOffset?.call(position) : null,
        'hitTestable': physical.hitTestable().evaluate().length,
      })}',
    );
  }

  trace('before_scroll');
  final initialViewport = tester.getRect(viewportFinder);
  final initialRect = tester.getRect(physical);
  // Do not move an already tappable header into the floating latest overlay.
  if (physical.hitTestable().evaluate().isEmpty ||
      !initialViewport.contains(initialRect.center)) {
    await tester.ensureVisible(physical);
    await tester.pumpAndSettle();
  }
  // A real drag switches the viewport from following a fresh reply to user
  // reading. Bound the gestures; never force controller state or suppress taps.
  for (
    var attempt = 0;
    attempt < 8 && physical.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    final viewport = tester.getRect(viewportFinder);
    final rect = tester.getRect(physical);
    // A center may be inside the viewport but under the latest-jump button.
    // Move it toward the unobstructed middle using a real reading gesture.
    final towardMiddle = viewport.center.dy - rect.center.dy;
    final delta = towardMiddle == 0
        ? -64.0
        : towardMiddle.sign * towardMiddle.abs().clamp(64, 250).toDouble();
    await tester.drag(viewportFinder, Offset(0, delta));
    await tester.pumpAndSettle();
    trace('physical_drag_$attempt');
  }
  trace('before_tap');
  expect(physical.hitTestable(), findsOneWidget);
  final viewport = tester.getRect(viewportFinder);
  final rect = tester.getRect(physical);
  expect(
    viewport.contains(rect.center),
    isTrue,
    reason: 'Actual header/tool center must be inside the chat viewport.',
  );
  await tester.tap(physical.hitTestable());
  await tester.pump();
}

void registerCoachPresentationPageCases() {
  testWidgets(
    'same owner SQLite reopen restores readable history and draft while retiring old reply',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bil-owner-visit-'),
      ))!;
      final file = File('${directory.path}/owner.sqlite');
      final original = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: presentationFixtureOwner,
      );
      final reopened = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: presentationFixtureOwner,
      );
      var activeDatabase = original;
      final gateway = _HeldGateway();
      try {
        await tester.runAsync(() async {
          await PreferencesRepository(original).set(
            'intelligenceConversationV1',
            jsonEncode([
              IntelligenceMessage(
                id: 'saved-before-reopen',
                role: IntelligenceMessageRole.bil,
                kind: IntelligenceMessageKind.coach,
                text: 'Saved same-owner history.',
                createdAt: presentationFixtureClock,
              ).toJson(),
            ]),
          );
        });
        await _mount(
          tester,
          database: original,
          databaseLoader: () => activeDatabase,
          gateway: gateway,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => presentationFixtureOwner,
            changes: const Stream.empty(),
          ),
        );
        await _presentationPageReady(tester);
        expect(find.text('Saved same-owner history.'), findsOneWidget);
        await _send(tester, gateway, question: 'hi');
        const draft = 'Keep this private unsent draft.';
        await tester.enterText(
          find.byKey(const Key('ai-coach-question-field')),
          draft,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(IntelligenceCenterPage)),
        );
        activeDatabase = reopened;
        container.invalidate(databaseProvider);
        await tester.pump();
        await tester.pump();
        await _presentationPageReady(tester);
        expect(find.text('Saved same-owner history.'), findsOneWidget);
        expect(find.text('hi'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('ai-coach-question-field')),
              )
              .controller!
              .text,
          draft,
        );
        expect(
          find.text('Your account changed. Return to Coach to continue.'),
          findsNothing,
        );
        gateway.finish(text: 'Retired old request must not appear.');
        await tester.pumpAndSettle();
        expect(find.text('Retired old request must not appear.'), findsNothing);
        expect(gateway.calls, 1);
        final saved = await tester.runAsync(
          () =>
              PreferencesRepository(reopened).get('intelligenceConversationV1'),
        );
        expect(saved, isNot(contains('Retired old request must not appear.')));
        expect(tester.takeException(), isNull);
      } finally {
        for (final reply in gateway.replies) {
          if (!reply.isCompleted) {
            reply.complete(
              const LocalModelResult.answer(
                LocalModelAnswer(text: 'Synthetic cleanup.', action: null),
              ),
            );
          }
        }
        await _unmount(tester);
        await tester.runAsync(() async {
          await original.close();
          await reopened.close();
          final expectedPrefix =
              '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}bil-owner-visit-';
          if (!directory.absolute.path.startsWith(expectedPrefix)) {
            throw StateError(
              'Refusing cleanup outside created fixture directory',
            );
          }
          await directory.delete(recursive: true);
        });
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  for (final withdrawal in [
    'foreign auth roundtrip',
    'auth stream error',
    'foreign database',
    'auth roundtrip after recovery scheduled',
  ]) {
    testWidgets(
      'repository reopen never revives a withdrawn visit: $withdrawal',
      (tester) async {
        final original = await openMessagePresentationDatabase(tester);
        final replacement = await openMessagePresentationDatabase(
          tester,
          localOwnerId: withdrawal == 'foreign database'
              ? 'synthetic-other-owner'
              : presentationFixtureOwner,
        );
        var activeDatabase = original;
        var currentOwner = presentationFixtureOwner;
        final events = StreamController<String?>.broadcast(sync: true);
        try {
          await tester.runAsync(() async {
            for (final entry in [
              (original, 'Original owner private message.'),
              (replacement, 'Replacement database private message.'),
            ]) {
              await PreferencesRepository(entry.$1).set(
                'intelligenceConversationV1',
                jsonEncode([
                  IntelligenceMessage(
                    id: 'before-withdrawal',
                    role: IntelligenceMessageRole.bil,
                    kind: IntelligenceMessageKind.coach,
                    text: entry.$2,
                    createdAt: presentationFixtureClock,
                  ).toJson(),
                ]),
              );
            }
          });
          await _mount(
            tester,
            database: original,
            databaseLoader: () => activeDatabase,
            gateway: _HeldGateway(),
            messageOwnerWitness: CoachNativeOwnerWitness(
              readOwner: () => currentOwner,
              changes: events.stream,
            ),
          );
          await _presentationPageReady(tester);
          final originalState = tester.state(
            find.byType(IntelligenceCenterPage),
          );
          expect(find.text('Original owner private message.'), findsOneWidget);
          void authRoundtrip() {
            currentOwner = 'synthetic-other-owner';
            events.add(currentOwner);
            currentOwner = presentationFixtureOwner;
            events.add(currentOwner);
          }

          if (withdrawal == 'foreign auth roundtrip') authRoundtrip();
          if (withdrawal == 'auth stream error') {
            events.addError(StateError('Synthetic auth witness unavailable'));
          }
          final container = ProviderScope.containerOf(
            tester.element(find.byType(IntelligenceCenterPage)),
          );
          activeDatabase = replacement;
          container.invalidate(databaseProvider);
          container.read(databaseProvider);
          if (withdrawal == 'auth roundtrip after recovery scheduled') {
            await tester.pump();
            authRoundtrip();
          }
          await tester.pump();
          await tester.pump();
          expect(
            tester.state(find.byType(IntelligenceCenterPage)),
            same(originalState),
          );
          expect(find.text('Original owner private message.'), findsNothing);
          expect(
            find.text('Replacement database private message.'),
            findsNothing,
          );
          expect(
            find.text('Your account changed. Return to Coach to continue.'),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester);
          await events.close();
          await tester.runAsync(() async {
            await original.close();
            await replacement.close();
          });
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }

  testWidgets(
    'same owner auth event preserves the existing readable visit',
    (tester) async {
      final database = await openMessagePresentationDatabase(tester);
      final events = StreamController<String?>.broadcast(sync: true);
      try {
        await tester.runAsync(
          () => PreferencesRepository(database).set(
            'intelligenceConversationV1',
            jsonEncode([
              IntelligenceMessage(
                id: 'same-owner-auth',
                role: IntelligenceMessageRole.bil,
                kind: IntelligenceMessageKind.coach,
                text: 'Same owner remains readable.',
                createdAt: presentationFixtureClock,
              ).toJson(),
            ]),
          ),
        );
        await _mount(
          tester,
          database: database,
          gateway: _HeldGateway(),
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => presentationFixtureOwner,
            changes: events.stream,
          ),
        );
        await _presentationPageReady(tester);
        final originalState = tester.state(find.byType(IntelligenceCenterPage));
        events.add(presentationFixtureOwner);
        await tester.pump();
        expect(
          tester.state(find.byType(IntelligenceCenterPage)),
          same(originalState),
        );
        expect(find.text('Same owner remains readable.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester);
        await events.close();
        await tester.runAsync(database.close);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'actual page meal read fold copy share and reopening preserve SQLite facts',
    (tester) async {
      final database = await openMessagePresentationDatabase(tester);
      final gateway = _HeldGateway();
      final copied = <String>[], shared = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text']! as String);
        }
        if (call.method == 'Clipboard.hasStrings') return {'value': false};
        return null;
      });
      messenger.setMockMethodCallHandler(share, (call) async {
        shared.add((call.arguments as Map)['text']! as String);
        return 'synthetic-share-target';
      });
      try {
        await tester.runAsync(() async {
          await seedMessageFood(database);
          final old = IntelligenceMessage(
            id: 'old-readable',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: 'Old readable reply.',
            createdAt: presentationFixtureClock,
          );
          await PreferencesRepository(database).set(
            'intelligenceConversationV1',
            jsonEncode([
              old.toJson(),
              {
                ...old.copyWith(text: 'Saved readable fallback.').toJson(),
                'id': 'invalid-block',
                'localPresentation': {
                  'schema': 'unknown-v99',
                  'ownerKey': presentationFixtureOwnerKey,
                },
              },
            ]),
          );
        });
        final original = (await tester.runAsync(
          () => database.select(database.mealItems).get(),
        ))!;
        await tester.runAsync(loadVisualEvidenceFont);
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          evidenceFonts: true,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => presentationFixtureOwner,
            changes: const Stream.empty(),
          ),
        );
        await _presentationPageReady(tester);
        await _presentationSendRead(
          tester,
          'show lunch nutrition on 2026-10-09',
        );
        expect(gateway.calls, 0);
        expect(find.text('97.5 kcal'), findsOneWidget);
        expect(find.text('Copy'), findsNothing);
        expect(find.text('Share'), findsNothing);
        expect(
          tester.widget<IconButton>(_presentationCopyButton()).tooltip,
          'Copy answer',
        );
        expect(
          tester.widget<IconButton>(_presentationShareButton()).tooltip,
          'Share answer',
        );
        final details = find.byKey(const ValueKey('coach-nutrition-details'));
        await _presentationTapVisible(tester, details);
        await tester.pumpAndSettle();
        expect(find.text('Vitamin A'), findsOneWidget);
        await _presentationTapVisible(tester, _presentationCopyButton());
        await tester.pump();
        await _presentationTapVisible(tester, _presentationShareButton());
        await tester.pumpAndSettle();
        expect(copied, hasLength(1));
        expect(shared, [copied.single]);
        expect(copied.single, contains('Calories: 97.5 kcal'));
        expect(copied.single, contains('Fiber: 1.5 g'));
        expect(copied.single, contains('Net carbs: 12 g'));
        expect(copied.single, isNot(contains(presentationFixtureOwnerKey)));
        final after = (await tester.runAsync(
          () => database.select(database.mealItems).get(),
        ))!;
        expect(
          after.map((x) => x.toJson()).toList(),
          original.map((x) => x.toJson()).toList(),
        );
        // Wait for the real queued local conversation save before reopening.
        for (var i = 0; i < 50; i++) {
          final raw = await tester.runAsync(
            () => PreferencesRepository(
              database,
            ).get('intelligenceConversationV1'),
          );
          if (raw != null && raw.contains('localPresentation')) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await _unmount(tester);
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          evidenceFonts: true,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => presentationFixtureOwner,
            changes: const Stream.empty(),
          ),
        );
        await _presentationPageReady(tester);
        expect(find.byType(CoachMessagePresentationView), findsOneWidget);
        expect(find.text('97.5 kcal'), findsOneWidget);
        expect(
          (await tester.runAsync(
            () => database.select(database.mealItems).get(),
          ))!.map((x) => x.uuid),
          original.map((x) => x.uuid),
        );
        expect(gateway.calls, 0);
        await tester.drag(
          find.byType(ChatHistoryViewport),
          const Offset(0, 450),
        );
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CoachMessageText &&
                widget.text == 'Old readable reply.',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CoachMessageText &&
                widget.text == 'Saved readable fallback.',
          ),
          findsOneWidget,
        );
        await _send(tester, gateway, question: 'hi');
        expect(gateway.conversations, hasLength(1));
        expect(
          gateway.conversations.single.any(
            (turn) =>
                turn.content.contains('97.5') ||
                turn.content.contains('Vitamin A'),
          ),
          isFalse,
          reason: 'Local card facts must not silently extend model history.',
        );
        gateway.finish(text: 'Ordinary follow-up.');
        await tester.pumpAndSettle();
      } finally {
        for (final pending in gateway.replies) {
          if (!pending.isCompleted) {
            pending.complete(
              LocalModelResult.answer(
                LocalModelAnswer(text: 'Synthetic cleanup.', action: null),
              ),
            );
          }
        }
        try {
          await _unmount(tester);
        } finally {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          messenger.setMockMethodCallHandler(share, null);
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'actual page two meal comparison reads same records without duplicate writes',
    (tester) async {
      final database = await openMessagePresentationDatabase(tester);
      final gateway = _HeldGateway();
      try {
        await tester.runAsync(() async {
          await seedMessageFood(database);
          await seedMessageFood(
            database,
            operation: 'dinner-read',
            meal: 'dinner',
          );
        });
        final ids = (await tester.runAsync(
          () => database.select(database.mealItems).get(),
        ))!.map((x) => x.uuid).toList();
        await tester.runAsync(loadVisualEvidenceFont);
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          evidenceFonts: true,
          arabic: true,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => presentationFixtureOwner,
            changes: const Stream.empty(),
          ),
        );
        await _presentationPageReady(tester);
        await _presentationSendRead(
          tester,
          'قارن الغداء بتاريخ ٢٠٢٦-١٠-٠٩ مع العشاء بتاريخ ٢٠٢٦-١٠-٠٩',
        );
        expect(gateway.calls, 0);
        expect(find.byType(CoachMessagePresentationView), findsOneWidget);
        expect(find.text('الغداء'), findsOneWidget);
        expect(find.text('العشاء'), findsOneWidget);
        expect(
          (await tester.runAsync(
            () => database.select(database.mealItems).get(),
          ))!.map((x) => x.uuid),
          ids,
        );
      } finally {
        for (final pending in gateway.replies) {
          if (!pending.isCompleted) {
            pending.complete(
              LocalModelResult.answer(
                LocalModelAnswer(text: 'Synthetic cleanup.', action: null),
              ),
            );
          }
        }
        try {
          await _unmount(tester);
        } finally {
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'actual page delivered A B A permanently hides old facts and copy actions',
    (tester) async {
      final database = await openMessagePresentationDatabase(tester);
      final gateway = _HeldGateway(),
          events = StreamController<String?>.broadcast(sync: true);
      var current = presentationFixtureOwner;
      try {
        await tester.runAsync(() => seedMessageFood(database));
        await tester.runAsync(loadVisualEvidenceFont);
        await _mount(
          tester,
          database: database,
          gateway: gateway,
          evidenceFonts: true,
          messageOwnerWitness: CoachNativeOwnerWitness(
            readOwner: () => current,
            changes: events.stream,
          ),
        );
        await _presentationPageReady(tester);
        await _presentationSendRead(tester, 'show lunch on 2026-10-09');
        expect(find.text('97.5 kcal'), findsOneWidget);
        current = 'synthetic-other-owner';
        events.add(current);
        current = presentationFixtureOwner;
        events.add(current);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // The old GlobalKey may have been deactivated by this frame. A later
        // viewport callback must not read it or revive an A-to-B-to-A visit.
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        expect(find.text('97.5 kcal'), findsNothing);
        expect(_presentationCopyButton(), findsNothing);
        expect(_presentationShareButton(), findsNothing);
        expect(gateway.calls, 0);
      } finally {
        try {
          await _unmount(tester);
        } finally {
          await events.close();
          await tester.runAsync(database.close);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
