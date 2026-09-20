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
      'intelligence_query_flow.dart',
    ).readAsStringSync();
    final server = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();

    expect(contextProvider, contains("signal.key == 'sleep'"));
    expect(contextProvider, contains('authoritativeExerciseEnergyForDay('));
    expect(gateway, contains("client.rpc('bil_get_remote_ai_consent')"));
    expect(privacyBoundary, contains('projectCoachCloudContext'));
    expect(gateway, contains('context_disclosure'));
    expect(queryFlow, contains("'p_purpose': 'remote_ai'"));
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
}

String _healthShareDescription(String contents) {
  final matches = RegExp(
    r'^"NSHealthShareUsageDescription"\s*=\s*"([^"]+)";$',
    multiLine: true,
  ).allMatches(contents).toList(growable: false);
  expect(matches, hasLength(1));
  return matches.single.group(1)!;
}
