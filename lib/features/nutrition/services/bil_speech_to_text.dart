import 'dart:async';

import 'package:flutter/services.dart';

enum ListenMode { confirmation }

class SpeechListenOptions {
  const SpeechListenOptions({
    required this.localeId,
    required this.listenFor,
    required this.pauseFor,
    required this.listenMode,
    required this.partialResults,
    required this.cancelOnError,
    this.autoDetectLanguage = false,
    this.allowedLocaleIds = const <String>[],
  });

  final String localeId;
  final Duration listenFor;
  final Duration pauseFor;
  final ListenMode listenMode;
  final bool partialResults;
  final bool cancelOnError;
  final bool autoDetectLanguage;
  final List<String> allowedLocaleIds;
}

class LocaleName {
  const LocaleName(this.localeId);

  final String localeId;
}

class SpeechRecognitionResult {
  const SpeechRecognitionResult(this.recognizedWords, {this.isFinal = false});

  final String recognizedWords;
  final bool isFinal;
}

class SpeechRecognitionError {
  const SpeechRecognitionError(this.errorMsg);

  final String errorMsg;
}

/// Thin, first-party bridge to the operating-system speech recognizer.
///
/// BIL owns this boundary so Android can use AGP 9 built-in Kotlin without a
/// legacy Kotlin Gradle Plugin. Audio never leaves the OS recognizer through
/// this class and BIL persists only text explicitly accepted by the user.
class SpeechToText {
  SpeechToText({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('bil/speech'),
      _events = events ?? const EventChannel('bil/speech/events');

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<Object?>? _subscription;
  void Function(SpeechRecognitionError error)? _onError;
  void Function(SpeechRecognitionResult result)? _onResult;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _onError = onError;
    await _subscription?.cancel();
    _subscription = _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        _isListening = false;
        _onError?.call(SpeechRecognitionError(error.toString()));
      },
    );
    return await _methods.invokeMethod<bool>('available') ?? false;
  }

  Future<List<LocaleName>> locales() async {
    final values = await _methods.invokeListMethod<String>('locales');
    return (values ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .map(LocaleName.new)
        .toList(growable: false);
  }

  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    required SpeechListenOptions listenOptions,
  }) async {
    _onResult = onResult;
    await _methods.invokeMethod<void>('listen', <String, Object>{
      'localeId': listenOptions.localeId,
      'listenForMs': listenOptions.listenFor.inMilliseconds,
      'pauseForMs': listenOptions.pauseFor.inMilliseconds,
      'partialResults': listenOptions.partialResults,
      'cancelOnError': listenOptions.cancelOnError,
      'autoDetectLanguage': listenOptions.autoDetectLanguage,
      'allowedLocaleIds': listenOptions.allowedLocaleIds,
    });
    _isListening = true;
  }

  Future<void> stop() async {
    await _methods.invokeMethod<void>('stop');
    _isListening = false;
  }

  Future<void> cancel() async {
    await _methods.invokeMethod<void>('cancel');
    _isListening = false;
  }

  void _handleEvent(Object? raw) {
    if (raw is! Map) return;
    final event = Map<String, Object?>.from(raw);
    switch (event['type']) {
      case 'result':
        _onResult?.call(
          SpeechRecognitionResult(
            event['words']?.toString() ?? '',
            isFinal: event['final'] == true,
          ),
        );
        if (event['final'] == true) _isListening = false;
      case 'error':
        _isListening = false;
        _onError?.call(
          SpeechRecognitionError(event['code']?.toString() ?? 'unavailable'),
        );
      case 'status':
        if (event['listening'] is bool) {
          _isListening = event['listening']! as bool;
        }
    }
  }
}
