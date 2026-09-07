/// Repairs a very small set of high-confidence speech-recognition artifacts.
///
/// This is intentionally scoped to the voice path. Typed text such as
/// "cat" must never be rewritten, and unknown transcripts are returned
/// unchanged so the coach can still reason about the user's actual words.
String normalizeCoachVoiceTranscript(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r"[’‘]"), "'")
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  return switch (normalized) {
    // iOS commonly returns this for the short Arabic greeting "كيفك".
    'cat' => 'كيفك',
    // iOS commonly returns these variants for "مساء الخير".
    'massage hair' ||
    'message hair' ||
    'massage here' ||
    'message here' ||
    'massage air' ||
    'message air' => 'مساء الخير',
    _ => value,
  };
}
