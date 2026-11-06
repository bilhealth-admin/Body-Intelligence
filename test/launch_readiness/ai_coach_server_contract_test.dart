import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _numericContract(String source, String pattern, String name) {
  final matches = RegExp(pattern).allMatches(source).toList();
  expect(
    matches,
    hasLength(1),
    reason: 'One live $name must define the budget.',
  );
  return int.parse(matches.single.group(1)!.replaceAll('_', ''));
}

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
    expect(source, contains('gemini-3.8-flash'));
    expect(source, contains('gemini-3.7-flash'));
    expect(
      source,
      isNot(contains('env("BIL_GEMINI_VISION_MODEL") || "gemini-2.5-flash"')),
    );
    expect(source, contains('BIL_GEMINI_COST_RATES_JSON'));
    expect(source, contains('attempt <= 1'));
    expect(
      source,
      matches(
        RegExp(
          r'AbortSignal\.timeout\(\s*Math\.max\(1, Math\.min\(geminiAttemptTimeoutMs, attemptTimeoutMs\)\),?\s*\)',
        ),
      ),
    );
    expect(source, contains('maxOutputTokens'));
    expect(source, contains('responseMimeType: "application/json"'));
    expect(source, contains('responseSchema: coachResponseSchema('));
    expect(source, contains('citationCatalogVersion,\n            )'));
    expect(source, contains('function coachResponseSchema('));
    expect(source, contains('extractModelText('));
    expect(
      source,
      contains('content?.parts as Array<Record<string, unknown>> | undefined'),
    );
    expect(source, contains('parseModelJson('));
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

  test('AI Coach live provider caps fit the shared window and client deadline', () {
    final source = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final primary = _numericContract(
      source,
      r'export\s+const\s+geminiAttemptTimeoutMs\s*=\s*([0-9_]+)\s*;',
      'primary provider cap',
    );
    final later = _numericContract(
      source,
      r'export\s+const\s+geminiLaterAttemptTimeoutMs\s*=\s*([0-9_]+)\s*;',
      'later provider cap',
    );
    final window = _numericContract(
      source,
      r'const\s+remaining\s*=\s*([0-9_]+)\s*-\s*\(attemptStarted\s*-\s*started\)',
      'absolute request window',
    );
    final repairWindow = _numericContract(
      source,
      r'const\s+budget\s*=\s*Math\.min\(geminiAttemptTimeoutMs,\s*([0-9_]+)\s*-\s*\(now\(\)\s*-\s*started\)\)',
      'citation repair window',
    );
    final clientSeconds = _numericContract(
      gateway,
      r'\.invokeCoach\(<String,\s*Object\?>\{[\s\S]*?\.timeout\(\s*const\s+Duration\(seconds:\s*([0-9_]+)\)\s*\)',
      'remote client timeout',
    );
    final maximumCalls = _numericContract(
      source,
      r'providerAttempts\s*>=\s*([0-9_]+)',
      'provider call maximum',
    );
    expect(later, greaterThan(0));
    expect(primary, greaterThan(later));
    expect(primary + later, lessThanOrEqualTo(window));
    expect(repairWindow, window);
    expect(window, lessThan(clientSeconds * 1000));
    expect(
      maximumCalls,
      3,
      reason: 'Primary, independent fallback and repair.',
    );
    expect(
      source,
      matches(
        RegExp(
          r'const\s+cap\s*=\s*providerAttempts\s*===\s*0\s*\?\s*geminiAttemptTimeoutMs\s*:\s*geminiLaterAttemptTimeoutMs',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'const\s+budget\s*=\s*Math\.min\(args\[8\]\s*\?\?\s*cap,\s*cap,\s*remaining\)',
        ),
      ),
    );
    // These source/caller invariants supplement the executed Deno boundaries,
    // not a replacement for them. The required exact-SHA cloud-source CI runs
    // provider_deadline_test.ts (real logical transport, late-answer rejection,
    // independent fallback and one refund) plus coach_reasoning_test.ts
    // (read LOW, analysis MEDIUM, short planning HIGH and alias independence).
    // The final release gate requires that workflow on the same source SHA.
    final reasoning = File(
      'supabase/functions/ai-coach/coach_reasoning.ts',
    ).readAsStringSync();
    expect(source, contains('coachReasoningFor(messages)'));
    expect(source, contains('reasoning.level'));
    expect(source, contains('independentGeminiFallback('));
    expect(
      reasoning,
      contains('canonicalGeminiModel(candidate) !== canonical'),
    );
    expect(
      source,
      contains('thinkingLevel === "HIGH" ? "MEDIUM" : thinkingLevel'),
    );
  });

  test('AI Coach voice capture is not locked to the app locale', () {
    final page =
        [
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
              'intelligence_conversation_viewport.dart',
              'intelligence_center_voice_widgets.dart',
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
    expect(
      page,
      contains(
        'autoDetectLanguage: defaultTargetPlatform != TargetPlatform.iOS',
      ),
    );
    expect(page, contains('localeId: coachIosSpeechLocaleId('));
    expect(page, isNot(contains('previousUserMessage')));
    // Native capture now requires the owned media request and a guarded
    // draft writer; old one-argument source text was no longer the contract.
    expect(
      page,
      matches(
        RegExp(
          r'if\s*\(await _startNativeVoiceCapture\('
          r'\s*request,\s*generation,'
          r'\s*writeTranscript:\s*writeTranscript,'
          r'\s*hasUserEdited:\s*hasUserEdited,'
          r'\s*\)\s*\)\s*\{\s*return;',
        ),
      ),
    );
    expect(page, isNot(contains('_startCloudVoiceCapture')));
    expect(page, isNot(contains('CoachVoicePayload')));
    expect(page, contains('pendingVoiceTranscript = transcript'));
    expect(page, contains('question.value = TextEditingValue('));
    expect(page, contains('Duration(milliseconds: 3500)'));
    expect(page, contains('_LiveVoiceTranscript'));
    expect(page, contains("part 'intelligence_conversation_viewport.dart';"));
    expect(page, contains("part 'intelligence_center_voice_widgets.dart';"));
    expect(page, contains('await speech.stop();'));
    expect(page, contains('_speakCoachText(spokenReply, spokenLocale)'));
    expect(page, contains('speechPlan != CoachSpeechPlan.directAnswer'));
    expect(page, contains('allowedLocaleIds: speechLocaleAllowList'));
    expect(page, contains('detectedLanguageTag: detectedLanguageTag'));
    expect(bridge, contains('onLanguageDetection'));
    expect(bridge, contains('SpeechRecognizer.DETECTED_LANGUAGE'));
    expect(bridge, contains('EXTRA_ENABLE_LANGUAGE_SWITCH'));
    expect(bridge, contains('LANGUAGE_SWITCH_QUICK_RESPONSE'));
    expect(bridge, contains('EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES'));
    expect(bridge, isNot(contains('EXTRA_PREFER_OFFLINE')));
    expect(bridge, contains('if (recognizer == null)'));
    expect(bridge, contains('val wasActive = sessionActive'));
    expect(bridge, contains('if (wasActive)'));
    expect(bridge, contains('recognizer?.stopListening()'));
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
