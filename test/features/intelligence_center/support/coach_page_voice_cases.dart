part of '../coach_page_lifecycle_regression_test.dart';

Future<void> _acceptCoachVoiceDisclosure(WidgetTester tester) async {
  for (
    var frame = 0;
    frame < 40 && find.byKey(systemSpeechDisclosureAllowKey).evaluate().isEmpty;
    frame++
  ) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await acceptSystemSpeechDisclosure(tester, settleAfterAccept: false);
}

Map<String, int> _mockCoachVoice(
  WidgetTester tester, {
  Future<bool>? available,
}) {
  final calls = <String, int>{};
  final messenger = tester.binding.defaultBinaryMessenger;
  for (final name in [
    'flutter/platform',
    'bil/speech',
    'bil/speech/events',
    'bil/tts',
    'bil/mic_sound',
    'flutter.baseflow.com/permissions/methods',
  ]) {
    final channel = name == 'flutter/platform'
        ? SystemChannels.platform
        : MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      final key = '$name:${call.method}';
      calls[key] = (calls[key] ?? 0) + 1;
      if (call.method == 'checkPermissionStatus') return 1;
      if (call.method == 'available') {
        return available == null ? true : await available;
      }
      if (call.method == 'locales') return ['en-US', 'ar-EG'];
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  return calls;
}

Future<void> _emitCoachVoice(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'bil/speech/events',
    const StandardMethodCodec().encodeSuccessEnvelope({
      'type': 'result',
      'words': 'Explain consistency in everyday habits',
      'final': true,
      'localeId': 'en-US',
    }),
    (_) {},
  );
  await tester.pump(const Duration(milliseconds: 950));
}

