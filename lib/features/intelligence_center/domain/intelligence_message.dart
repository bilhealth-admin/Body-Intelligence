enum IntelligenceMessageRole { bil, user }

/// The interaction contract is intentionally explicit: typed turns stay
/// visual, voice turns remain readable while live-call speech is automatic,
/// and camera turns stay visual. Voice text is retained locally for the visible transcript and the
/// bounded conversation context.
enum IntelligenceMessageModality { text, voice, image, system }

enum IntelligenceMessageKind {
  coach,
  freeQuestion,
  evidence,
  action,
  memory,
  safety,
}

enum IntelligenceMessageLinkKind { recipe, workout }

/// A catalog-grounded, app-local destination attached to a coach reply.
///
/// Only the two verified wellness libraries are accepted. This prevents a
/// restored conversation from turning arbitrary persisted text into an
/// external link or an unrelated in-app route.
class IntelligenceMessageLink {
  const IntelligenceMessageLink({
    required this.id,
    required this.label,
    required this.route,
    required this.kind,
  });

  final String id;
  final String label;
  final String route;
  final IntelligenceMessageLinkKind kind;

  bool get isTrustedLocalRoute {
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    final expectedPath = switch (kind) {
      IntelligenceMessageLinkKind.recipe => '/wellness/recipes',
      IntelligenceMessageLinkKind.workout => '/wellness/workouts/routines',
    };
    final queryKey = switch (kind) {
      IntelligenceMessageLinkKind.recipe => 'recipe',
      IntelligenceMessageLinkKind.workout => 'item',
    };
    final targetId = uri.queryParameters[queryKey];
    return uri.path == expectedPath &&
        targetId == id &&
        RegExp(r'^[a-zA-Z0-9._:-]{1,160}$').hasMatch(id);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'route': route,
    'kind': kind.name,
  };

  factory IntelligenceMessageLink.fromJson(Map<String, Object?> json) =>
      IntelligenceMessageLink(
        id: json['id'] as String,
        label: json['label'] as String,
        route: json['route'] as String,
        kind: IntelligenceMessageLinkKind.values.byName(json['kind'] as String),
      );
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
    this.modality = IntelligenceMessageModality.text,
    this.links = const <IntelligenceMessageLink>[],
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
  final IntelligenceMessageModality modality;
  final List<IntelligenceMessageLink> links;

  IntelligenceMessage copyWith({
    IntelligenceMessageRole? role,
    IntelligenceMessageKind? kind,
    String? text,
    DateTime? createdAt,
    List<String>? evidence,
    double? confidence,
    String? actionId,
    String? memoryCandidate,
    String? reason,
    List<String>? missingData,
    IntelligenceMessageModality? modality,
    List<IntelligenceMessageLink>? links,
  }) => IntelligenceMessage(
    id: id,
    role: role ?? this.role,
    kind: kind ?? this.kind,
    text: text ?? this.text,
    createdAt: createdAt ?? this.createdAt,
    evidence: evidence ?? this.evidence,
    confidence: confidence ?? this.confidence,
    actionId: actionId ?? this.actionId,
    memoryCandidate: memoryCandidate ?? this.memoryCandidate,
    reason: reason ?? this.reason,
    missingData: missingData ?? this.missingData,
    modality: modality ?? this.modality,
    links: links ?? this.links,
  );

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
    'modality': modality.name,
    'links': links.map((link) => link.toJson()).toList(growable: false),
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
        modality: IntelligenceMessageModality.values.firstWhere(
          (value) => value.name == json['modality'],
          orElse: () => IntelligenceMessageModality.text,
        ),
        links: (json['links'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map(
              (value) => IntelligenceMessageLink.fromJson(
                Map<String, Object?>.from(value),
              ),
            )
            .where((link) => link.isTrustedLocalRoute)
            .toList(growable: false),
      );
}
