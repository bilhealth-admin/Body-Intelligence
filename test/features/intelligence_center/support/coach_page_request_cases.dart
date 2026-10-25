part of '../coach_page_lifecycle_regression_test.dart';

class _ReceiptStatusGateway extends _HeldGateway
    implements RequestScopedLocalModelGateway {
  final boundRequests = <CoachCloudRequest>[];
  final receiptRequestIds = <String>[];
  String receiptState = 'reserved';
  late CoachCloudRequest _request;

  @override
  LocalModelGateway forCloudRequest(CoachCloudRequest request) {
    boundRequests.add(request);
    _request = request;
    return this;
  }

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    final request = _request;
    if (request.beginSubmission(
      readReceipt: () async {
        receiptRequestIds.add(request.requestId);
        final settled = receiptState == 'succeeded';
        return {
          'request_id': request.requestId,
          'capability': 'text',
          'state': receiptState,
          'credit_actual': settled ? 3 : 0,
          'credit_included_actual': settled ? 3 : 0,
          'credit_paid_actual': 0,
          'completed_at': settled ? '2026-10-20T12:00:00Z' : null,
        };
      },
    )) {
      calls++;
    }
    return const LocalModelResult(
      status: CoachServiceStatus.temporarilyUnavailable,
    );
  }
}

void _expectCoachPearlAction(
  WidgetTester tester,
  Finder action, {
  IconData? glyph,
  bool enabled = true,
}) {
  expect(action.hitTestable(), findsOneWidget);
  final size = tester.getSize(action);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
  final button = tester.widget<IconButton>(action);
  expect(button.onPressed == null, !enabled);
  final data = tester.getSemantics(action).getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.flagsCollection.isEnabled.toBoolOrNull(), enabled);
  expect(data.hasAction(ui.SemanticsAction.tap), enabled);
  final finish = tester.widget<DecoratedBox>(
    find.byKey(const Key('ai-coach-composer-action-finish')),
  );
  final decoration = finish.decoration as BoxDecoration;
  expect(decoration.shape, BoxShape.circle);
  final gradient = decoration.gradient as LinearGradient;
  expect(gradient.colors, const [
    Colors.white,
    Color(0xFFECF3F8),
    Color(0xFFD7E4EF),
  ]);
  const ink = Color(0xFF14243A);
  for (final color in gradient.colors) {
    expect(color.a, 1);
    expect(
      (color.computeLuminance() + .05) / (ink.computeLuminance() + .05),
      greaterThanOrEqualTo(4.5),
    );
  }
  if (glyph != null) {
    final icon = tester.widget<Icon>(
      find.descendant(of: action, matching: find.byIcon(glyph)),
    );
    expect(icon.color, enabled ? ink : ink.withValues(alpha: .38));
  }
}

void _expectCoachPearlSemantics(
  WidgetTester tester,
  Finder action,
  String expectedName,
) {
  final data = tester.getSemantics(action).getSemanticsData();
  debugPrint(
    'BIL_PEARL_SEMANTICS ${jsonEncode({'label': data.label, 'tooltip': data.tooltip, 'button': data.flagsCollection.isButton, 'enabled': data.flagsCollection.isEnabled.toBoolOrNull(), 'tap': data.hasAction(ui.SemanticsAction.tap)})}',
  );
  // Installed Material Tooltip publishes semanticsTooltip, a distinct field
  // from label. Require the actual accessible name AND tooltip verbatim.
  expect(data.tooltip, expectedName);
  expect(data.label.isEmpty ? data.tooltip : data.label, expectedName);
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
  expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
}

