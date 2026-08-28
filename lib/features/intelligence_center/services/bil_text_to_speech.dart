import 'package:flutter/services.dart';

enum BilCoachVoiceGender { male, female, system }

BilCoachVoiceGender coachVoiceGenderForProfile(String? profileGender) {
  return switch (profileGender?.trim().toLowerCase()) {
    'male' => BilCoachVoiceGender.male,
    'female' => BilCoachVoiceGender.female,
    _ => BilCoachVoiceGender.system,
  };
}

class BilTextToSpeech {
  const BilTextToSpeech();

  static const _channel = MethodChannel('bil/tts');

  Future<void> speak(
    String text,
    String locale, {
    BilCoachVoiceGender voiceGender = BilCoachVoiceGender.system,
  }) async {
    PlatformException? localeFailure;
    for (final candidate in _voiceLocaleCandidates(locale)) {
      try {
        await _channel.invokeMethod<void>('speak', <String, Object?>{
          'text': text,
          'locale': candidate,
          'voiceGender': voiceGender.name,
        });
        return;
      } on PlatformException catch (error) {
        if (error.code != 'tts_locale_unavailable') rethrow;
        localeFailure = error;
      }
    }
    throw localeFailure ?? PlatformException(code: 'tts_locale_unavailable');
  }

  Future<void> stop() => _channel.invokeMethod<void>('stop');
}

/// Android voice packs frequently expose a regional voice but reject the
/// otherwise valid base BCP-47 language. Try the exact detected language first
/// and then a neutral regional voice without ever changing the reply language.
List<String> _voiceLocaleCandidates(String raw) {
  final normalized = raw.trim().replaceAll('_', '-');
  final language = normalized.split('-').first.toLowerCase();
  const regionalFallback = <String, String>{
    'ar': 'ar-SA',
    'bn': 'bn-BD',
    'de': 'de-DE',
    'en': 'en-US',
    'es': 'es-ES',
    'fa': 'fa-IR',
    'fr': 'fr-FR',
    'hi': 'hi-IN',
    'id': 'id-ID',
    'it': 'it-IT',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'ms': 'ms-MY',
    'nl': 'nl-NL',
    'pl': 'pl-PL',
    'pt': 'pt-BR',
    'ru': 'ru-RU',
    'th': 'th-TH',
    'tr': 'tr-TR',
    'uk': 'uk-UA',
    'ur': 'ur-PK',
    'vi': 'vi-VN',
    'zh': 'zh-CN',
  };
  final candidates = <String>[
    if (normalized.isNotEmpty) normalized,
    ?regionalFallback[language],
    if (language == 'ar') 'ar-EG',
    if (language == 'zh' && normalized.toLowerCase() == 'zh-hant') 'zh-TW',
    if (language == 'zh' && normalized.toLowerCase() == 'zh-hans') 'zh-CN',
  ];
  return candidates.where((value) => value.isNotEmpty).toSet().toList();
}
