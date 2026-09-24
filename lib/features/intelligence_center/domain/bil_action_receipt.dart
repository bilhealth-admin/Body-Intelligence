class BilActionReceipt {
  const BilActionReceipt({
    required this.actionId,
    required this.committed,
    required this.completedAt,
    this.entityType,
    this.entityId,
    this.refreshTargets = const <String>{},
    this.before = const <String, Object?>{},
    this.after = const <String, Object?>{},
    this.source = 'ai_coach',
    this.toolId,
    this.undoable = false,
    this.undoneAt,
  });

  final String actionId;
  final bool committed;
  final DateTime completedAt;
  final String? entityType;
  final String? entityId;
  final Set<String> refreshTargets;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final String source;
  final String? toolId;
  final bool undoable;
  final DateTime? undoneAt;

  bool get verified =>
      committed &&
      completedAt.microsecondsSinceEpoch > 0 &&
      (entityType == null || entityId?.isNotEmpty == true);

  /// Stable localization key; the domain receipt never embeds user-visible
  /// language and therefore remains identical across text and voice routes.
  String get messageKey => verified
      ? 'ai_coach.action_receipt.completed'
      : 'ai_coach.action_receipt.not_completed';

  Map<String, Object?> toStructuredPayload() => <String, Object?>{
    'action_id': actionId,
    'committed': committed,
    'verified': verified,
    'completed_at': completedAt.toUtc().toIso8601String(),
    if (entityType != null) 'entity_type': entityType,
    if (entityId != null) 'entity_id': entityId,
    'refresh_targets': refreshTargets.toList()..sort(),
    'before': before,
    'after': after,
    'source': source,
    if (toolId != null) 'tool_id': toolId,
    'undoable': undoable,
    if (undoneAt != null) 'undone_at': undoneAt!.toUtc().toIso8601String(),
    'message_key': messageKey,
  };
}
