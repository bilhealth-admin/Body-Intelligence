import 'package:flutter/services.dart';

class BilTextToSpeech {
  const BilTextToSpeech();

  static const _channel = MethodChannel('bil/tts');

  Future<void> speak(String text, String locale) async {
    await _channel.invokeMethod<void>('speak', <String, Object?>{
      'text': text,
      'locale': locale,
    });
  }

  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
