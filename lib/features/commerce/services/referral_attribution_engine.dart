import '../domain/affiliate_commission.dart';
import '../domain/referral_attribution.dart';
import '../domain/referral_audit_event.dart';
import '../domain/referral_decision.dart';
import '../repositories/referral_repository.dart';

final class ReferralAttributionEngine {
  ReferralAttributionEngine(this._repository);

  final ReferralRepository _repository;

  ReferralDecision attribute({
    required String code,
    required String referredUserId,
    required ReferralAttributionSource source,
    required DateTime now,
  }) {
    final program = _repository.findProgramByCode(code);
    if (program == null) {
      return const ReferralDecision(code: ReferralDecisionCode.unknownCode);
    }
    if (!program.isActiveAt(now)) {
      return const ReferralDecision(code: ReferralDecisionCode.inactiveProgram);
    }
    if (program.ownerUserId == referredUserId) {
      _audit(referredUserId, ReferralAuditAction.selfAttributionBlocked, now);
      return const ReferralDecision(code: ReferralDecisionCode.selfAttribution);
    }
    if (_repository.findAttributionForUser(referredUserId) != null) {
      _audit(referredUserId, ReferralAuditAction.duplicateBlocked, now);
      return const ReferralDecision(
        code: ReferralDecisionCode.duplicateAttribution,
      );
    }
    final maximum = program.maxAttributions;
    if (maximum != null &&
        _repository.attributionCountForProgram(program.id) >= maximum) {
      return const ReferralDecision(code: ReferralDecisionCode.capacityReached);
    }

    final instant = now.toUtc();
    final attribution = ReferralAttribution(
      id: '${program.id}:$referredUserId',
      programId: program.id,
      referrerUserId: program.ownerUserId,
      referredUserId: referredUserId,
      source: source,
      status: ReferralAttributionStatus.pending,
      attributedAt: instant,
      expiresAt: instant.add(program.attributionWindow),
    );
    _repository.saveAttribution(attribution);
    _audit(attribution.id, ReferralAuditAction.attributed, instant);
    return ReferralDecision(
      code: ReferralDecisionCode.accepted,
      attribution: attribution,
    );
  }

  AffiliateCommission createCommission({
    required ReferralAttribution attribution,
    required String ownerUserId,
    required int basisPoints,
    required int eligibleAmountMinorUnits,
    required DateTime now,
  }) {
    final commission = AffiliateCommission(
      id: 'commission:${attribution.id}',
      attributionId: attribution.id,
      ownerUserId: ownerUserId,
      basisPoints: basisPoints,
      eligibleAmountMinorUnits: eligibleAmountMinorUnits,
      status: AffiliateCommissionStatus.pending,
      createdAt: now.toUtc(),
    );
    _repository.saveCommission(commission);
    _audit(attribution.id, ReferralAuditAction.commissionCreated, now);
    return commission;
  }

  AffiliateCommission revokeCommission(
    AffiliateCommission commission, {
    required DateTime now,
    required String reason,
  }) {
    final revoked = commission.transition(
      AffiliateCommissionStatus.revoked,
      reason: reason,
    );
    _repository.saveCommission(revoked);
    _audit(
      commission.attributionId,
      ReferralAuditAction.commissionRevoked,
      now,
    );
    return revoked;
  }

  void _audit(String subjectId, ReferralAuditAction action, DateTime now) {
    _repository.appendAudit(
      ReferralAuditEvent(
        id: '${action.name}:$subjectId:${now.toUtc().microsecondsSinceEpoch}',
        subjectId: subjectId,
        action: action,
        occurredAt: now.toUtc(),
      ),
    );
  }
}
