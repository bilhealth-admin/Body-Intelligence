import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen and speech respect the input modality', () {
    final page =
        [
              'intelligence_center_page.dart',
              'intelligence_center_widgets.dart',
              'intelligence_center_message_widgets.dart',
              'intelligence_center_voice_widgets.dart',
              'intelligence_conversation_voice.dart',
              'intelligence_query_flow.dart',
              'intelligence_action_flow.dart',
            ]
            .map(
              (name) => File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync(),
            )
            .join('\n');
    expect(page, contains('message.text,'));
    expect(page, contains('_compactSpokenCoachReply(presented.text)'));
    expect(page, contains('CoachLanguageResolver()'));
    expect(page, contains('inputChannel == CoachInputChannel.voice'));
    expect(page, contains('IntelligenceMessageModality.voice'));
    expect(page, contains("Key('ai-coach-speak-\${message.id}')"));
    expect(page, contains('Read answer aloud'));
    expect(
      page,
      contains('message.modality == IntelligenceMessageModality.voice'),
    );
    expect(page, isNot(contains('Replay voice reply')));
    expect(page, contains('_sessionWelcome(displayName, at: now)'));
    expect(page, contains('intelligenceConversationClockProvider'));
    expect(page, contains("tr('BIL member', 'عضو BIL')"));
    expect(page, isNot(contains('final email = user?.email')));
    expect(page, isNot(contains('email.substring(0')));
    expect(page, contains("tr('Good morning'"));
    expect(page, contains('_preferredCoachVoice()'));
    expect(page, contains('return BilCoachVoiceGender.male;'));
    expect(
      page,
      isNot(contains('coachVoiceGenderForProfile(profile?.gender)')),
    );
  });

  test(
    'native speech bridges select coach gender without changing language',
    () {
      final dart = File(
        'lib/features/intelligence_center/services/bil_text_to_speech.dart',
      ).readAsStringSync();
      final android = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
        'BILTextToSpeechBridge.kt',
      ).readAsStringSync();
      final ios = File(
        'ios/Runner/BILTextToSpeechBridge.swift',
      ).readAsStringSync();
      expect(dart, contains("'voiceGender': voiceGender.name"));
      expect(android, contains('call.argument<String>("voiceGender")'));
      expect(android, contains('"male" -> 0.72f'));
      expect(android, contains('voice.locale.language.equals(locale.language'));
      expect(android, contains('requestedTag == "zh-hans"'));
      expect(android, contains('requestedTag == "zh-hant"'));
      expect(ios, contains('AVSpeechSynthesisVoiceGender'));
      expect(ios, contains('candidate.gender == gender'));
      expect(ios, contains('requestedGender == "male" ? 0.82'));
      expect(ios, contains('requestedLanguage.lowercased() == "zh-hans"'));
      expect(ios, contains('requiresExactVoice'));
      expect(ios, contains('result: @escaping FlutterResult'));
    },
  );
}
