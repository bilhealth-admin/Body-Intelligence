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

  /// Optional fallback language for recognizers that cannot switch languages.
  ///
  /// Leave this null for multilingual capture so the operating-system default
  /// is not replaced by the app interface language.
  final String? localeId;
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
  const SpeechRecognitionResult(
    this.recognizedWords, {
    this.isFinal = false,
    this.localeId,
  });

  final String recognizedWords;
  final bool isFinal;
  final String? localeId;
}

class SpeechRecognitionError {
  const SpeechRecognitionError(this.errorMsg);

  final String errorMsg;
}

/// Thin, first-party bridge to the operating-system speech recognizer.
///
/// BIL owns this boundary so Android can use AGP 9 built-in Kotlin without a
/// legacy Kotlin Gradle Plugin. This class exposes partial text only; the
/// owning screen decides when an intentional voice capture is submitted.
class SpeechToText {
  SpeechToText({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('bil/speech'),
      _events = events ?? const EventChannel('bil/speech/events');

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<Object?>? _subscription;
  void Function(SpeechRecognitionError error)? _onError;
  void Function(SpeechRecognitionResult result)? _onResult;
  SpeechListenOptions? _lastListenOptions;
  Timer? _transientRetry;
  var _transientRetryCount = 0;
  var _cancelRequested = false;
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
    _lastListenOptions = listenOptions;
    _transientRetryCount = 0;
    _cancelRequested = false;
    _transientRetry?.cancel();
    _transientRetry = null;
    await _startNativeListening(listenOptions);
  }

  Future<void> _startNativeListening(SpeechListenOptions listenOptions) async {
    _isListening = true;
    try {
      await _methods.invokeMethod<void>('listen', <String, Object?>{
        'localeId': listenOptions.localeId,
        'listenForMs': listenOptions.listenFor.inMilliseconds,
        'pauseForMs': listenOptions.pauseFor.inMilliseconds,
        'partialResults': listenOptions.partialResults,
        'cancelOnError': listenOptions.cancelOnError,
        'autoDetectLanguage': listenOptions.autoDetectLanguage,
        'allowedLocaleIds': listenOptions.allowedLocaleIds,
      });
    } on Object catch (error) {
      _isListening = false;
      final code = _platformErrorCode(error);
      if (_shouldRetryTransiently(code)) {
        _transientRetryCount += 1;
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!_cancelRequested && identical(_lastListenOptions, listenOptions)) {
          return _startNativeListening(listenOptions);
        }
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    _cancelRequested = true;
    _lastListenOptions = null;
    _transientRetry?.cancel();
    _transientRetry = null;
    await _methods.invokeMethod<void>('stop');
    _isListening = false;
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    _lastListenOptions = null;
    _transientRetry?.cancel();
    _transientRetry = null;
    await _methods.invokeMethod<void>('cancel');
    _isListening = false;
  }

  Future<void> dispose() async {
    try {
      await cancel();
    } on Object {
      // Native speech may already be unavailable while the owning page closes.
    }
    await _subscription?.cancel();
    _subscription = null;
    _onError = null;
    _onResult = null;
    _lastListenOptions = null;
    _transientRetry?.cancel();
    _transientRetry = null;
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
            localeId: event['localeId']?.toString(),
          ),
        );
        if (event['final'] == true) {
          _isListening = false;
          _lastListenOptions = null;
          _transientRetry?.cancel();
          _transientRetry = null;
        }
      case 'error':
        _isListening = false;
        final code = event['code']?.toString() ?? 'unavailable';
        if (_shouldRetryTransiently(code)) {
          _scheduleTransientRetry();
        } else {
          _lastListenOptions = null;
          _onError?.call(SpeechRecognitionError(code));
        }
      case 'status':
        if (event['listening'] is bool) {
          _isListening = event['listening']! as bool;
        }
    }
  }

  bool _shouldRetryTransiently(String code) =>
      !_cancelRequested &&
      _lastListenOptions != null &&
      _transientRetryCount < 1 &&
      const <String>{
        'recognizer_error_5',
        'speech_recognizer_busy',
        'speech_start_failed',
        'audio_input_unavailable',
        'audio_session_unavailable',
      }.contains(code);

  String _platformErrorCode(Object error) =>
      error is PlatformException ? error.code : 'speech_start_failed';

  void _scheduleTransientRetry() {
    _transientRetryCount += 1;
    _transientRetry?.cancel();
    _transientRetry = Timer(const Duration(milliseconds: 450), () async {
      _transientRetry = null;
      final options = _lastListenOptions;
      if (_cancelRequested || options == null) return;
      try {
        await _startNativeListening(options);
      } on Object catch (error) {
        _lastListenOptions = null;
        _onError?.call(SpeechRecognitionError(_platformErrorCode(error)));
      }
    });
  }
}
