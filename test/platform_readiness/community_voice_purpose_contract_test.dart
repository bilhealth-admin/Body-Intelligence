import 'dart:io';

import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('Community voice uses the actual microphone and speech policy', () {
    const policy = BilRuntimePermissionPolicy();
    expect(
      policy.permissionFor(BilRuntimeCapability.microphone),
      Permission.microphone,
    );
    expect(
      policy.permissionFor(BilRuntimeCapability.speechRecognition),
      Permission.speech,
    );
    final service = File(
      'lib/features/community/services/community_composer_voice_input_service.dart',
    ).readAsStringSync();
    expect(service, contains('BilRuntimeCapability.microphone'));
    expect(service, contains('BilRuntimeCapability.speechRecognition'));
    expect(service, contains('SpeechToText'));
  });

  test('All 25 localized iOS voice purposes disclose Community posts', () {
    const phrases = <String, String>{
      'ar': 'المجتمع',
      'en': 'Community',
      'fr': 'communauté',
      'es': 'comunidad',
      'tr': 'topluluk',
      'de': 'Community',
      'it': 'community',
      'pt-BR': 'comunidade',
      'pt-PT': 'comunidade',
      'ur': 'کمیونٹی',
      'fa': 'انجمن',
      'hi': 'समुदाय',
      'id': 'komunitas',
      'ms': 'komuniti',
      'ja': 'コミュニティ',
      'ko': '커뮤니티',
      'zh-Hans': '社区',
      'zh-Hant': '社群',
      'ru': 'сообщества',
      'bn': 'কমিউনিটি',
      'vi': 'cộng đồng',
      'th': 'ชุมชน',
      'pl': 'społeczności',
      'nl': 'community',
      'uk': 'спільноти',
    };
    expect(phrases, hasLength(25));
    for (final entry in phrases.entries) {
      final source = File(
        'ios/Runner/${entry.key}.lproj/InfoPlist.strings',
      ).readAsLinesSync();
      for (final key in [
        'NSMicrophoneUsageDescription',
        'NSSpeechRecognitionUsageDescription',
      ]) {
        final lines = source.where((line) => line.startsWith('"$key"'));
        expect(lines, hasLength(1), reason: '${entry.key}: $key');
        expect(lines.single, contains(entry.value));
      }
    }
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('a Community post'));
    expect(plist, contains('Community posts'));
    expect(plist, contains('before saving, posting, or sending it'));
  });
}
