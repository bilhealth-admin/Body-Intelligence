import '../domain/affiliate_commission.dart';
import '../domain/referral_attribution.dart';
import '../domain/referral_audit_event.dart';
import '../domain/referral_program.dart';

abstract interface class ReferralRepository {
  ReferralProgram? findProgramByCode(String code);
  ReferralAttribution? findAttributionForUser(String referredUserId);
  int attributionCountForProgram(String programId);
  void saveProgram(ReferralProgram program);
  void saveAttribution(ReferralAttribution attribution);
  void saveCommission(AffiliateCommission commission);
  void appendAudit(ReferralAuditEvent event);
  List<ReferralAuditEvent> auditForSubject(String subjectId);
}
