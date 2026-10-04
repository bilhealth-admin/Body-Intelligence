import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS English and Arabic disclose user-initiated Community voice', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final english = File(
      'ios/Runner/en.lproj/InfoPlist.strings',
    ).readAsStringSync();
    final arabic = File(
      'ios/Runner/ar.lproj/InfoPlist.strings',
    ).readAsStringSync();
    for (final source in [plist, english]) {
      expect(source, contains('a Community post'));
      expect(source, contains('Community posts'));
      expect(source, contains('before saving, posting, or sending it'));
    }
    expect(arabic, contains('منشور في المجتمع'));
    expect(arabic, contains('منشورات المجتمع'));
    expect(arabic, contains('قبل حفظه أو نشره أو إرساله'));
    final service = File(
      'lib/features/community/services/community_composer_voice_input_service.dart',
    ).readAsStringSync();
    expect(service, contains('Permission.microphone'));
    expect(service, contains('Permission.speech'));
    expect(service, contains('SpeechToText'));
  });
}
