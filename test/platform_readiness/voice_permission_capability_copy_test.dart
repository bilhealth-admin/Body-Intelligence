import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS mic-granted speech-denied recovery names speech recognition', () {
    final capability = mealVoiceEffectivePermission(
      platform: TargetPlatform.iOS,
      microphoneState: BilRuntimePermissionState.granted,
      speechRecognitionState: BilRuntimePermissionState.denied,
    );

    expect(capability.capability, BilRuntimeCapability.speechRecognition);
    expect(capability.state, BilRuntimePermissionState.denied);
    final recovery = mealVoiceSettingsRecoveryCopy(
      languageCode: 'en',
      capability: capability.capability,
    );
    expect(recovery, contains('Speech recognition access is off'));
    expect(recovery, isNot(contains('Microphone access is off')));
    final rationale = mealVoicePermissionRationaleCopy(
      languageCode: 'en',
      capability: capability.capability,
    );
    expect(rationale, contains('speech recognition'));
    expect(rationale, isNot(contains('Microphone access')));
  });

  test('microphone denial keeps the microphone-specific recovery', () {
    final capability = mealVoiceEffectivePermission(
      platform: TargetPlatform.iOS,
      microphoneState: BilRuntimePermissionState.permanentlyDenied,
    );

    expect(capability.capability, BilRuntimeCapability.microphone);
    expect(capability.state, BilRuntimePermissionState.permanentlyDenied);
    expect(
      mealVoiceSettingsRecoveryCopy(
        languageCode: 'en',
        capability: capability.capability,
      ),
      contains('Microphone access is off'),
    );
    expect(
      mealVoicePermissionRationaleCopy(
        languageCode: 'en',
        capability: capability.capability,
      ),
      contains('microphone'),
    );
  });

  test('weight voice also names a denied iOS speech permission truthfully', () {
    final decision = weightVoiceEffectivePermission(
      platform: TargetPlatform.iOS,
      microphoneState: BilRuntimePermissionState.granted,
      speechRecognitionState: BilRuntimePermissionState.permanentlyDenied,
    );

    expect(decision.capability, BilRuntimeCapability.speechRecognition);
    expect(decision.state, BilRuntimePermissionState.permanentlyDenied);
    expect(
      weightVoiceSettingsRecoverySource(decision.capability),
      contains('Speech recognition access is off'),
    );
  });
}
