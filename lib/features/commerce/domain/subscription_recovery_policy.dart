/// Explicit policy for deterministic offline subscription recovery.
final class SubscriptionRecoveryPolicy {
  SubscriptionRecoveryPolicy({required this.maximumOfflineAge})
    : assert(!maximumOfflineAge.isNegative);

  final Duration maximumOfflineAge;

  bool isStale({required DateTime verifiedAt, required DateTime now}) {
    final age = now.toUtc().difference(verifiedAt.toUtc());
    return age.isNegative || age > maximumOfflineAge;
  }
}
