import 'store_renewal_observation.dart';
import 'subscription_provider.dart';

/// Compatibility adapter for existing Google-only callers/tests.
/// Production display scheduling uses StoreRenewalObservation for both stores.
final class GoogleRenewalObservation extends StoreRenewalObservation {
  const GoogleRenewalObservation({
    required super.ownerId,
    required super.periodEnd,
    required super.verifiedAt,
    super.lineage,
    super.revision,
    super.periodStart,
    super.gracePeriodEnd,
    super.hadAiAllowance,
  });

  static GoogleRenewalObservation? fromObservation(
    StoreRenewalObservation? value,
  ) => value == null || value.provider != SubscriptionProvider.google
      ? null
      : GoogleRenewalObservation(
          ownerId: value.ownerId,
          periodEnd: value.periodEnd,
          verifiedAt: value.verifiedAt,
          lineage: value.lineage,
          revision: value.revision,
          periodStart: value.periodStart,
          gracePeriodEnd: value.gracePeriodEnd,
          hadAiAllowance: value.hadAiAllowance,
        );

  static GoogleRenewalObservation? fromCanonicalRow(
    Map<String, dynamic> row, {
    required String ownerId,
  }) =>
      row['provider'] != 'google' ||
          !const {'active', 'trial'}.contains(row['lifecycle'])
      ? null
      : fromObservation(
          StoreRenewalObservation.fromCanonicalRow(row, ownerId: ownerId),
        );
}
