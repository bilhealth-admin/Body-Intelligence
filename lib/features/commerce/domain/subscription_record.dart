import 'commerce_plan.dart';
import 'subscription_lifecycle.dart';
import 'subscription_provider.dart';

/// Immutable provider-neutral input used by the entitlement resolver.
final class SubscriptionRecord {
  SubscriptionRecord({
    required this.plan,
    required this.lifecycle,
    required this.authorityVerified,
    this.provider,
    this.startedAt,
    this.currentPeriodEndsAt,
    this.trialEndsAt,
    this.gracePeriodEndsAt,
  }) {
    if (plan == CommercePlan.free && provider != null) {
      throw ArgumentError(
        'Free plan records must not identify a store provider.',
      );
    }
    if (trialEndsAt != null &&
        startedAt != null &&
        trialEndsAt!.isBefore(startedAt!)) {
      throw ArgumentError('trialEndsAt must not be before startedAt.');
    }
    if (currentPeriodEndsAt != null &&
        startedAt != null &&
        currentPeriodEndsAt!.isBefore(startedAt!)) {
      throw ArgumentError('currentPeriodEndsAt must not be before startedAt.');
    }
    if (gracePeriodEndsAt != null &&
        currentPeriodEndsAt != null &&
        gracePeriodEndsAt!.isBefore(currentPeriodEndsAt!)) {
      throw ArgumentError(
        'gracePeriodEndsAt must not be before currentPeriodEndsAt.',
      );
    }
  }

  final CommercePlan plan;
  final SubscriptionLifecycle lifecycle;
  final bool authorityVerified;
  final SubscriptionProvider? provider;
  final DateTime? startedAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? trialEndsAt;
  final DateTime? gracePeriodEndsAt;
}
