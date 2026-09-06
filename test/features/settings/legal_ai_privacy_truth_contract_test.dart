import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

const _englishAiVoiceDisclosure =
    'When Personalized Intelligence is enabled and you ask the AI Coach, BIL may send the minimum relevant context—such as selected profile, diary, and connected-health data—through BIL’s secure gateway to its configured AI provider to answer that request. A meal image is sent only when you choose analysis and the secure server gateway is configured. In the current mobile speech flow, BIL’s backend and Gemini receive only the recognized transcript, not raw microphone audio; Apple or another platform speech-recognition service may process the audio you initiate under its own terms and settings. Device permissions can be withdrawn in system settings.';

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
      '': const [
        'When Personalized Intelligence is enabled',
        'minimum relevant context',
        'selected profile, diary, and connected-health data',
        'through BIL’s secure gateway',
        'configured AI provider',
        'current mobile speech flow',
        'receive only the recognized transcript',
        'not raw microphone audio',
        'platform speech-recognition service may process',
        'own terms and settings',
      ],
      'Ar': const [
        'عند تفعيل «الذكاء المخصص»',
        'أقل قدر من السياق ذي الصلة',
        'الملف واليوميات والصحة المتصلة',
        'عبر بوابة BIL الآمنة',
        'مزود الذكاء الاصطناعي المهيأ',
        'مسار الكلام الحالي على الهاتف',
        'النص المتعرّف عليه فقط',
        'وليس صوت الميكروفون الخام',
        'وفق شروطها وإعداداتها',
      ],
      'Fr': const [
        'Intelligence personnalisée est activée',
        'minimum de contexte pertinent',
        'du profil, du journal et de santé connectée',
        'passerelle sécurisée de BIL',
        'fournisseur d’IA configuré',
        'parcours vocal mobile actuel',
        'que la transcription reconnue',
        'jamais l’audio brut du microphone',
        'propres conditions et réglages',
      ],
      'Es': const [
        'Inteligencia personalizada está activada',
        'contexto pertinente mínimo',
        'del perfil, diario y salud conectada',
        'pasarela segura de BIL',
        'proveedor de IA configurado',
        'flujo de voz móvil actual',
        'solo reciben la transcripción reconocida',
        'no el audio sin procesar del micrófono',
        'propios términos y ajustes',
      ],
      'Tr': const [
        'Kişiselleştirilmiş Zekâ açıkken',
        'gereken en az ilgili bağlamı',
        'profil, günlük ve bağlı sağlık verileri',
        'BIL’in güvenli geçidi üzerinden',
        'yapılandırılmış AI sağlayıcısına',
        'Mevcut mobil konuşma akışında',
        'yalnızca tanınan metni alır',
        'ham mikrofon sesini almaz',
        'kendi koşulları ve ayarları kapsamında',
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
      expect(translated, isNotNull, reason: locale);
      expect(translated!.trim(), isNotEmpty, reason: locale);
      expect(translated, isNot(_englishAiVoiceDisclosure), reason: locale);
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
