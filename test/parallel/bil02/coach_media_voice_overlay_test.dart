// Integration-proposal dependency: run on the BIL-02 validation overlay.
// Exercise the existing public live-call entry and its editable/manual handoff
// using the real Coach page, native-channel fakes and an isolated Drift store.
// There is no public composer-dictation entry on the declared BASE; these tests
// do not claim to expose one or to exercise a real recognizer/provider.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/intelligence_center/coach_review_actions_regression_test.dart'
    as base;

final class _VoiceFixture {
  _VoiceFixture(this.database, this.gateway, this.router, this.nativeCalls);

  final AppDatabase database;
  final base.Gateway gateway;
  final GoRouter router;
  final Map<String, int> nativeCalls;

  void completeReply() {
    final pending = gateway.pending!;
    if (!pending.isCompleted) {
      pending.complete(
        LocalModelResult.answer(
          LocalModelAnswer(text: 'A synthetic local reply.', action: null),
        ),
      );
    }
  }
}

Finder get _field => find.byKey(const Key('ai-coach-question-field'));
Finder get _send => find.byKey(const Key('ai-coach-send-button'));
String _draft(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

Future<void> _drain(
  WidgetTester tester, {
  Duration elapsed = const Duration(milliseconds: 20),
}) async {
  // Drift work must progress outside Flutter's fake clock. A bounded pump also
  // avoids waiting forever for the deliberate listening/thinking animations.
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pump(elapsed);
}

Future<_VoiceFixture> _mount(WidgetTester tester) async {
  final database = (await tester.runAsync(() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    return database;
  }))!;
  addTearDown(() async {
    await tester.runAsync(database.close);
  });

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
      if (call.method == 'available') return true;
      if (call.method == 'locales') return ['en-US', 'ar-EG'];
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  final gateway = base.Gateway()..pending = Completer<LocalModelResult>();
  final router = await base.mount(tester, database, gateway: gateway);
  final fixture = _VoiceFixture(database, gateway, router, calls);
  // Register after mount so the page is disposed while its native cleanup
  // channels and database still exist, including when an assertion fails.
  addTearDown(() async {
    await base.unmount(tester);
    fixture.completeReply();
    await _drain(tester);
  });
  for (var turn = 0; turn < 40; turn++) {
    await _drain(tester);
    if (_field.evaluate().length == 1 &&
        tester.widget<TextField>(_field).enabled == true) {
      return fixture;
    }
  }
  fail('The real Coach composer did not become ready.');
}

Future<void> _startVoice(WidgetTester tester, _VoiceFixture fixture) async {
  await tester.tap(find.byKey(const Key('ai-coach-voice-button')));
  for (
    var turn = 0;
    turn < 40 && (fixture.nativeCalls['bil/speech:listen'] ?? 0) == 0;
    turn++
  ) {
    await _drain(tester);
  }
  expect(fixture.nativeCalls['bil/speech:listen'], 1);
  expect(fixture.gateway.questions, isEmpty);
}

Future<void> _emit(
  WidgetTester tester,
  String words, {
  required bool finalResult,
}) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'bil/speech/events',
    const StandardMethodCodec().encodeSuccessEnvelope({
      'type': 'result',
      'words': words,
      'final': finalResult,
      'localeId': 'en-US',
    }),
    (_) {},
  );
  await tester.pump();
}

