/// Small deterministic voice-activity gate for recorder amplitude samples.
///
/// Two consecutive onset frames prevent a single click from uploading audio.
/// A lower release level keeps ordinary pauses inside one spoken question.
class BilVoiceActivityDetector {
  BilVoiceActivityDetector({
    this.onsetDb = -50,
    this.releaseDb = -56,
    this.requiredOnsetFrames = 2,
  });

  final double onsetDb;
  final double releaseDb;
  final int requiredOnsetFrames;

  int _onsetFrames = 0;
  bool _heardSpeech = false;

  bool get heardSpeech => _heardSpeech;

  void reset() {
    _onsetFrames = 0;
    _heardSpeech = false;
  }

  void add(double currentDb) {
    if (_heardSpeech) return;
    if (currentDb >= onsetDb) {
      _onsetFrames += 1;
      if (_onsetFrames >= requiredOnsetFrames) _heardSpeech = true;
      return;
    }
    _onsetFrames = 0;
  }

  bool isSilence(double currentDb) => currentDb <= releaseDb;
}
