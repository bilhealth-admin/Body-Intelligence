import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';

const _voicePrivacyDisclosure =
    'Your device or platform speech service may process microphone audio under its own terms. When you submit a Coach request, BIL sends Gemini only recognized text, never raw microphone audio.';

const _voicePrivacyDisclosureArabic =
    'قد تعالج خدمة التعرّف على الكلام في جهازك أو منصتك صوت الميكروفون وفق شروطها. عند إرسال طلب إلى Coach، يرسل BIL إلى Gemini النص المتعرّف عليه فقط، ولا يرسل صوت الميكروفون الخام.';

void main() {
  test('both coach microphones are text-only at the model boundary', () {
    final page =
        <String>[
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
              'intelligence_conversation_voice_transcript.dart',
              'intelligence_query_flow.dart',
            ]
            .map((name) {
              return File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync();
            })
            .join('\n');
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final contract = File(
      'lib/features/intelligence_center/services/local_model_gateway.dart',
    ).readAsStringSync();
    // The settings page still owns the part that renders this disclosure.
    final settingsPage = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ).readAsStringSync();
    expect(settingsPage, contains("part 'ai_coach_settings_body.dart';"));
    final settings =
        '$settingsPage\n${File('lib/features/intelligence_center/presentation/ai_coach_settings_body.dart').readAsStringSync()}';
    final iosSpeechBridge = File(
      'ios/Runner/BILSpeechBridge.swift',
    ).readAsStringSync();
    final androidSpeechBridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSpeechBridge.kt',
    ).readAsStringSync();
    final aiCoachServer = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();

    expect(page, contains('if (await _startNativeVoiceCapture('));
    expect(
      page,
      contains('      generation,\n      writeTranscript: writeTranscript,'),
    );
    expect(page, contains('generation != voiceCaptureGeneration'));
    expect(page, contains('coachInBackground'));
    expect(page, contains('partialResults: true'));
    expect(page, contains('pendingVoiceTranscript = transcript'));
    // The atomic bridge submits only the recognized, reviewed text snapshot.
    expect(page, contains('textOverride: submission.text'));
    expect(page, contains('inputChannel: CoachInputChannel.voice'));
    expect(page, contains('autoDetectLanguage: true'));
    expect(page, isNot(contains('_startCloudVoiceCapture')));
    expect(page, isNot(contains('cloudVoice.start')));
    expect(page, isNot(contains('base64Audio')));
    expect(contract, isNot(contains('CoachVoicePayload')));
    expect(gateway, isNot(contains("'audio':")));
    expect(settings, contains('Your platform handles speech recognition'));
    expect(
      settings,
      contains(
        'Your device or platform speech service may process microphone audio under its own terms.',
      ),
    );
    expect(settings, contains('BIL sends Gemini only recognized text'));
    expect(page, contains(_voicePrivacyDisclosure));
    expect(iosSpeechBridge, contains('SFSpeechRecognizer(locale: locale)'));
    expect(iosSpeechBridge, contains('recognizer.supportsOnDeviceRecognition'));
    expect(
      iosSpeechBridge,
      contains('request.requiresOnDeviceRecognition = true'),
    );
    expect(page, contains("errorCode == 'speech_on_device_unavailable'"));
    expect(
      page,
      contains(
        'On-device speech recognition is unavailable for this language.',
      ),
    );
    expect(aiCoachServer, contains('rejectRawVoiceAudio(body.audio)'));
    expect(aiCoachServer, contains('raw_voice_audio_not_supported'));
    expect(
      iosSpeechBridge,
      contains('SFSpeechAudioBufferRecognitionRequest()'),
    );
    expect(
      androidSpeechBridge,
      contains('SpeechRecognizer.createSpeechRecognizer(activity)'),
    );
    expect(
      androidSpeechBridge,
      contains('RecognizerIntent.ACTION_RECOGNIZE_SPEECH'),
    );
    final nativeSpeechBridges = '$iosSpeechBridge\n$androidSpeechBridge';
    expect(nativeSpeechBridges, isNot(contains('URLSession')));
    expect(nativeSpeechBridges, isNot(contains('HttpURLConnection')));
    expect(nativeSpeechBridges, isNot(contains('OkHttpClient')));
    expect(nativeSpeechBridges, isNot(contains('base64')));
    expect(settings, isNot(contains('Cloud voice processing')));
  });

  test('voice privacy disclosure is localized for every supported locale', () {
    for (final locale in RuntimeCopy.supported) {
      final value = intelligenceTextFor(
        locale,
        _voicePrivacyDisclosure,
        _voicePrivacyDisclosureArabic,
      );
      expect(value.trim(), isNotEmpty, reason: locale);
      if (locale != 'en') {
        expect(value, isNot(_voicePrivacyDisclosure), reason: locale);
      }
    }
  });
}