Future<void> _waitForCoachCall(
  WidgetTester tester,
  _HeldGateway gateway,
) async {
  for (var i = 0; i < 60 && gateway.calls == 0; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(gateway.calls, 1);
}

void registerCoachVoiceCases() {
  for (final dark in [false, true]) {
    testWidgets(
      'Coach pearl recording keeps real start stop and no text dispatch dark=$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _HeldGateway();
        final calls = _mockCoachVoice(tester);
        try {
          await _mount(
            tester,
            database: database,
            gateway: gateway,
            dark: dark,
            arabic: dark,
            evidenceFonts: true,
          );
          final voice = find.byKey(const Key('ai-coach-voice-button'));
          _expectCoachPearlAction(
            tester,
            voice,
            glyph: Icons.graphic_eq_rounded,
          );
          _expectCoachPearlSemantics(
            tester,
            voice,
            dark ? 'تحدث مع BIL' : 'Talk to BIL',
          );
          await tester.tap(voice);
          await _acceptCoachVoiceDisclosure(tester);
          for (
            var i = 0;
            i < 20 && (calls['bil/speech:listen'] ?? 0) == 0;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(calls['bil/speech:listen'], 1);
          await tester.pump(const Duration(milliseconds: 200));
          _expectCoachPearlAction(tester, voice);
          expect(
            tester.widget<IconButton>(voice).tooltip,
            dark ? 'إنهاء المكالمة' : 'End live call',
          );
          _expectCoachPearlSemantics(
            tester,
            voice,
            dark ? 'إنهاء المكالمة' : 'End live call',
          );
          final waveBars = find.descendant(
            of: voice,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          );
          expect(waveBars, findsNWidgets(4));
          for (final bar in tester.widgetList<Container>(waveBars)) {
            expect(
              (bar.decoration as BoxDecoration).color,
              const Color(0xFF14243A),
            );
          }
          final composer = tester.widget<AnimatedContainer>(
            find.byKey(const Key('ai-coach-composer-surface')),
          );
          final edge = (composer.decoration as BoxDecoration).border! as Border;
          expect(
            edge.top.color,
            dark ? const Color(0xFF526B80) : const Color(0xFFC4D3E0),
          );
          expect(edge.top.width, 1.5);
          expect(gateway.calls, 0);
          await tester.tap(voice);
          await tester.pumpAndSettle();
          expect(calls['bil/speech:cancel'], greaterThanOrEqualTo(1));
          expect(
            find.byKey(const Key('ai-coach-question-field')).hitTestable(),
            findsOneWidget,
          );
          _expectCoachPearlAction(
            tester,
            voice,
            glyph: Icons.graphic_eq_rounded,
          );
          expect(
            gateway.calls,
            0,
            reason:
                'Starting and ending an empty recording never invents an AI question.',
          );
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
  testWidgets(
    'Quick Add pauses live voice and retains the unfinished transcript',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final calls = _mockCoachVoice(tester);
      final gateway = _HeldGateway();
      await _mount(tester, database: database, gateway: gateway);
      await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
      await _acceptCoachVoiceDisclosure(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls['bil/speech:listen'], 1);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'bil/speech/events',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'type': 'result',
          'words': 'Keep this unfinished spoken draft',
          'final': false,
          'localeId': 'en-US',
        }),
        (_) {},
      );
      await tester.pump();
      final cancelledBefore = calls['bil/speech:cancel'] ?? 0;
      await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byType(BilQuickAddSheet), findsOneWidget);
      expect(calls['bil/speech:cancel'], cancelledBefore + 1);
      expect(calls['bil/tts:stop'], greaterThanOrEqualTo(1));
      // A late result from the cancelled recognizer cannot replace this draft
      // or start a Coach request while the shared action sheet covers it.
      await _emitCoachVoice(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(gateway.calls, 0);
      expect(calls['bil/speech:listen'], 1);
      Navigator.of(tester.element(find.byType(BilQuickAddSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
            .controller!
            .text,
        'Keep this unfinished spoken draft',
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'camera permission is single-flight and returning late cannot open a route',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      _mockCoachVoice(tester);
      final permission = Completer<int>();
      var requests = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
          requests++;
          return permission.future;
        },
      );
      final router = await _mount(
        tester,
        database: database,
        gateway: _HeldGateway(),
      );
      final camera = find.byKey(const Key('ai-coach-food-image-button'));
      await tester.tap(camera);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-camera')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(camera);
      await tester.pump();
      expect(requests, 1);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      permission.complete(1);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
  testWidgets('voice opening is single-flight and cannot start after leaving', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final available = Completer<bool>();
    final calls = _mockCoachVoice(tester, available: available.future);
    final router = await _mount(
      tester,
      database: database,
      gateway: _HeldGateway(),
    );
    await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
    await _acceptCoachVoiceDisclosure(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(systemSpeechDisclosureAllowKey), findsNothing);
    expect(calls['bil/speech:available'], 1);
    router.go('/dashboard');
    await tester.pumpAndSettle();
    available.complete(true);
    await tester.pumpAndSettle();
    expect(calls['bil/speech:listen'] ?? 0, 0);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('unavailable recognizer leaves the composer usable', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    _mockCoachVoice(tester, available: Future.value(false));
    await _mount(tester, database: database, gateway: _HeldGateway());
    await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
    await _acceptCoachVoiceDisclosure(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
          .controller!
          .text,
      '',
    );
    expect(find.textContaining('Voice input is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  for (final leave in [false, true]) {
    testWidgets(
      'voice reply completion respects next draft and lifecycle leave=$leave',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        _mockCoachVoice(tester);
        final gateway = _HeldGateway();
        final router = await _mount(
          tester,
          database: database,
          gateway: gateway,
        );
        await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
        await _acceptCoachVoiceDisclosure(tester);
        await tester.pump(const Duration(milliseconds: 200));
        await _emitCoachVoice(tester);
        await _waitForCoachCall(tester, gateway);
        if (leave) {
          router.go('/dashboard');
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(
            find.byKey(const Key('ai-coach-question-field')),
            'My next typed question',
          );
        }
        gateway.finish();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!leave) {
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const Key('ai-coach-question-field')),
                )
                .controller!
                .text,
            'My next typed question',
          );
        }
        await _unmount(tester);
      },
    );
  }

  testWidgets(
    'backgrounding a live call prevents reply speech and microphone restart',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final calls = _mockCoachVoice(tester);
      final gateway = _HeldGateway();
      await _mount(tester, database: database, gateway: gateway);
      await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
      await _acceptCoachVoiceDisclosure(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await _emitCoachVoice(tester);
      await _waitForCoachCall(tester, gateway);
      final spokenBefore = calls['bil/tts:speak'] ?? 0;
      final listenedBefore = calls['bil/speech:listen'] ?? 0;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.paused'),
        (_) {},
      );
      await tester.pump();
      gateway.finish();
      await tester.pumpAndSettle();
      expect(calls['bil/tts:speak'] ?? 0, spokenBefore);
      expect(calls['bil/speech:listen'] ?? 0, listenedBefore);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.resumed'),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(calls['bil/speech:listen'] ?? 0, listenedBefore);
      expect(find.byTooltip('End live call'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
}
