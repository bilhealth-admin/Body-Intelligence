import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

const _englishAiVoiceDisclosure =
    'BIL sends your questions and only the categories you select—weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate requested answers. Raw microphone audio is not sent. You can decline and keep using local features, or withdraw later in AI Coach settings.';
const _englishMealVisionDisclosure =
    'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.';

void main() {
  String authoredPrivacyBlock(String source, String suffix) {
    final marker = 'const _privacySections$suffix =';
    final start = source.indexOf(marker);
    final end = source.indexOf('\n];', start);
    expect(start, greaterThanOrEqualTo(0), reason: marker);
    expect(end, greaterThan(start), reason: marker);
    return source.substring(start, end);
  }

  test('five authored policies disclose bounded AI and speech data flow', () {
    final source = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();
    final expectedMarkers = <String, List<String>>{
      '': const ['_combinedAiPrivacyDisclosure'],
      'Ar': const [
        'بعد موافقة صريحة',
        'Google Gemini',
        'خدمة ذكاء اصطناعي تابعة لجهة خارجية',
        'آخر 12 رسالة',
        'موافقة منفصلة',
        'سحب الموافقة لاحقًا',
        'لا صوت الميكروفون الخام',
      ],
      'Fr': const [
        'consentement explicite',
        'Google Gemini',
        'service d’IA tiers exploité par Google',
        '12 derniers messages',
        'consentement distinct',
        'retirer votre consentement',
        'jamais l’audio brut du microphone',
      ],
      'Es': const [
        'consentimiento explícito',
        'Google Gemini',
        'servicio de IA de terceros operado por Google',
        '12 mensajes recientes',
        'consentimiento separado',
        'retirar el consentimiento',
        'no el audio sin procesar del micrófono',
      ],
      'Tr': const [
        'Açık onayınızdan sonra',
        'Google Gemini',
        'üçüncü taraf bir yapay zekâ hizmeti',
        'son 12 mesaj',
        'ayrı onay gerektirir',
        'onayı daha sonra',
        'ham mikrofon sesini almaz',
      ],
    };

    for (final entry in expectedMarkers.entries) {
      final block = authoredPrivacyBlock(source, entry.key);
      for (final marker in entry.value) {
        expect(block, contains(marker), reason: '${entry.key}: $marker');
      }
    }
  });

  test('extended legal locales resolve the revised disclosure directly', () {
    for (final locale in ExtendedRuntimeCopy.supported) {
      final translated = RuntimeCopy.resolve(_englishAiVoiceDisclosure, locale);
      final mealTranslated = RuntimeCopy.resolve(
        _englishMealVisionDisclosure,
        locale,
      );
      expect(translated, isNotNull, reason: locale);
      expect(mealTranslated, isNotNull, reason: 'meal $locale');
      expect(translated!.trim(), isNotEmpty, reason: locale);
      expect(mealTranslated!.trim(), isNotEmpty, reason: 'meal $locale');
      expect(translated, isNot(_englishAiVoiceDisclosure), reason: locale);
      expect(
        mealTranslated,
        isNot(_englishMealVisionDisclosure),
        reason: 'meal $locale',
      );
    }
  });

  test(
    'policy remains aligned with bounded context and text-only voice code',
    () {
      final gateway = File(
        'lib/features/intelligence_center/services/local_model_gateway_io.dart',
      ).readAsStringSync();
      final privacyBoundary = File(
        'lib/features/intelligence_center/services/'
        'coach_cloud_privacy_boundary.dart',
      ).readAsStringSync();
      final voicePolicy = File(
        'lib/features/intelligence_center/services/coach_voice_turn_policy.dart',
      ).readAsStringSync();

      expect(gateway, contains("client.rpc('bil_get_remote_ai_consent')"));
      expect(privacyBoundary, contains('projectCoachCloudContext'));
      expect(gateway, contains('context_disclosure'));
      expect(privacyBoundary, contains('included_context_fields'));
      expect(privacyBoundary, contains('CoachCloudContextCategory'));
      expect(voicePolicy, contains('maySendAudio: false'));
      expect(voicePolicy, contains('sends recognized text only'));
    },
  );
}
