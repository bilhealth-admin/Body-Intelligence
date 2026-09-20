import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS voice capture leaves an audible route for cues and replies', () {
    final speech = File('ios/Runner/BILSpeechBridge.swift').readAsStringSync();
    final textToSpeech = File(
      'ios/Runner/BILTextToSpeechBridge.swift',
    ).readAsStringSync();
    final micSound = File(
      'ios/Runner/BILMicSoundBridge.swift',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(speech, contains('.playAndRecord,'));
    expect(speech, contains('.defaultToSpeaker'));
    expect(RegExp(r'setCategory\s*\(\s*\.record\b').hasMatch(speech), isFalse);
    expect(
      textToSpeech,
      contains('synthesizer.usesApplicationAudioSession = false'),
    );
    expect(micSound, contains('active.delegate = self'));
    expect(micSound, contains('playbackResult = result'));
    expect(micSound, contains('audioPlayerDidFinishPlaying'));
    expect(micSound, contains('finishPendingPlayback('));
    expect(micSound, contains('mic_sound_playback_rejected'));
    expect(appDelegate, contains('BILMicSoundBridge(messenger:'));
    expect(xcodeProject, contains('BILMicSoundBridge.swift in Sources'));
  });

  test(
    'microphone cue completes before speech capture starts on both platforms',
    () {
      final iosSound = File(
        'ios/Runner/BILMicSoundBridge.swift',
      ).readAsStringSync();
      final androidSound = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILMicSoundBridge.kt',
      ).readAsStringSync();
      final voice = File(
        'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
      ).readAsStringSync();
      final captureStart = voice.indexOf('Future<void> _startVoiceCapture(');
      final captureEnd = voice.indexOf(
        'Future<void> _playVoiceActivationCue()',
        captureStart,
      );
      final startCapture = voice.substring(captureStart, captureEnd);

      expect(iosSound, contains('audioPlayerDidFinishPlaying'));
      expect(iosSound, contains('finishPendingPlayback('));
      expect(androidSound, contains('setOnCompletionListener'));
      expect(androidSound, contains('finishPendingPlayback()'));
      expect(
        RegExp(r'active\.start\(\)\s+result\.success').hasMatch(androidSound),
        isFalse,
      );
      expect(
        startCapture.indexOf('await _playVoiceActivationCue()'),
        lessThan(startCapture.indexOf('await _startNativeVoiceCapture()')),
      );
    },
  );
}
