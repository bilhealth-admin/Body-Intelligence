enum ReferralAuditAction {
  attributed,
  duplicateBlocked,
  selfAttributionBlocked,
  expired,
  confirmed,
  rejected,
  commissionCreated,
  commissionRevoked,
}

final class ReferralAuditEvent {
  const ReferralAuditEvent({
    required this.id,
    required this.subjectId,
    required this.action,
    required this.occurredAt,
    this.detail,
  });

  final String id;
  final String subjectId;
  final ReferralAuditAction action;
  final DateTime occurredAt;
  final String? detail;
}
