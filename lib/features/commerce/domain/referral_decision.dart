import 'referral_attribution.dart';

enum ReferralDecisionCode {
  accepted,
  unknownCode,
  inactiveProgram,
  selfAttribution,
  duplicateAttribution,
  capacityReached,
}

final class ReferralDecision {
  const ReferralDecision({required this.code, this.attribution});

  final ReferralDecisionCode code;
  final ReferralAttribution? attribution;

  bool get accepted => code == ReferralDecisionCode.accepted;
}
