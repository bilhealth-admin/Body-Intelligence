import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both coach microphones are text-only at the model boundary', () {
    final page =
        <String>[
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
              'intelligence_query_flow.dart',
            ]
            .map((name) {
              return File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync();
            })
            .join('\n');
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final contract = File(
      'lib/features/intelligence_center/services/local_model_gateway.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ).readAsStringSync();

    expect(page, contains('if (await _startNativeVoiceCapture()) return;'));
    expect(page, contains('partialResults: true'));
    expect(page, contains('pendingVoiceTranscript = transcript'));
    expect(page, contains('textOverride: transcript'));
    expect(page, contains('autoDetectLanguage: true'));
    expect(page, isNot(contains('_startCloudVoiceCapture')));
    expect(page, isNot(contains('cloudVoice.start')));
    expect(page, isNot(contains('base64Audio')));
    expect(contract, isNot(contains('CoachVoicePayload')));
    expect(gateway, isNot(contains("'audio':")));
    expect(settings, contains('Voice stays on this device'));
    expect(settings, contains('Only that recognized text can be sent'));
    expect(settings, isNot(contains('Cloud voice processing')));
  });
}
