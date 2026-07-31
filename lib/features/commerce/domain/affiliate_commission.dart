enum AffiliateCommissionStatus { pending, approved, rejected, paid, revoked }

/// Ledger record only; this package performs no financial transfer.
final class AffiliateCommission {
  const AffiliateCommission({
    required this.id,
    required this.attributionId,
    required this.ownerUserId,
    required this.basisPoints,
    required this.eligibleAmountMinorUnits,
    required this.status,
    required this.createdAt,
    this.reason,
  });

  final String id;
  final String attributionId;
  final String ownerUserId;
  final int basisPoints;
  final int eligibleAmountMinorUnits;
  final AffiliateCommissionStatus status;
  final DateTime createdAt;
  final String? reason;

  int get commissionMinorUnits =>
      (eligibleAmountMinorUnits * basisPoints) ~/ 10000;

  AffiliateCommission transition(
    AffiliateCommissionStatus next, {
    String? reason,
  }) {
    if (status == AffiliateCommissionStatus.paid &&
        next != AffiliateCommissionStatus.paid) {
      throw StateError('Paid commissions are immutable.');
    }
    return AffiliateCommission(
      id: id,
      attributionId: attributionId,
      ownerUserId: ownerUserId,
      basisPoints: basisPoints,
      eligibleAmountMinorUnits: eligibleAmountMinorUnits,
      status: next,
      createdAt: createdAt,
      reason: reason,
    );
  }
}
