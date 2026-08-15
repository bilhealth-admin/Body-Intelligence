import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach text route is server metered and confirmation gated', () {
    final source = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    // The local variable may be narrowed/renamed; the audited contract is the
    // privileged RPC call itself, not that implementation detail.
    expect(source, contains(".rpc('bil_reserve_ai_usage'"));
    expect(source, contains(".rpc('bil_settle_ai_usage'"));
    expect(source, contains("p_capability: 'text'"));
    expect(source, contains("'gemini-2.5-flash-lite'"));
    expect(source, contains("'gemini-2.5-flash'"));
    expect(source, contains('BIL_GEMINI_TEXT_MODEL'));
    expect(source, contains('BIL_GEMINI_SIMPLE_MODEL'));
    expect(source, contains('BIL_GEMINI_COST_RATES_JSON'));
    expect(source, contains('attempt <= 2'));
    expect(source, contains('AbortSignal.timeout(30_000)'));
    expect(source, contains('requires_confirmation: true'));
    expect(source, contains('Never claim an action was executed'));
    expect(source, contains('responseLanguage(messages, requestedLocale)'));
    expect(source, contains('independently resolved as'));
    expect(source, contains('response_locale: locale'));
    expect(source, contains('spoken_reply'));
    expect(source, contains('one short spoken sentence'));
    expect(source, contains('Arabic (العربية)'));
    expect(source, contains('regardless of the app interface language'));
    expect(source, contains('raw.slice(-12)'));
    expect(source, contains('encoded.length > 20_000'));
    expect(source, isNot(contains('AIza')));
    expect(source, isNot(contains('service_role_key=')));
  });

  test('AI Coach voice capture is not locked to the app locale', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    final bridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSpeechBridge.kt',
    ).readAsStringSync();
    expect(page, contains('autoDetectLanguage: true'));
    expect(page, contains('previousUserMessage'));
    expect(page, contains('inputChannel == CoachInputChannel.voice'));
    expect(page, contains('BilTextToSpeech().speak(spokenReply'));
    expect(page, contains('allowedLocaleIds: BilLocalePolicy.productionTags'));
    expect(bridge, contains('EXTRA_ENABLE_LANGUAGE_DETECTION'));
    expect(bridge, contains('EXTRA_LANGUAGE_DETECTION_ALLOWED_LANGUAGES'));
    expect(bridge, contains('EXTRA_ENABLE_LANGUAGE_SWITCH'));
    expect(bridge, contains('LANGUAGE_SWITCH_QUICK_RESPONSE'));
    expect(bridge, contains('EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES'));
  });
}