Future<void> _expectEditable(WidgetTester tester) async {
  // Stay well inside the live-call final's 900 ms review window.
  for (var turn = 0; turn < 20 && _field.evaluate().isEmpty; turn++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(_field, findsOneWidget);
  expect(tester.widget<TextField>(_field).enabled, isTrue);
}

Future<void> _waitForQuestion(
  WidgetTester tester,
  _VoiceFixture fixture,
  String expected,
) async {
  for (var turn = 0; turn < 50 && fixture.gateway.questions.isEmpty; turn++) {
    await _drain(tester);
  }
  expect(fixture.gateway.questions, [expected]);
}

Future<List<IntelligenceMessage>> _savedUserMessages(
  WidgetTester tester,
  _VoiceFixture fixture,
) async {
  await _drain(tester);
  final raw = await tester.runAsync(
    () => PreferencesRepository(fixture.database).get(base.transcriptKey),
  );
  if (raw == null) return const [];
  return (jsonDecode(raw) as List)
      .map(
        (row) =>
            IntelligenceMessage.fromJson(Map<String, Object?>.from(row as Map)),
      )
      .where((message) => message.role == IntelligenceMessageRole.user)
      .toList(growable: false);
}

void main() {
  testWidgets(
    'real final is editable; correction cancels auto send and double Send admits one voice turn',
    (tester) async {
      final fixture = await _mount(tester);
      await _startVoice(tester, fixture);
      await _emit(tester, 'Explain consistency', finalResult: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.gateway.questions, isEmpty);

      const finalText = 'Explain consistency in everyday habits';
      await _emit(tester, finalText, finalResult: true);
      await _expectEditable(tester);
      expect(_draft(tester), finalText);
      expect(fixture.gateway.questions, isEmpty);

      await _emit(tester, 'Duplicate final must be ignored', finalResult: true);
      await _emit(tester, 'Late partial must be ignored', finalResult: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_draft(tester), finalText);
      expect(fixture.gateway.questions, isEmpty);

      const edited =
          'Explain consistency in everyday habits with one practical example';
      // BASE LocalCoachApi sends CoachIntentNormalizer.normalized to the
      // gateway. The composer and stored user message keep accepted spelling.
      const gatewayQuestion =
          'explain consistency in everyday habits with one practical example';
      await tester.enterText(_field, edited);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(_draft(tester), edited);
      expect(fixture.gateway.questions, isEmpty);
      expect(await _savedUserMessages(tester, fixture), isEmpty);

      // Two taps before the next frame exercise the actual pending handoff,
      // rather than relying only on the later disabled Sending button.
      await tester.tap(_send);
      await tester.tap(_send);
      await _waitForQuestion(tester, fixture, gatewayQuestion);
      final users = await _savedUserMessages(tester, fixture);
      expect(users, hasLength(1));
      expect(users.single.text, edited);
      expect(users.single.modality, IntelligenceMessageModality.voice);

      const nextDraft = 'Keep this next typed question';
      await tester.enterText(_field, nextDraft);
      await _emit(tester, finalText, finalResult: true);
      await _emit(tester, 'A stale partial after Send', finalResult: false);
      fixture.completeReply();
      await _drain(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_draft(tester), nextDraft);
      expect(fixture.gateway.questions, [gatewayQuestion]);
      expect(fixture.nativeCalls['bil/speech:listen'], 1);
      expect(await _savedUserMessages(tester, fixture), hasLength(1));
      expect(tester.takeException(), isNull);
      // Dispose the Riverpod/Drift listeners while the fake clock is still
      // advancing; a query-stream microtask is scheduled during disposal.
      await base.unmount(tester);
      await _drain(tester);
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'partial-only silence freezes manual review; late final cannot replace it or send',
    (tester) async {
      final fixture = await _mount(tester);
      await _startVoice(tester, fixture);
      const partial = 'Explain how everyday habits can become consistent';
      const gatewayQuestion =
          'explain how everyday habits can become consistent';
      await _emit(tester, partial, finalResult: false);
      await tester.pump(const Duration(seconds: 4));
      await _expectEditable(tester);
      expect(_draft(tester), partial);
      expect(fixture.gateway.questions, isEmpty);
      expect(fixture.nativeCalls['bil/speech:stop'], greaterThanOrEqualTo(1));

      await _emit(tester, 'A late final after silence', finalResult: true);
      await _emit(tester, 'A late changing partial', finalResult: false);
      await tester.pump(const Duration(seconds: 5));
      expect(_draft(tester), partial);
      expect(fixture.gateway.questions, isEmpty);
      expect(await _savedUserMessages(tester, fixture), isEmpty);

      await tester.tap(_send);
      await _waitForQuestion(tester, fixture, gatewayQuestion);
      final users = await _savedUserMessages(tester, fixture);
      expect(users, hasLength(1));
      expect(users.single.text, partial);
      expect(users.single.modality, IntelligenceMessageModality.voice);

      fixture.router.go('/dashboard');
      await _drain(tester);
      fixture.completeReply();
      await _emit(tester, 'A final after the route closed', finalResult: true);
      await _drain(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Dashboard'), findsOneWidget);
      expect(fixture.gateway.questions, [gatewayQuestion]);
      expect(fixture.nativeCalls['bil/speech:listen'], 1);
      expect(await _savedUserMessages(tester, fixture), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
