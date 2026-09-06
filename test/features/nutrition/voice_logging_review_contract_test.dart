import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice logging requires editable review and never writes a meal', () {
    final service = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();
    final localizedCopy = File(
      'lib/app/localization/runtime_copy_meal_voice.dart',
    ).readAsStringSync();
    expect(service, contains("Key('editable-voice-food-candidate')"));
    expect(service, contains("Key('accept-reviewed-voice-candidate')"));
    expect(service, contains('MealVoiceRuntimeCopy.resolve'));
    expect(localizedCopy, contains('Nothing is logged automatically.'));
    expect(service, isNot(contains('mealRepositoryProvider')));
    expect(service, isNot(contains('.addMeal(')));
  });

  test(
    'native bridges expose explicit permission timeout and no-match paths',
    () {
      final android = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSpeechBridge.kt',
      ).readAsStringSync();
      final ios = File('ios/Runner/BILSpeechBridge.swift').readAsStringSync();
      expect(android, contains('microphone_permission_denied'));
      expect(android, contains('speech_timeout'));
      expect(android, contains('speech_no_match'));
      expect(android, contains('speech_start_failed'));
      expect(android, contains('sessionActive = false'));
      expect(
        android,
        contains('finishPendingListen("speech_start_cancelled")'),
      );
      expect(
        RegExp(
          r'"stop"\s*->\s*\{\s*finishPendingListen\('
          r'"speech_start_cancelled"\)',
        ).hasMatch(android),
        isTrue,
      );
      expect(
        RegExp(
          r'"cancel"\s*->\s*\{\s*finishPendingListen\('
          r'"speech_start_cancelled"\)',
        ).hasMatch(android),
        isTrue,
      );
      expect(android, contains('val pending = pendingListen ?: return'));
      expect(android, contains('pendingListen = null'));
      expect(ios, contains('speech_permission_denied'));
      expect(ios, contains('microphone_permission_denied'));
      expect(ios, contains('speech_no_match'));
      expect(ios, contains('inputTapInstalled'));
      expect(ios, contains('audio_input_unavailable'));
      expect(ios, contains('setActive(true'));
    },
  );

  testWidgets('each meal voice capture releases its speech subscription', (
    tester,
  ) async {
    final speech = _UnavailableSpeechToText();
    final service = MealVoiceInputService(
      speech,
      permissionGate: (_) async => true,
    );
    late BuildContext captureContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captureContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final capture = service.capture(
      context: captureContext,
      localeId: 'en',
      arabic: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Voice input unavailable'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(await capture, isNull);
    expect(speech.disposeCalls, 1);
  });
}

final class _UnavailableSpeechToText extends SpeechToText {
  int disposeCalls = 0;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
  }) async => false;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
