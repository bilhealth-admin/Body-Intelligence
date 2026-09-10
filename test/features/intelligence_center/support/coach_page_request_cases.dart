part of '../coach_page_lifecycle_regression_test.dart';

void registerCoachRequestCases() {
  testWidgets('a different entitlement owner gets a fresh UI state', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final owners = StreamController<String?>();
    addTearDown(owners.close);
    await _mount(
      tester,
      database: database,
      gateway: _HeldGateway(),
      gate: true,
      owners: owners.stream,
    );
    owners.add('member-one');
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(IntelligenceCenterPage));
    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'Private unsent draft',
    );
    owners.add('member-two');
    await tester.pumpAndSettle();
    expect(
      identical(state, tester.state(find.byType(IntelligenceCenterPage))),
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
          .controller!
          .text,
      isEmpty,
    );
    await _unmount(tester);
  });
  testWidgets(
    'failed local restore preserves the transcript and offers retry',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = _HeldPreferences(database)..failTranscriptRead = true;
      await _mount(
        tester,
        database: database,
        gateway: _HeldGateway(),
        preferences: preferences,
        historyCount: 8,
      );
      final original = await PreferencesRepository(
        database,
      ).get('intelligenceConversationV1');
      expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
            .enabled,
        isFalse,
      );
      preferences.failTranscriptRead = false;
      await tester.tap(find.byKey(const Key('ai-coach-retry')));
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey('coach-message-text-fixture-7'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(await preferences.get('intelligenceConversationV1'), original);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('leaving a corrupt snapshot does not silently overwrite it', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    const raw = 'damaged but preserved original transcript';
    await preferences.set('intelligenceConversationV1', raw);
    await _mount(tester, database: database, gateway: _HeldGateway());
    expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
    await _unmount(tester);
    expect(await preferences.get('intelligenceConversationV1'), raw);
  });
  for (final fail in [false, true]) {
    testWidgets(
      'credit refresh denies exhausted/error access, retains draft, recovers error=$fail',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        var available = true;
        await _mount(
          tester,
          database: database,
          gateway: _HeldGateway(),
          gate: true,
          usageLoader: () async {
            if (!available && fail) throw StateError('controlled unavailable');
            return {
              'credits': {'total_remaining': available ? 1000 : 0},
            };
          },
        );
        final state = tester.state(find.byType(IntelligenceCenterPage));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(IntelligenceCenterPage)),
        );
        await tester.enterText(
          find.byKey(const Key('ai-coach-question-field')),
          'Preserved after access check',
        );
        available = false;
        container.invalidate(aiCoachCreditAccessProvider);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              fail
                  ? 'premium-route-access-unavailable'
                  : 'premium-route-glass-blur',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('ai-coach-send-button')).hitTestable(),
          findsNothing,
        );
        available = true;
        container.invalidate(aiCoachCreditAccessProvider);
        await tester.pumpAndSettle();
        expect(
          identical(state, tester.state(find.byType(IntelligenceCenterPage))),
          isTrue,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('ai-coach-question-field')),
              )
              .controller!
              .text,
          'Preserved after access check',
        );
        expect(
          find.byKey(const Key('ai-coach-send-button')).hitTestable(),
          findsOneWidget,
        );
        await _unmount(tester);
      },
    );
  }

  testWidgets('cancelled response cannot overwrite a newer request', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(tester, database: database, gateway: gateway);
    await _send(tester, gateway);
    await tester.tap(find.byKey(const Key('ai-coach-cancel-request')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'hi',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-coach-send-button')));
    for (var i = 0; i < 60 && gateway.calls < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gateway.calls, 2);
    gateway.finish(text: 'Discard this cancelled reply');
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Discard this cancelled reply'), findsNothing);
    expect(find.byKey(const Key('ai-coach-cancel-request')), findsOneWidget);
    gateway.finish(index: 1, text: 'Keep this current reply');
    await tester.pumpAndSettle();
    expect(find.text('Keep this current reply'), findsOneWidget);
    expect(find.textContaining('Searching your BIL context'), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('retry keeps exactly one user turn', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(tester, database: database, gateway: gateway);
    await _send(tester, gateway);
    gateway.reply.complete(
      const LocalModelResult(status: CoachServiceStatus.temporarilyUnavailable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-coach-retry')));
    for (var i = 0; i < 60 && gateway.calls < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gateway.calls, 2);
    gateway.finish(index: 1);
    await tester.pumpAndSettle();
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    final turns = (jsonDecode(raw!) as List).cast<Map>();
    expect(
      turns.where((turn) => turn['role'] == 'user' && turn['text'] == 'hi'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
