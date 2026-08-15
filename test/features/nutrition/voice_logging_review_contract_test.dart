import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice logging requires editable review and never writes a meal', () {
    final service = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();
    expect(service, contains("Key('editable-voice-food-candidate')"));
    expect(service, contains("Key('accept-reviewed-voice-candidate')"));
    expect(service, contains('Nothing is logged automatically.'));
    expect(service, isNot(contains('mealRepositoryProvider')));
    expect(service, isNot(contains('.addMeal(')));
  });

  test(
    'native bridges expose explicit permission timeout and no-match paths',
    () {
      final android = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILSpeechBridge.kt',
      ).readAsStringSync();
      final ios = File('ios/Runner/BILSpeechBridge.swift').readAsStringSync();
      expect(android, contains('microphone_permission_denied'));
      expect(android, contains('speech_timeout'));
      expect(android, contains('speech_no_match'));
      expect(ios, contains('speech_permission_denied'));
      expect(ios, contains('microphone_permission_denied'));
      expect(ios, contains('speech_no_match'));
    },
  );
}
