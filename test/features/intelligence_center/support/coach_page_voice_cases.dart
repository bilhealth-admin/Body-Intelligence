part of '../coach_page_lifecycle_regression_test.dart';

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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls['bil/speech:available'], 1);
    router.go('/dashboard');
    await tester.pumpAndSettle();
    available.complete(true);
    await tester.pumpAndSettle();
    expect(calls['bil/speech:listen'] ?? 0, 0);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('unavailable recognizer preserves the typed draft', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    _mockCoachVoice(tester, available: Future.value(false));
    await _mount(tester, database: database, gateway: _HeldGateway());
    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'Keep this draft',
    );
    await tester.tap(find.byKey(const Key('ai-coach-hero-start')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
          .controller!
          .text,
      'Keep this draft',
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
      await tester.tap(find.byKey(const Key('ai-coach-hero-start')));
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
      expect(find.byTooltip('Resume live call'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
}