void registerCoachRequestCases() {
  for (final arabic in [false, true]) {
    testWidgets(
      'cloud request status retry keeps one generation at 320px 2x Arabic=$arabic',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _ReceiptStatusGateway();
        try {
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            arabic: arabic,
            size: const Size(320, 700),
            textScale: 2,
            evidenceFonts: true,
          );
          await _send(tester, gateway, question: 'Explain balanced nutrition');
          await tester.pumpAndSettle();
          final retry = find.byKey(const Key('ai-coach-retry'));
          final retryLabel = arabic
              ? 'التحقق من حالة الطلب'
              : 'Check request status';
          expect(find.text(retryLabel), findsOneWidget);
          void traceRetry(String phase) {
            final dynamic state = tester.state(
              find.byType(IntelligenceCenterPage),
            );
            final controller = state.conversationScroll as ScrollController;
            final rect = tester.getRect(retry);
            final viewport = tester.getRect(find.byType(CoachAnchoredHistory));
            final media = MediaQuery.of(tester.element(retry));
            debugPrint(
              'BIL_STATUS_RETRY_VIEWPORT ${jsonEncode({
                'phase': phase,
                'arabic': arabic,
                'button': [rect.left, rect.top, rect.right, rect.bottom],
                'viewport': [viewport.left, viewport.top, viewport.right, viewport.bottom],
                'composer': tester.getRect(find.byKey(const Key('ai-coach-composer-surface'))).toString(),
                'keyboard': media.viewInsets.bottom,
                'textScale': media.textScaler.scale(1),
                'scroll': controller.positions.map((p) => {'pixels': p.pixels, 'min': p.minScrollExtent, 'max': p.maxScrollExtent, 'viewport': p.viewportDimension}).toList(),
                'hitTestable': retry.hitTestable().evaluate().length,
                'jumpButton': find.byKey(const ValueKey('chat-jump-to-latest')).evaluate().isEmpty ? null : tester.getRect(find.byKey(const ValueKey('chat-jump-to-latest'))).toString(),
                'hitPath': tester.hitTestOnBinding(rect.center).path.take(12).map((entry) => {'type': entry.target.runtimeType.toString(), if (entry.target is RenderParagraph) 'text': (entry.target as RenderParagraph).text.toPlainText()}).toList(),
              })}',
            );
          }

          traceRetry('before-ensureVisible');
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          traceRetry('after-ensureVisible');
          // ensureVisible can align this long turn's action beneath the
          // floating latest-message shortcut. Read further with a real drag;
          // retain the center hit-test and actual tap rather than bypassing it.
          await tester.drag(
            find.byType(CoachAnchoredHistory),
            const Offset(0, -110),
          );
          await tester.pumpAndSettle();
          traceRetry('after-real-reading-drag');
          expect(retry.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(retry);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          expect(
            tester.getSemantics(retry).getSemanticsData().label,
            contains(retryLabel),
          );
          expect(tester.takeException(), isNull);
          expect(gateway.calls, 1);
          expect(gateway.boundRequests, hasLength(1));
          final originalId = gateway.boundRequests.single.requestId;

          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              arabic
                  ? 'ما زال هذا الطلب قيد المعالجة'
                  : 'This request is still being processed',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(find.text(retryLabel), findsOneWidget);
          expect(gateway.calls, 1);
          expect(gateway.boundRequests, hasLength(1));
          expect(gateway.receiptRequestIds, [originalId]);
          expect(tester.takeException(), isNull);

          gateway.receiptState = 'succeeded';
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              arabic
                  ? 'اكتمل هذا الطلب، لكن لم يصل رده'
                  : 'This request completed, but its reply was not received',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(retry, findsNothing);
          expect(gateway.calls, 1);
          expect(gateway.boundRequests, hasLength(1));
          expect(gateway.receiptRequestIds, [originalId, originalId]);
          expect(tester.takeException(), isNull);
        } finally {
          try {
            await _unmount(tester);
          } finally {
            semantics.dispose();
            await tester.runAsync(database.close);
          }
        }
      },
    );
  }

  for (final dark in [false, true]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'Coach pearl send keeps actual dispatch draft and pending gate dark=$dark Arabic=$arabic',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          final gateway = _HeldGateway();
          try {
            await _mount(
              tester,
              database: database,
              gateway: gateway,
              dark: dark,
              highContrast: true,
              arabic: arabic,
              size: const Size(320, 700),
              textScale: 2,
              evidenceFonts: true,
            );
            const question = 'Explain balanced nutrition';
            await tester.enterText(
              find.byKey(const Key('ai-coach-question-field')),
              question,
            );
            await tester.pump();
            final send = find.byKey(const Key('ai-coach-send-button'));
            _expectCoachPearlAction(
              tester,
              send,
              glyph: Icons.arrow_upward_rounded,
            );
            _expectCoachPearlSemantics(tester, send, arabic ? 'إرسال' : 'Send');
            await _send(tester, gateway, question: question);
            expect(gateway.calls, 1);
            _expectCoachPearlAction(
              tester,
              send,
              glyph: Icons.arrow_upward_rounded,
              enabled: false,
            );
            expect(
              find.descendant(
                of: send,
                matching: find.byType(CircularProgressIndicator),
              ),
              findsNothing,
            );
            await tester.enterText(
              find.byKey(const Key('ai-coach-question-field')),
              'My next unsent message',
            );
            await tester.pump();
            await tester.tap(send);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              gateway.calls,
              1,
              reason:
                  'A physical double send cannot duplicate the pending request.',
            );
            gateway.finish(text: 'A verified synthetic reply.');
            await tester.pumpAndSettle();
            expect(find.text('A verified synthetic reply.'), findsOneWidget);
            expect(
              tester
                  .widget<TextField>(
                    find.byKey(const Key('ai-coach-question-field')),
                  )
                  .controller!
                  .text,
              'My next unsent message',
            );
            _expectCoachPearlAction(
              tester,
              send,
              glyph: Icons.arrow_upward_rounded,
            );
            expect(tester.takeException(), isNull);
          } finally {
            for (final pending in gateway.replies) {
              if (!pending.isCompleted) {
                pending.complete(
                  LocalModelResult.answer(
                    LocalModelAnswer(
                      text: 'Synthetic fixture cancelled.',
                      action: null,
                    ),
                  ),
                );
              }
            }
            try {
              await _unmount(tester);
            } finally {
              semantics.dispose();
              await tester.runAsync(database.close);
            }
          }
        },
      );
    }
  }
  testWidgets(
    'Arabic greeting completes locally without an incomplete reply card',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _HeldGateway();
      await _mount(tester, database: database, gateway: gateway);
      await _send(tester, gateway, question: 'كيفك');
      expect(
        find.byKey(const Key('ai-coach-thinking-indicator')),
        findsOneWidget,
      );
      gateway.reply.complete(
        const LocalModelResult(
          status: CoachServiceStatus.temporarilyUnavailable,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-coach-thinking-indicator')),
        findsNothing,
      );
      expect(find.textContaining('أنا جاهز معك'), findsOneWidget);
      expect(find.byKey(const Key('ai-coach-retry')), findsNothing);
      expect(find.byKey(const Key('ai-coach-reply-progress')), findsNothing);
      expect(find.textContaining('The reply did not complete'), findsNothing);
      await tester.pump(const Duration(seconds: 35));
      expect(gateway.calls, 1);
      final raw = await PreferencesRepository(
        database,
      ).get('intelligenceConversationV1');
      final turns = (jsonDecode(raw!) as List).cast<Map>();
      expect(turns.where((turn) => turn['role'] == 'user'), hasLength(1));
      expect(
        turns.where(
          (turn) => (turn['text'] as String).contains('أنا جاهز معك'),
        ),
        hasLength(1),
      );
      await _unmount(tester);
    },
  );
  testWidgets('repeated service failure keeps one transcript retry surface', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(tester, database: database, gateway: gateway);
    await _send(tester, gateway, question: 'Explain balanced nutrition');
    const failure = LocalModelResult(
      status: CoachServiceStatus.temporarilyUnavailable,
    );
    gateway.reply.complete(failure);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-coach-reply-progress')), findsNothing);
    await tester.tap(find.byKey(const Key('ai-coach-retry')));
    for (var i = 0; i < 60 && gateway.calls < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gateway.calls, 2);
    gateway.replies[1].complete(failure);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
    expect(find.byKey(const Key('ai-coach-reply-progress')), findsNothing);
    await tester.pump(const Duration(seconds: 35));
    expect(gateway.calls, 2);
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    final turns = (jsonDecode(raw!) as List).cast<Map>();
    expect(turns.where((turn) => turn['role'] == 'user'), hasLength(1));
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
  testWidgets('each new question receives its own service failure reply', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(tester, database: database, gateway: gateway);
    const failure = LocalModelResult(
      status: CoachServiceStatus.temporarilyUnavailable,
    );
    List<IntelligenceMessage> assistantMessages() {
      final dynamic state = tester.state(find.byType(IntelligenceCenterPage));
      return List<IntelligenceMessage>.from(state.messages as List)
          .where((message) => message.role == IntelligenceMessageRole.bil)
          .toList(growable: false);
    }

    final initialAssistantCount = assistantMessages().length;

    // Weight history now resolves locally. This scenario must exercise two
    // actual cloud turns, so retain its service-failure assertions there.
    await _send(tester, gateway, question: 'Explain balanced nutrition');
    gateway.replies[0].complete(failure);
    await tester.pumpAndSettle();
    final afterFirst = assistantMessages();
    expect(afterFirst, hasLength(initialAssistantCount + 1));
    final firstFailure = afterFirst.last;

    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'How tall am I?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-coach-send-button')));
    for (var i = 0; i < 100 && gateway.calls < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gateway.calls, 2);
    gateway.replies[1].complete(failure);
    await tester.pumpAndSettle();

    final afterSecond = assistantMessages();
    expect(afterSecond, hasLength(initialAssistantCount + 2));
    final secondFailure = afterSecond.last;
    expect(secondFailure.text, firstFailure.text);
    final history = tester.widget<CoachAnchoredHistory>(
      find.byType(CoachAnchoredHistory),
    );
    expect(history.rowIds, containsAll([firstFailure.id, secondFailure.id]));
    expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
  for (final failure in ['service', 'exception', 'timeout']) {
    testWidgets('one first-message failure surface: $failure', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _HeldGateway();
      await _mount(tester, database: database, gateway: gateway);
      await _send(tester, gateway, question: 'Explain balanced nutrition');
      if (failure == 'service') {
        gateway.reply.complete(
          const LocalModelResult(
            status: CoachServiceStatus.temporarilyUnavailable,
          ),
        );
      } else if (failure == 'exception') {
        gateway.reply.completeError(StateError('controlled API failure'));
      } else {
        await tester.pump(const Duration(seconds: 31));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
      expect(find.byKey(const Key('ai-coach-reply-progress')), findsNothing);
      expect(gateway.calls, 1);
      await tester.pump(const Duration(seconds: 35));
      expect(gateway.calls, 1, reason: 'Failure must not automatically resend');
      if (failure == 'timeout') {
        gateway.finish(text: 'Late response must be ignored');
        await tester.pumpAndSettle();
        expect(find.text('Late response must be ignored'), findsNothing);
      }
      final raw = await PreferencesRepository(
        database,
      ).get('intelligenceConversationV1');
      final turns = (jsonDecode(raw!) as List).cast<Map>();
      expect(
        turns.where(
          (turn) =>
              turn['role'] == 'user' &&
              turn['text'] == 'Explain balanced nutrition',
        ),
        hasLength(1),
      );
      expect(find.byKey(const Key('ai-coach-retry')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
  testWidgets('a different entitlement owner gets a fresh UI state', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final owners = StreamController<String?>();
    addTearDown(owners.close);
    // An intentionally unresolved identity keeps a checking animation. Seed
    // the first authenticated owner before waiting for this mounted fixture.
    owners.add('member-one');
    await _mount(
      tester,
      database: database,
      gateway: _HeldGateway(),
      gate: true,
      owners: owners.stream,
    );
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
    // A new owner gets its own default Overview. Enter through its real action
    // before asserting that the previous owner's draft did not cross accounts.
    await openCoachConversationFromOverview(tester);
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
        if (fail) {
          // A transient background revalidation error must not tear down a
          // previously server-verified Coach surface. The request path remains
          // server-authoritative and can still reject unavailable credit.
          expect(
            find.byKey(const Key('premium-route-access-unavailable')),
            findsNothing,
          );
          expect(find.byType(IntelligenceCenterPage), findsOneWidget);
        } else {
          expect(
            find.byKey(const Key('premium-route-upgrade-cta')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('ai-coach-send-button')).hitTestable(),
            findsNothing,
          );
        }
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

  testWidgets('in-flight response disables send without a second spinner', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _HeldGateway();
    await _mount(tester, database: database, gateway: gateway);
    await _send(tester, gateway);
    final disabledSend = tester.widget<IconButton>(
      find.byKey(const Key('ai-coach-send-button')),
    );
    expect(disabledSend.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('ai-coach-send-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    gateway.finish(text: 'Keep this current reply');
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
    await _send(tester, gateway, question: 'Explain balanced nutrition');
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
      turns.where(
        (turn) =>
            turn['role'] == 'user' &&
            turn['text'] == 'Explain balanced nutrition',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
