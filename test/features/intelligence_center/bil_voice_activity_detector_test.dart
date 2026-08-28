import 'package:body_intelligence_log/features/intelligence_center/services/bil_voice_activity_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts quiet emulator speech only after consecutive frames', () {
    final detector = BilVoiceActivityDetector();

    detector.add(-48);
    expect(detector.heardSpeech, isFalse);
    detector.add(-49);
    expect(detector.heardSpeech, isTrue);
  });

  test('isolated noise does not count as speech', () {
    final detector = BilVoiceActivityDetector();

    detector.add(-47);
    detector.add(-70);
    detector.add(-47);
    expect(detector.heardSpeech, isFalse);
  });

  test('uses a lower release threshold for natural pauses', () {
    final detector = BilVoiceActivityDetector();

    expect(detector.isSilence(-53), isFalse);
    expect(detector.isSilence(-57), isTrue);
  });
}
