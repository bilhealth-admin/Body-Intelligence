import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway_stub.dart'
    if (dart.library.io) 'local_model_gateway_io.dart'
    as implementation;

enum CoachServiceStatus {
  ready,
  signedOut,
  consentRequired,
  quotaExhausted,
  creditsRequired,
  temporarilyUnavailable,
}

enum CoachAnswerRuntime { cloudPersonalized, onDevice, localFallback }

/// Maps the trusted Edge Function error envelope to a UI-safe state.
///
/// Credit exhaustion is intentionally distinct from generic provider quota so
/// the UI can route directly to AI Coach/Boost purchasing. The status/code
/// pair must match exactly; aliases and unrelated 402 responses stay generic.
CoachServiceStatus coachServiceStatusForFunctionError(
  int status,
  String? code,
) => switch ((status, code)) {
  (401, _) => CoachServiceStatus.signedOut,
  (403, 'ai_consent_required') => CoachServiceStatus.consentRequired,
  (403, 'voice_ai_consent_required') => CoachServiceStatus.consentRequired,
  (402, 'ai_usage_exhausted') => CoachServiceStatus.creditsRequired,
  (402, _) => CoachServiceStatus.quotaExhausted,
  _ => CoachServiceStatus.temporarilyUnavailable,
};

class CoachConversationTurn {
  const CoachConversationTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LocalModelAnswer {
  const LocalModelAnswer({
    required this.text,
    required this.action,
    this.spokenText,
    this.processedOnDevice = true,
    this.reason,
    this.confidence,
    this.evidence = const [],
    this.missingData = const [],
    this.responseId,
    this.transcript,
  });

  final String text;
  final Map<String, Object?>? action;
  final String? spokenText;
  final bool processedOnDevice;
  final String? reason;
  final double? confidence;
  final List<String> evidence;
  final List<String> missingData;
  final String? responseId;
  final String? transcript;
}

class LocalModelResult {
  const LocalModelResult({
    required this.status,
    this.answer,
    this.diagnosticCode,
  });

  const LocalModelResult.answer(LocalModelAnswer value)
    : answer = value,
      status = CoachServiceStatus.ready,
      diagnosticCode = null;

  final LocalModelAnswer? answer;
  final CoachServiceStatus status;
  final String? diagnosticCode;
}

abstract interface class LocalModelGateway {
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  });
}

LocalModelGateway createLocalModelGateway() =>
    implementation.createLocalModelGateway();
