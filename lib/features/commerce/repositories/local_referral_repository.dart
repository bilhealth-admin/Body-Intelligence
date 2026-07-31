import '../domain/affiliate_commission.dart';
import '../domain/referral_attribution.dart';
import '../domain/referral_audit_event.dart';
import '../domain/referral_program.dart';
import 'referral_repository.dart';

final class LocalReferralRepository implements ReferralRepository {
  final Map<String, ReferralProgram> _programsByCode = {};
  final Map<String, ReferralAttribution> _attributionsByUser = {};
  final Map<String, AffiliateCommission> commissionsById = {};
  final List<ReferralAuditEvent> _audit = [];

  @override
  ReferralProgram? findProgramByCode(String code) =>
      _programsByCode[ReferralProgram.normalizeCode(code)];

  @override
  ReferralAttribution? findAttributionForUser(String referredUserId) =>
      _attributionsByUser[referredUserId];

  @override
  int attributionCountForProgram(String programId) => _attributionsByUser.values
      .where((item) => item.programId == programId)
      .length;

  @override
  void saveProgram(ReferralProgram program) {
    _programsByCode[program.code] = program;
  }

  @override
  void saveAttribution(ReferralAttribution attribution) {
    _attributionsByUser[attribution.referredUserId] = attribution;
  }

  @override
  void saveCommission(AffiliateCommission commission) {
    commissionsById[commission.id] = commission;
  }

  @override
  void appendAudit(ReferralAuditEvent event) => _audit.add(event);

  @override
  List<ReferralAuditEvent> auditForSubject(String subjectId) =>
      List.unmodifiable(_audit.where((event) => event.subjectId == subjectId));
}
