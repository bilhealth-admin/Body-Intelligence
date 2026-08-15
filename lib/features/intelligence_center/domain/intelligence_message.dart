enum IntelligenceMessageRole { bil, user }

enum IntelligenceMessageKind {
  coach,
  freeQuestion,
  evidence,
  action,
  memory,
  safety,
}

class IntelligenceMessage {
  const IntelligenceMessage({
    required this.id,
    required this.role,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.evidence = const <String>[],
    this.confidence,
    this.actionId,
    this.memoryCandidate,
    this.reason,
    this.missingData = const <String>[],
  });

  final String id;
  final IntelligenceMessageRole role;
  final IntelligenceMessageKind kind;
  final String text;
  final DateTime createdAt;
  final List<String> evidence;
  final double? confidence;
  final String? actionId;
  final String? memoryCandidate;
  final String? reason;
  final List<String> missingData;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'kind': kind.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'evidence': evidence,
    'confidence': confidence,
    'actionId': actionId,
    'memoryCandidate': memoryCandidate,
    'reason': reason,
    'missingData': missingData,
  };

  factory IntelligenceMessage.fromJson(Map<String, Object?> json) =>
      IntelligenceMessage(
        id: json['id'] as String,
        role: IntelligenceMessageRole.values.byName(json['role'] as String),
        kind: IntelligenceMessageKind.values.byName(json['kind'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        evidence: (json['evidence'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        confidence: (json['confidence'] as num?)?.toDouble(),
        actionId: json['actionId'] as String?,
        memoryCandidate: json['memoryCandidate'] as String?,
        reason: json['reason'] as String?,
        missingData: (json['missingData'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}
