import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HealthKit data reaches cloud AI only through the consented flow', () {
    final contextProvider = File(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final privacyBoundary = File(
      'lib/features/intelligence_center/services/'
      'coach_cloud_privacy_boundary.dart',
    ).readAsStringSync();
    final queryFlow = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_query_guard_flow.dart',
    ).readAsStringSync();
    final consentCoordinator = File(
      'lib/features/intelligence_center/services/'
      'remote_ai_consent_coordinator.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final server = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();

    expect(contextProvider, contains("signal.key == 'sleep'"));
    expect(contextProvider, contains('authoritativeExerciseEnergyForDay('));
    expect(gateway, contains("client.rpc('bil_get_remote_ai_consent')"));
    expect(privacyBoundary, contains('projectCoachCloudContext'));
    expect(gateway, contains('context_disclosure'));
    expect(queryFlow, contains('.grantAndVerify()'));
    expect(consentCoordinator, contains("'p_purpose': 'remote_ai'"));
    expect(consentCoordinator, contains("'p_policy_version': '3'"));
    final grant = consentCoordinator.substring(
      consentCoordinator.indexOf('Future<bool> _grantCurrent('),
      consentCoordinator.indexOf('Future<bool> _revokeCurrent('),
    );
    final persisted = grant.indexOf('await write().timeout(');
    final readback = grant.indexOf('final receipt = await read().timeout(');
    final verified = grant.indexOf(
      'if (!isCurrentRemoteAiConsentGranted(receipt)',
    );
    final clearDenial = grant.indexOf('await _persistDenial(owner, false);');
    final unlocked = grant.indexOf('_granted = true;');
    expect(persisted, greaterThanOrEqualTo(0));
    expect(readback, greaterThan(persisted));
    expect(verified, greaterThan(readback));
    expect(clearDenial, greaterThan(verified));
    expect(unlocked, greaterThan(clearDenial));
    expect(
      grant.substring(verified, clearDenial),
      contains('_syncOwner() != owner ||\n        _generation != generation'),
    );
    expect(grant.substring(verified, clearDenial), contains('return false;'));
    expect(
      grant.substring(clearDenial, unlocked),
      contains('await _persistDenial(owner, true);\n      return false;'),
      reason: 'A newer denial or owner change must not unlock cloud AI.',
    );
    expect(server, contains('bil_has_remote_ai_consent'));
  });

  test('every iOS locale truthfully discloses conditional cloud AI use', () {
    const disclosureMarkers = <String, List<String>>{
      'ar': ['وفقط عندما', 'مدرب BIL', 'الحد الأدنى', 'سحابي', 'بشكل آمن'],
      'bn': ['শুধু তখনই', 'BIL Coach', 'ন্যূনতম', 'ক্লাউড AI', 'নিরাপদে'],
      'de': ['Nur wenn', 'BIL Coach', 'mindestens', 'Cloud-AI', 'sicher'],
      'en': ['Only when', 'BIL Coach', 'minimum', 'cloud AI', 'securely'],
      'es': ['Solo cuando', 'BIL Coach', 'mínimo', 'IA en la nube', 'segura'],
      'fa': ['فقط زمانی', 'مربی BIL', 'حداقل', 'مصنوعی ابری', 'امن'],
      'fr': [
        'Uniquement lorsque',
        'BIL Coach',
        'strictement nécessaires',
        'IA dans le cloud',
        'sécurisée',
      ],
      'hi': ['केवल जब', 'BIL Coach', 'न्यूनतम', 'क्लाउड AI', 'सुरक्षित'],
      'id': ['Hanya saat', 'BIL Coach', 'minimum', 'AI berbasis cloud', 'aman'],
      'it': [
        'Solo quando',
        'BIL Coach',
        'strettamente necessari',
        'IA nel cloud',
        'sicuro',
      ],
      'ja': ['場合に限り', 'BIL Coach', '最小限', 'クラウド AI', '安全に'],
      'ko': ['경우에만', 'BIL Coach', '최소한', '클라우드 AI', '안전하게'],
      'ms': ['Hanya apabila', 'BIL Coach', 'minimum', 'AI awan', 'selamat'],
      'nl': [
        'Alleen wanneer',
        'BIL Coach',
        'minimaal',
        'AI in de cloud',
        'veilig',
      ],
      'pl': [
        'Tylko gdy',
        'BIL Coach',
        'minimalny',
        'AI w chmurze',
        'bezpiecznie',
      ],
      'pt-BR': [
        'Somente quando',
        'BIL Coach',
        'mínimo',
        'IA na nuvem',
        'segurança',
      ],
      'pt-PT': [
        'Apenas quando',
        'BIL Coach',
        'mínimo',
        'IA na nuvem',
        'segura',
      ],
      'ru': [
        'Только когда',
        'BIL Coach',
        'минимально',
        'облачным ИИ',
        'безопасно',
      ],
      'th': ['เฉพาะเมื่อ', 'BIL Coach', 'ขั้นต่ำ', 'AI บนคลาวด์', 'ปลอดภัย'],
      'tr': [
        'Yalnızca',
        'BIL Coach',
        'asgari',
        'bulut yapay zekâsı',
        'güvenli',
      ],
      'uk': ['Лише коли', 'BIL Coach', 'мінімально', 'хмарним ШІ', 'безпечно'],
      'ur': ['صرف جب', 'BIL Coach', 'کم سے کم', 'کلاؤڈ AI', 'محفوظ'],
      'vi': ['Chỉ khi', 'BIL Coach', 'tối thiểu', 'AI đám mây', 'an toàn'],
      'zh-Hans': ['只有当', 'BIL Coach', '最少', '云端 AI', '安全'],
      'zh-Hant': ['只有當', 'BIL Coach', '最少', '雲端 AI', '安全'],
    };

    final localizedFiles = Directory('ios/Runner')
        .listSync()
        .whereType<Directory>()
        .where((directory) => directory.path.endsWith('.lproj'))
        .map(
          (directory) => File(
            '${directory.path}${Platform.pathSeparator}InfoPlist.strings',
          ),
        )
        .where((file) => file.existsSync())
        .toList(growable: false);
    final foundLocales = localizedFiles
        .map(
          (file) => file.parent.path
              .split(Platform.pathSeparator)
              .last
              .replaceAll('.lproj', ''),
        )
        .toSet();

    expect(foundLocales, disclosureMarkers.keys.toSet());
    for (final file in localizedFiles) {
      final locale = file.parent.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll('.lproj', '');
      final value = _healthShareDescription(file.readAsStringSync());
      expect(value, contains('Personalized Intelligence'), reason: locale);
      for (final marker in disclosureMarkers[locale]!) {
        expect(value, contains(marker), reason: '$locale is missing "$marker"');
      }
    }

    final base = File('ios/Runner/Info.plist').readAsStringSync();
    expect(base, contains('private on-device fitness timeline and insights'));
    expect(base, contains('Only when you enable Personalized Intelligence'));
    expect(base, contains('ask BIL Coach a question'));
    expect(base, contains('minimum relevant data'));
    expect(base, contains('securely processed by cloud AI'));
  });

  test(
    'iOS voice disclosures match on-device transcription and AI routing',
    () {
      const voiceMarkers = <String, List<String>>{
        'ar': ['على هذا الجهاز', 'لا يُرسل الصوت الخام إلى Gemini'],
        'bn': ['এই ডিভাইসেই', 'Raw audio Gemini-তে পাঠানো হয় না'],
        'de': ['auf diesem Gerät', 'Roh-Audio wird nicht an Gemini gesendet'],
        'en': ['on this device', 'Raw audio is not sent to Gemini'],
        'es': [
          'en este dispositivo',
          'El audio sin procesar no se envía a Gemini',
        ],
        'fa': ['روی همین دستگاه', 'صدای خام به Gemini ارسال نمی‌شود'],
        'fr': ['sur cet appareil', 'L’audio brut n’est pas envoyé à Gemini'],
        'hi': ['इस डिवाइस पर', 'कच्चा ऑडियो Gemini को नहीं भेजा जाता'],
        'id': ['di perangkat ini', 'Audio mentah tidak dikirim ke Gemini'],
        'it': [
          'su questo dispositivo',
          'L’audio grezzo non viene inviato a Gemini',
        ],
        'ja': ['このデバイス上', '生の音声は Gemini に送信されません'],
        'ko': ['이 기기에서', '원본 오디오는 Gemini로 전송되지 않습니다'],
        'ms': ['pada peranti ini', 'Audio mentah tidak dihantar ke Gemini'],
        'nl': [
          'op dit apparaat',
          'Ruwe audio wordt niet naar Gemini verzonden',
        ],
        'pl': ['na tym urządzeniu', 'Surowe audio nie jest wysyłane do Gemini'],
        'pt-BR': ['neste dispositivo', 'O áudio bruto não é enviado ao Gemini'],
        'pt-PT': [
          'neste dispositivo',
          'O áudio bruto não é enviado para o Gemini',
        ],
        'ru': [
          'на этом устройстве',
          'Необработанное аудио не отправляется в Gemini',
        ],
        'th': ['บนอุปกรณ์นี้', 'เสียงดิบจะไม่ถูกส่งไปยัง Gemini'],
        'tr': ['bu cihazda', 'Ham ses Gemini’ye gönderilmez'],
        'uk': [
          'на цьому пристрої',
          'Необроблене аудіо не надсилається до Gemini',
        ],
        'ur': ['اسی ڈیوائس پر', 'خام آڈیو Gemini کو نہیں بھیجی جاتی'],
        'vi': ['trên thiết bị này', 'Âm thanh thô không được gửi đến Gemini'],
        'zh-Hans': ['在此设备上', '原始音频不会发送给 Gemini'],
        'zh-Hant': ['在此裝置上', '原始音訊不會傳送給 Gemini'],
      };

      final speechBridge = File(
        'ios/Runner/BILSpeechBridge.swift',
      ).readAsStringSync();
      expect(speechBridge, contains('recognizer.supportsOnDeviceRecognition'));
      expect(
        speechBridge,
        contains('request.requiresOnDeviceRecognition = true'),
      );

      final localizedFiles = Directory('ios/Runner')
          .listSync()
          .whereType<Directory>()
          .where((directory) => directory.path.endsWith('.lproj'))
          .map(
            (directory) => File(
              '${directory.path}${Platform.pathSeparator}InfoPlist.strings',
            ),
          )
          .where((file) => file.existsSync());
      for (final file in localizedFiles) {
        final locale = file.parent.path
            .split(Platform.pathSeparator)
            .last
            .replaceAll('.lproj', '');
        final contents = file.readAsStringSync();
        final microphone = _plistDescription(
          contents,
          'NSMicrophoneUsageDescription',
        );
        final speech = _plistDescription(
          contents,
          'NSSpeechRecognitionUsageDescription',
        );
        final markers = voiceMarkers[locale]!;
        expect(
          microphone,
          contains(markers.first),
          reason: '$locale microphone',
        );
        expect(speech, contains(markers.first), reason: '$locale speech');
        expect(
          '$microphone $speech',
          contains(markers.last),
          reason: '$locale raw-audio disclosure',
        );
        expect(microphone, isNot(contains('review the text before')));
        expect(speech, isNot(contains('review it before')));
      }

      final base = File('ios/Runner/Info.plist').readAsStringSync();
      final microphone = _plistXmlDescription(
        base,
        'NSMicrophoneUsageDescription',
      );
      final speech = _plistXmlDescription(
        base,
        'NSSpeechRecognitionUsageDescription',
      );
      expect(microphone, contains('on this device'));
      expect(
        microphone,
        contains(
          'voice input for weight, meals, a Community post, or AI Coach',
        ),
      );
      expect(microphone, contains('Raw audio is not sent to Gemini'));
      expect(speech, contains('on this device'));
      expect(speech, contains('Raw audio is never sent to Gemini'));
    },
  );
}

String _healthShareDescription(String contents) {
  return _plistDescription(contents, 'NSHealthShareUsageDescription');
}

String _plistDescription(String contents, String key) {
  final matches = RegExp(
    r'^"' + RegExp.escape(key) + r'"\s*=\s*"([^"]+)";$',
    multiLine: true,
  ).allMatches(contents).toList(growable: false);
  expect(matches, hasLength(1));
  return matches.single.group(1)!;
}

String _plistXmlDescription(String contents, String key) {
  final matches = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).allMatches(contents).toList(growable: false);
  expect(matches, hasLength(1));
  return matches.single.group(1)!;
}
