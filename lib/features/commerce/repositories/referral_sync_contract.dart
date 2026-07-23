import '../domain/affiliate_commission.dart';
import '../domain/referral_attribution.dart';
import '../domain/referral_audit_event.dart';

/// Future cloud/server boundary. No network implementation belongs here.
abstract interface class ReferralSyncContract {
  Future<void> pushAttribution(ReferralAttribution attribution);
  Future<void> pushCommission(AffiliateCommission commission);
  Future<void> pushAuditEvents(List<ReferralAuditEvent> events);
}
