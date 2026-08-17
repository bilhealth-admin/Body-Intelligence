/// Stable commercial plan identifiers used across the BIL client boundary.
///
/// The consumer store exposes only [free], [premium], and [premiumAiCoach].
/// [plus] and [pro] are retained solely to read historical server records; no
/// new product may be registered or purchased with either legacy identifier.
enum CommercePlan {
  free,
  premium,
  premiumAiCoach,
  plus,
  pro,
  elite,
  clinic,
  coach,
  enterprise,
}

extension CommercePlanIdentity on CommercePlan {
  String get id => switch (this) {
    CommercePlan.free => 'free',
    CommercePlan.premium => 'premium',
    CommercePlan.premiumAiCoach => 'premium_ai_coach',
    CommercePlan.plus => 'plus',
    CommercePlan.pro => 'pro',
    CommercePlan.elite => 'elite',
    CommercePlan.clinic => 'clinic',
    CommercePlan.coach => 'coach',
    CommercePlan.enterprise => 'enterprise',
  };

  bool get isConsumerTier => switch (this) {
    CommercePlan.free ||
    CommercePlan.premium ||
    CommercePlan.premiumAiCoach => true,
    _ => false,
  };
}
