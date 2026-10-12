import 'dart:async';
import 'package:flutter/widgets.dart';
import 'bil_speech_to_text.dart';
import 'meal_voice_candidate.dart';

enum MealVoicePhase { initializing, listening, stopped, review, failure }

/// A single user initiated voice window across food, posts and weight.
/// A rejected second capture never cancels or disposes the current owner.
abstract final class VoiceCaptureLease {
  static Object? _owner;
  static bool acquire(Object owner) {
    if (_owner != null) return false;
    _owner = owner;
    return true;
  }

  static void release(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}

/// One reviewed phrase, without any food writes or cloud AI calls.
class MealVoiceSession extends ChangeNotifier {
  MealVoiceSession({
    required this.speech,
    required this.appLocale,
    required this.deviceLocale,
    this.optionsForLocales,
    this.reviewTextForResult,
  });
  final SpeechToText speech;
  final String appLocale, deviceLocale;
  final SpeechListenOptions Function(List<LocaleName> locales)?
  optionsForLocales;
  final String Function(SpeechRecognitionResult result)? reviewTextForResult;
  final editor = TextEditingController();
  MealVoicePhase phase = MealVoicePhase.initializing;
  MealVoiceFailure? failure;
  String? selectedLocale;
  bool _closed = false, _starting = false, _edited = false;
  int _generation = 0;
  Timer? _timeout;
  bool get canAccept =>
      !_closed &&
      editor.text.trim().isNotEmpty &&
      phase != MealVoicePhase.initializing &&
      phase != MealVoicePhase.listening;
  bool get starting => _starting;

  void _publish() {
    if (!_closed) notifyListeners();
  }

  bool _current(int generation) => !_closed && generation == _generation;

  Future<void> start() async {
    if (_closed || _starting) return;
    _starting = true;
    final generation = ++_generation;
    _timeout?.cancel();
    _edited = false;
    failure = null;
    phase = MealVoicePhase.initializing;
    _publish();
    try {
      await _stopRecognizer();
      if (!_current(generation)) return;
      {
        final available = await speech.initialize(
          onError: (error) {
            if (!_current(generation) || _edited) return;
            failure = classifyMealVoiceFailure(error.errorMsg);
            phase = MealVoicePhase.failure;
            _timeout?.cancel();
            unawaited(_stopRecognizer());
            _publish();
          },
        );
        if (!_current(generation)) return;
        if (!available) throw StateError('recognizer_unavailable');
      }
      // Rebind each attempt: an old result/status must not mutate a retry.
      speech.onListeningChanged = (listening) {
        if (!_current(generation) ||
            _edited ||
            phase == MealVoicePhase.failure) {
          return;
        }
        phase = listening
            ? MealVoicePhase.listening
            : editor.text.trim().isEmpty
            ? MealVoicePhase.stopped
            : MealVoicePhase.review;
        _publish();
      };
      final locales = await speech.locales();
      if (!_current(generation)) return;
      selectedLocale = MealVoiceLocaleResolver.resolve(
        appLanguage: appLocale,
        deviceLocale: deviceLocale,
        availableLocales: locales.map((item) => item.localeId),
      );
      if (selectedLocale == null && optionsForLocales == null) {
        failure = MealVoiceFailure.localeUnavailable;
        phase = MealVoicePhase.failure;
        _publish();
        return;
      }
      var finalReceived = false;
      final options =
          optionsForLocales?.call(locales) ??
          SpeechListenOptions(
            localeId: selectedLocale,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 4),
            listenMode: ListenMode.confirmation,
            partialResults: true,
            cancelOnError: true,
          );
      selectedLocale = options.localeId ?? appLocale;
      await speech.listen(
        onResult: (result) {
          if (!_current(generation) || _edited) return;
          final text =
              reviewTextForResult?.call(result) ??
              result.recognizedWords.trim();
          editor.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          finalReceived = result.isFinal;
          if (result.isFinal) {
            _timeout?.cancel();
            failure = text.isEmpty ? MealVoiceFailure.noMatch : null;
            phase = text.isEmpty
                ? MealVoicePhase.failure
                : MealVoicePhase.review;
          }
          _publish();
        },
        listenOptions: options,
      );
      if (!_current(generation)) {
        await speech.cancel();
        return;
      }
      if (phase != MealVoicePhase.failure && !finalReceived) {
        phase = speech.isListening
            ? MealVoicePhase.listening
            : MealVoicePhase.stopped;
        _publish();
      }
      if (phase == MealVoicePhase.listening ||
          phase == MealVoicePhase.initializing) {
        _timeout = Timer(options.listenFor + const Duration(seconds: 1), () {
          if (!_current(generation)) return;
          if (editor.text.trim().isEmpty) {
            failure = MealVoiceFailure.timeout;
            phase = MealVoicePhase.failure;
          } else {
            phase = MealVoicePhase.review;
          }
          unawaited(_stopRecognizer());
          _publish();
        });
      }
    } on Object catch (error) {
      if (!_current(generation)) return;
      failure = classifyMealVoiceFailure(error.toString());
      phase = MealVoicePhase.failure;
      await _stopRecognizer();
      _publish();
    } finally {
      _starting = false;
      _publish();
    }
  }

  void beginManualEdit() {
    if (_closed || _edited) return;
    _edited = true;
    _generation++;
    failure = null;
    phase = MealVoicePhase.review;
    _timeout?.cancel();
    unawaited(_stopRecognizer());
    _publish();
  }

  void textChanged() {
    beginManualEdit();
    _publish();
  }

  Future<void> stop() async {
    if (_closed) return;
    _generation++;
    _timeout?.cancel();
    phase = editor.text.trim().isEmpty
        ? MealVoicePhase.stopped
        : MealVoicePhase.review;
    await _stopRecognizer();
    _publish();
  }

  Future<void> _stopRecognizer() async {
    try {
      await speech.cancel();
    } on Object {
      /* Native teardown can race with OS shutdown. */
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _timeout?.cancel();
    speech.onListeningChanged = null;
    await _stopRecognizer();
  }

  @override
  void dispose() {
    unawaited(close());
    editor.dispose();
    super.dispose();
  }
}
