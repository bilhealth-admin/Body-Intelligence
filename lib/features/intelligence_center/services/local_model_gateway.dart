import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway_stub.dart'
    if (dart.library.io) 'local_model_gateway_io.dart'
    as implementation;

enum CoachServiceStatus {
  ready,
  signedOut,
  consentRequired,
  quotaExhausted,
  temporarilyUnavailable,
}

enum CoachAnswerRuntime { cloudPersonalized, onDevice, localFallback }

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
