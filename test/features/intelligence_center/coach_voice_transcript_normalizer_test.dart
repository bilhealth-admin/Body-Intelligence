import 'package:body_intelligence_log/features/intelligence_center/services/coach_voice_transcript_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repairs only the two observed short Arabic recognition artifacts', () {
    expect(normalizeCoachVoiceTranscript('Cat'), 'كيفك');
    expect(normalizeCoachVoiceTranscript('Massage hair'), 'مساء الخير');
    expect(normalizeCoachVoiceTranscript('message here'), 'مساء الخير');
  });

  test('unknown voice text and typed-looking words remain unchanged', () {
    expect(normalizeCoachVoiceTranscript('cat and dog'), 'cat and dog');
    expect(
      normalizeCoachVoiceTranscript('How many calories?'),
      'How many calories?',
    );
    expect(normalizeCoachVoiceTranscript(''), isEmpty);
  });
}
