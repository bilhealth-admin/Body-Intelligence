import 'coach_media_attempt.dart';

/// Text to pass to the existing Coach query/review path after the caller's
/// review policy permits submission. It is not a food confirmation or receipt.
final class CoachVoiceTranscriptSubmission {
  const CoachVoiceTranscriptSubmission._({
    required this.attempt,
    required this.text,
    required this.languageTag,
  });

  final CoachMediaAttempt attempt;
  final String text;
  final String? languageTag;
}

/// Holds the editable transcript of one native speech-recognition attempt.
///
/// There are no timers, recognizers, cloud calls, or automatic submissions here.
/// Final callbacks freeze recognition, but the user can still edit the draft.
/// A caller can [finish] a partial result after silence or engine termination,
/// present it for review, and explicitly [takeForSubmission] when appropriate.
final class CoachVoiceTranscriptBridge {
  CoachMediaAttempt? _attempt;
  String _draftText = '';
  String? _languageTag;
  bool _hasFinal = false;
  bool _recognitionClosed = false;
  bool _submitted = false;
  bool _disposed = false;

  String get draftText => _hasCurrentDraft ? _draftText : '';
  String? get languageTag => _hasCurrentDraft ? _languageTag : null;
  bool get hasFinal => _hasCurrentDraft && _hasFinal;
  bool get isReadyForReview =>
      _hasCurrentDraft && _recognitionClosed && _draftText.trim().isNotEmpty;

  /// Starting a different attempt cancels the previous one. Reusing the same
  /// object cannot reset a frozen or already submitted transcript.
  bool begin(CoachMediaAttempt attempt) {
    if (_disposed || identical(_attempt, attempt)) return false;
    cancel();
    if (!attempt.canAcceptResult) return false;
    _attempt = attempt;
    return true;
  }

  bool acceptPartial(
    CoachMediaAttempt attempt,
    String text, {
    String? languageTag,
  }) {
    if (!_canUse(attempt) || _recognitionClosed) return false;
    final transcript = text.trim();
    if (transcript.isEmpty) return false;
    _draftText = transcript;
    _updateLanguageTag(languageTag);
    return true;
  }

  bool acceptFinal(
    CoachMediaAttempt attempt,
    String text, {
    String? languageTag,
  }) {
    if (!_canUse(attempt) || _recognitionClosed) return false;
    final transcript = text.trim();
    if (transcript.isEmpty) return false;
    _draftText = transcript;
    _updateLanguageTag(languageTag);
    _hasFinal = true;
    _recognitionClosed = true;
    return true;
  }

  /// Stops partial updates when the recognizer did not produce a usable final.
  /// This only freezes a draft for review; it does not submit or claim it.
  bool finish(CoachMediaAttempt attempt) {
    if (!_canUse(attempt) || _recognitionClosed) return false;
    _recognitionClosed = true;
    return true;
  }

  /// An explicit user edit wins over all subsequent recognition callbacks,
  /// including a final result arriving after the user started correcting text.
  /// Whitespace is preserved while editing and trimmed only on submission.
  bool updateDraft(CoachMediaAttempt attempt, String text) {
    if (!_canUse(attempt)) return false;
    _draftText = text;
    _recognitionClosed = true;
    return true;
  }

  /// Returns one immutable query input, after a final, [finish], or explicit
  /// user edit. It never consumes a still-changing partial automatically.
  ///
  /// The caller must recheck `submission.attempt.isCurrent` after every await
  /// before handing this text to the existing query/review path. That path owns
  /// consent, quotas, confirmation, the transaction, and committed readback.
  CoachVoiceTranscriptSubmission? takeForSubmission(CoachMediaAttempt attempt) {
    if (!_canUse(attempt) || !_recognitionClosed) return null;
    final transcript = _draftText.trim();
    if (transcript.isEmpty || !attempt.tryClaim()) return null;
    final submission = CoachVoiceTranscriptSubmission._(
      attempt: attempt,
      text: transcript,
      languageTag: _languageTag,
    );
    _submitted = true;
    _clearTranscript();
    return submission;
  }

  void cancel() {
    _attempt?.cancel();
    _attempt = null;
    _submitted = false;
    _clearTranscript();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _attempt?.dispose();
    cancel();
  }

  bool get _hasCurrentDraft {
    final attempt = _attempt;
    return attempt != null && _canUse(attempt);
  }

  bool _canUse(CoachMediaAttempt attempt) {
    if (_disposed || !identical(_attempt, attempt) || _submitted) return false;
    if (attempt.canAcceptResult) return true;
    _clearTranscript();
    return false;
  }

  void _updateLanguageTag(String? languageTag) {
    final normalized = languageTag?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      _languageTag = normalized;
    }
  }

  void _clearTranscript() {
    _draftText = '';
    _languageTag = null;
    _hasFinal = false;
    _recognitionClosed = false;
  }
}
