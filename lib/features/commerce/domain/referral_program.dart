/// Reward granted to one side of a referral attribution.
final class ReferralReward {
  const ReferralReward({required this.freeDays, required this.creditMinorUnits})
    : assert(freeDays >= 0),
      assert(creditMinorUnits >= 0),
      assert(freeDays > 0 || creditMinorUnits > 0);

  final int freeDays;
  final int creditMinorUnits;
}

/// Immutable referral or affiliate program definition.
final class ReferralProgram {
  ReferralProgram({
    required this.id,
    required String code,
    required this.ownerUserId,
    required this.startsAt,
    required this.endsAt,
    required this.attributionWindow,
    required this.referrerReward,
    required this.newUserReward,
    this.commissionBasisPoints = 0,
    this.maxAttributions,
    this.enabled = true,
  }) : code = normalizeCode(code) {
    if (id.trim().isEmpty || ownerUserId.trim().isEmpty || this.code.isEmpty) {
      throw ArgumentError('Program identity fields must not be empty.');
    }
    if (!endsAt.toUtc().isAfter(startsAt.toUtc())) {
      throw ArgumentError('endsAt must be after startsAt.');
    }
    if (attributionWindow <= Duration.zero) {
      throw ArgumentError('attributionWindow must be positive.');
    }
    if (commissionBasisPoints < 0 || commissionBasisPoints > 10000) {
      throw ArgumentError('commissionBasisPoints must be between 0 and 10000.');
    }
    if (maxAttributions != null && maxAttributions! <= 0) {
      throw ArgumentError('maxAttributions must be positive when provided.');
    }
  }

  final String id;
  final String code;
  final String ownerUserId;
  final DateTime startsAt;
  final DateTime endsAt;
  final Duration attributionWindow;
  final ReferralReward referrerReward;
  final ReferralReward newUserReward;
  final int commissionBasisPoints;
  final int? maxAttributions;
  final bool enabled;

  bool isActiveAt(DateTime instant) {
    final now = instant.toUtc();
    return enabled &&
        !now.isBefore(startsAt.toUtc()) &&
        !now.isAfter(endsAt.toUtc());
  }

  static String normalizeCode(String value) => value.trim().toUpperCase();
}
