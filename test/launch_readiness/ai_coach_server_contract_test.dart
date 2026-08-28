import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach text route is server metered and confirmation gated', () {
    final source = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    // The local variable may be narrowed/renamed; the audited contract is the
    // privileged RPC call itself, not that implementation detail.
    expect(source, contains('bil_reserve_ai_usage'));
    expect(source, contains('bil_settle_ai_usage'));
    expect(source, contains('p_capability: "text"'));
    expect(source, contains('BIL_GEMINI_TEXT_MODEL'));
    expect(source, contains('gemini-3.7-flash'));
    expect(
      source,
      isNot(contains('env("BIL_GEMINI_VISION_MODEL") || "gemini-2.5-flash"')),
    );
    expect(source, contains('BIL_GEMINI_COST_RATES_JSON'));
    expect(source, contains('attempt <= 2'));
    expect(source, contains('AbortSignal.timeout(30_000)'));
    expect(source, contains('maxOutputTokens'));
    expect(source, contains('responseMimeType: "application/json"'));
    expect(
      source,
      contains('responseSchema: coachResponseSchema(requireTranscript)'),
    );
    expect(source, contains('extractModelText(parts)'));
    expect(source, contains('system,\n      4096,'));
    expect(source, contains('const providerContext = context'));
    expect(source, contains('requires_confirmation: true'));
    expect(source, contains('Never invent a measurement'));
    expect(source, contains('detectedLanguageHint = safeLanguageHint'));
    expect(source, contains('responseLanguage('));
    expect(source, contains('Response language policy:'));
    expect(source, contains('Romanized text belongs to the language'));
    expect(
      source,
      contains('The app interface locale is not language evidence'),
    );
    expect(source, contains('response_locale: locale'));
    expect(source, contains('spoken_reply'));
    expect(source, contains('one to three short conversational sentences'));
    expect(source, contains('at most 48 words and 320 characters'));
    expect(source, contains('response_id: requestId'));
    expect(source, contains('usage.thoughtsTokenCount'));
    expect(source, contains('billedOutputTokens'));
    expect(source, contains('Arabic (العربية)'));
    expect(source, contains('regardless of the interface language'));
    expect(source, contains('raw.slice(-12)'));
    expect(source, contains('encoded.length > 20_000'));
    expect(source, isNot(contains('AIza')));
    expect(source, isNot(contains('service_role_key=')));
  });

  test('AI Coach voice capture is not locked to the app locale', () {
    final page =
        [
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
              'intelligence_query_flow.dart',
            ]
            .map(
              (name) => File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync(),
            )
            .join('\n');
    final bridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSpeechBridge.kt',
    ).readAsStringSync();
    expect(page, contains('autoDetectLanguage: true'));
    expect(page, contains('localeId: null'));
    expect(page, isNot(contains('previousUserMessage')));
    expect(page, contains('if (await _startNativeVoiceCapture()) return;'));
    expect(page, isNot(contains('_startCloudVoiceCapture')));
    expect(page, isNot(contains('CoachVoicePayload')));
    expect(page, contains('pendingVoiceTranscript = transcript'));
    expect(page, contains('question.value = TextEditingValue('));
    expect(page, contains('Duration(seconds: 2)'));
    expect(page, contains('_LiveVoiceTranscript'));
    expect(page, contains('await speech.stop();'));
    expect(page, contains('_speakCoachText(spokenReply, spokenLocale)'));
    expect(page, contains('speechPlan != CoachSpeechPlan.directAnswer'));
    expect(page, contains('allowedLocaleIds: const <String>[]'));
    expect(page, contains('detectedLanguageTag: detectedLanguageTag'));
    expect(bridge, contains('onLanguageDetection'));
    expect(bridge, contains('SpeechRecognizer.DETECTED_LANGUAGE'));
    expect(bridge, contains('EXTRA_ENABLE_LANGUAGE_SWITCH'));
    expect(bridge, contains('LANGUAGE_SWITCH_QUICK_RESPONSE'));
    expect(bridge, contains('EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES'));
    expect(bridge, isNot(contains('EXTRA_PREFER_OFFLINE')));
    expect(bridge, contains('if (recognizer == null)'));
    expect(bridge, contains('if (sessionActive) recognizer?.stopListening()'));
    expect(bridge, contains('pauseForMs'));
    expect(
      bridge,
      contains('EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS'),
    );
    expect(
      bridge,
      contains('EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS'),
    );
  });
}
