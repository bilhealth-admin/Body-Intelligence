import 'subscription_provider.dart';

bool storeRenewalTerminalLifecycle(String lifecycle, Object? autoRenews) =>
    const {
      'inactive',
      'pending',
      'cancelled',
      'refunded',
      'revoked',
      'accountHold',
      'paused',
      'suspended',
      'deferred',
    }.contains(lifecycle) ||
    (lifecycle == 'expired' && autoRenews != true);

/// Session-only display/read scheduling metadata, never financial authority.
/// No serializer exists and no entitlement/cache duration is changed by it.
class StoreRenewalObservation {
  const StoreRenewalObservation({
    required this.ownerId,
    required this.periodEnd,
    required this.verifiedAt,
    this.provider = SubscriptionProvider.google,
    this.periodStart,
    this.gracePeriodEnd,
    this.lineage,
    this.revision,
    this.hadAiAllowance = false,
  });
  final String ownerId;
  final SubscriptionProvider provider;
  final DateTime? periodStart;
  final DateTime periodEnd;
  final DateTime? gracePeriodEnd;
  final DateTime verifiedAt;
  final String? lineage;
  final int? revision;
  final bool hadAiAllowance;

  DateTime get boundary => gracePeriodEnd ?? periodEnd;
  String get periodKey =>
      '$ownerId|${provider.name}|${lineage ?? ""}|${boundary.toUtc().microsecondsSinceEpoch}';
  bool pendingAt(DateTime now) =>
      !boundary.toUtc().isAfter(now.toUtc()) ||
      (periodStart?.toUtc().isAfter(now.toUtc()) ?? false);

  static StoreRenewalObservation? fromCanonicalRow(
    Map<String, dynamic> row, {
    required String ownerId,
  }) {
    final provider = switch (row['provider']) {
      'google' => SubscriptionProvider.google,
      'apple' => SubscriptionProvider.apple,
      _ => null,
    };
    if (row['owner_id'] != ownerId ||
        provider == null ||
        !const {
          'active',
          'trial',
          'grace_period',
          'billing_retry',
          'expired',
        }.contains(row['lifecycle']) ||
        row['auto_renews'] != true) {
      return null;
    }
    final end = DateTime.tryParse('${row['expires_at']}')?.toUtc();
    final verified = DateTime.tryParse('${row['verified_at']}')?.toUtc();
    final start = row['started_at'] == null
        ? null
        : DateTime.tryParse('${row['started_at']}')?.toUtc();
    final grace = row['grace_period_ends_at'] == null
        ? null
        : DateTime.tryParse('${row['grace_period_ends_at']}')?.toUtc();
    if (end == null ||
        verified == null ||
        (row['started_at'] != null && start == null) ||
        (start != null && !end.isAfter(start)) ||
        (row['lifecycle'] == 'grace_period' &&
            (grace == null || grace.isBefore(end)))) {
      return null;
    }
    final lineage = row['original_transaction_id'];
    final revision = row['revision'];
    if ((revision != null && (revision is! int || revision < 0)) ||
        (lineage != null && lineage is! String)) {
      return null;
    }
    return StoreRenewalObservation(
      ownerId: ownerId,
      provider: provider,
      periodStart: start,
      periodEnd: end,
      gracePeriodEnd: row['lifecycle'] == 'grace_period' ? grace : null,
      verifiedAt: verified,
      lineage: lineage is String && lineage.isNotEmpty ? lineage : null,
      revision: revision is int && revision >= 0 ? revision : null,
      hadAiAllowance: row['plan_id'] == 'premium_ai_coach',
    );
  }
}
