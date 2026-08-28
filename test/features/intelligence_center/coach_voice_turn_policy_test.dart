import 'package:body_intelligence_log/features/intelligence_center/services/coach_voice_turn_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = CoachVoiceTurnPolicy();

  test(
    'bottom composer is multilingual text dictation with text-only reply',
    () {
      final plan = policy.planFor(CoachVoiceEntryPoint.composerDictation);

      expect(plan.maySendAudio, isFalse);
      expect(plan.autoSpeakReply, isFalse);
      expect(plan.resumeListeningAfterSpeech, isFalse);
    },
  );

  test('top microphone is an automatic spoken live-call loop', () {
    final plan = policy.planFor(CoachVoiceEntryPoint.liveCall);

    expect(plan.maySendAudio, isFalse);
    expect(plan.autoSpeakReply, isTrue);
    expect(plan.resumeListeningAfterSpeech, isTrue);
  });
}
