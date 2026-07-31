enum ReferralAttributionSource { referral, celebrity, blogger, affiliate }

enum ReferralAttributionStatus { pending, confirmed, rejected, revoked }

/// Deterministic local attribution between a new user and a program owner.
final class ReferralAttribution {
  const ReferralAttribution({
    required this.id,
    required this.programId,
    required this.referrerUserId,
    required this.referredUserId,
    required this.source,
    required this.status,
    required this.attributedAt,
    required this.expiresAt,
  });

  final String id;
  final String programId;
  final String referrerUserId;
  final String referredUserId;
  final ReferralAttributionSource source;
  final ReferralAttributionStatus status;
  final DateTime attributedAt;
  final DateTime expiresAt;

  bool get isSelfAttribution => referrerUserId == referredUserId;
  bool isExpiredAt(DateTime instant) =>
      instant.toUtc().isAfter(expiresAt.toUtc());
}
