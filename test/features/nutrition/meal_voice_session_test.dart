import 'dart:async';
import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_candidate.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledMealSpeech extends SpeechToText {
  Completer<bool>? available;
  void Function(SpeechRecognitionResult)? result;
  void Function(SpeechRecognitionError)? error;
  int listens = 0, cancels = 0, disposals = 0;
  bool listening = false;
  @override
  bool get isListening => listening;
  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
  }) async {
    error = onError;
    return available == null ? true : await available!.future;
  }

  @override
  Future<List<LocaleName>> locales() async => [
    const LocaleName('en-US'),
    const LocaleName('ar-SA'),
  ];
  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult) onResult,
    required SpeechListenOptions listenOptions,
  }) async {
    listens++;
    result = onResult;
    listening = true;
    onListeningChanged?.call(true);
  }

  void emit(String text, {bool finalResult = false}) {
    result?.call(SpeechRecognitionResult(text, isFinal: finalResult));
    if (finalResult) {
      listening = false;
      onListeningChanged?.call(false);
    }
  }

  @override
  Future<void> cancel() async {
    cancels++;
    listening = false;
    onListeningChanged?.call(false);
  }

  @override
  Future<void> stop() => cancel();
  @override
  Future<void> dispose() async {
    disposals++;
    await cancel();
  }
}

void main() {
  MealVoiceSession session(ControlledMealSpeech speech) =>
      MealVoiceSession(speech: speech, appLocale: 'ar', deviceLocale: 'ar-SA');
  testWidgets(
    'silence timeout stops the microphone; retry ignores an earlier final result',
    (tester) async {
      final speech = ControlledMealSpeech();
      final capture = session(speech);
      await capture.start();
      final oldResult = speech.result!;
      await tester.pump(const Duration(seconds: 31));
      expect(capture.phase, MealVoicePhase.failure);
      expect(capture.failure, MealVoiceFailure.timeout);
      expect(capture.canAccept, isFalse);
      expect(speech.listening, isFalse);
      await capture.start();
      oldResult(const SpeechRecognitionResult('retired words', isFinal: true));
      expect(capture.editor.text, isEmpty);
      speech.emit('new reviewed phrase', finalResult: true);
      expect(capture.editor.text, 'new reviewed phrase');
      expect(capture.canAccept, isTrue);
      await capture.close();
      capture.dispose();
    },
  );
  test(
    'delayed initialization is visible; cancellation cannot start a late microphone',
    () async {
      final speech = ControlledMealSpeech()..available = Completer<bool>();
      final capture = session(speech);
      final start = capture.start();
      await Future<void>.delayed(Duration.zero);
      expect(capture.phase, MealVoicePhase.initializing);
      expect(capture.canAccept, isFalse);
      await capture.close();
      speech.available!.complete(true);
      await start;
      expect(speech.listens, 0);
      expect(speech.listening, isFalse);
      capture.dispose();
    },
  );
  test(
    'partial final manual edit and late speech retain only reviewed text',
    () async {
      final speech = ControlledMealSpeech();
      final capture = session(speech);
      await capture.start();
      expect(capture.phase, MealVoicePhase.listening);
      speech.emit('فول');
      expect(capture.editor.text, 'فول');
      expect(capture.canAccept, isFalse);
      capture.beginManualEdit();
      capture.editor.text = 'فول مدمس 80 غرامًا';
      capture.textChanged();
      speech.emit('نص متأخر', finalResult: true);
      expect(capture.editor.text, 'فول مدمس 80 غرامًا');
      expect(capture.phase, MealVoicePhase.review);
      expect(capture.canAccept, isTrue);
      expect(speech.listening, isFalse);
      await capture.close();
      capture.dispose();
    },
  );
  test(
    'native failure and silence allow manual review and explicit retry',
    () async {
      final speech = ControlledMealSpeech();
      final capture = session(speech);
      await capture.start();
      speech.error!(
        const SpeechRecognitionError('microphone_permission_denied'),
      );
      expect(capture.failure, MealVoiceFailure.permissionDenied);
      expect(capture.phase, MealVoicePhase.failure);
      await capture.start();
      expect(speech.listens, 2);
      speech.emit('', finalResult: true);
      expect(capture.failure, MealVoiceFailure.noMatch);
      capture.editor.text = 'rice';
      capture.textChanged();
      expect(capture.failure, isNull);
      expect(capture.canAccept, isTrue);
      await capture.close();
      capture.dispose();
    },
  );
  test(
    'double start keeps one session; stopped and closed states have no live microphone',
    () async {
      final speech = ControlledMealSpeech()..available = Completer<bool>();
      final capture = session(speech);
      final start = capture.start();
      await capture.start();
      speech.available!.complete(true);
      await start;
      expect(speech.listens, 1);
      speech.emit('chicken', finalResult: true);
      expect(capture.phase, MealVoicePhase.review);
      await capture.stop();
      expect(speech.listening, isFalse);
      expect(capture.canAccept, isTrue);
      await capture.close();
      speech.emit('late');
      expect(capture.editor.text, 'chicken');
      capture.dispose();
    },
  );
}
