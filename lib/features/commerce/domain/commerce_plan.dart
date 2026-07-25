/// Stable commercial plan identifiers used across the BIL client boundary.
///
/// Only [free] is active in this package. The remaining identifiers reserve the
/// roadmap vocabulary without making those plans purchasable or entitled.
enum CommercePlan { free, plus, pro, elite, clinic, coach, enterprise }

extension CommercePlanIdentity on CommercePlan {
  String get id => switch (this) {
    CommercePlan.free => 'free',
    CommercePlan.plus => 'plus',
    CommercePlan.pro => 'pro',
    CommercePlan.elite => 'elite',
    CommercePlan.clinic => 'clinic',
    CommercePlan.coach => 'coach',
    CommercePlan.enterprise => 'enterprise',
  };
}
