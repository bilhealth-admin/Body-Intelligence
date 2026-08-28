enum CoachVoiceEntryPoint { composerDictation, liveCall }

final class CoachVoiceTurnPlan {
  const CoachVoiceTurnPlan({
    required this.maySendAudio,
    required this.autoSpeakReply,
    required this.resumeListeningAfterSpeech,
  });

  final bool maySendAudio;
  final bool autoSpeakReply;
  final bool resumeListeningAfterSpeech;
}

/// Keeps the two microphone promises separate and testable.
///
/// Composer dictation turns speech into text and gets a text-only response.
/// Live call also sends recognized text only, speaks the response locally,
/// then resumes listening. Neither plan implies a speaker permission: mobile
/// platforms expose no such runtime permission.
final class CoachVoiceTurnPolicy {
  const CoachVoiceTurnPolicy();

  CoachVoiceTurnPlan planFor(CoachVoiceEntryPoint entryPoint) =>
      switch (entryPoint) {
        CoachVoiceEntryPoint.composerDictation => const CoachVoiceTurnPlan(
          maySendAudio: false,
          autoSpeakReply: false,
          resumeListeningAfterSpeech: false,
        ),
        CoachVoiceEntryPoint.liveCall => const CoachVoiceTurnPlan(
          maySendAudio: false,
          autoSpeakReply: true,
          resumeListeningAfterSpeech: true,
        ),
      };
}
