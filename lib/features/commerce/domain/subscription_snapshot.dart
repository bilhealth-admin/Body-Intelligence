import 'subscription_record.dart';

/// Persisted, previously verified subscription facts and their freshness data.
final class SubscriptionSnapshot {
  SubscriptionSnapshot({
    required this.record,
    required this.verifiedAt,
    required this.persistedAt,
  }) {
    if (!record.authorityVerified) {
      throw ArgumentError('Only verified subscription records may be cached.');
    }
    if (persistedAt.toUtc().isBefore(verifiedAt.toUtc())) {
      throw ArgumentError('persistedAt must not be before verifiedAt.');
    }
  }

  final SubscriptionRecord record;
  final DateTime verifiedAt;
  final DateTime persistedAt;
}
