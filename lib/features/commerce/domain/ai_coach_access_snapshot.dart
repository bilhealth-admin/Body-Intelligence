/// A current successful quota response may prove that all available tokens
/// are reserved-aware prepaid credits. This never grants Premium rights.
final class VerifiedPrepaidAiCredit {
  const VerifiedPrepaidAiCredit._({
    required this.ownerId,
    required this.ownerVisit,
    required this.generation,
    required this.requestedAt,
  });

  static const maximumAge = Duration(seconds: 30);
  final String ownerId;
  final int ownerVisit;
  final int generation;
  final DateTime requestedAt;
  DateTime get expiresAt => requestedAt.add(maximumAge);

  static VerifiedPrepaidAiCredit? fromUsageStatus(
    Object? value, {
    required String ownerId,
    required int ownerVisit,
    required int generation,
    required DateTime requestedAt,
  }) {
    if (ownerId.trim().isEmpty || ownerVisit < 0 || generation < 1) return null;
    if (value is! Map) return null;
    final credits = value['credits'];
    if (credits is! Map) return null;
    final paid = credits['paid_remaining'];
    final included = credits['included_remaining'];
    final total = credits['total_remaining'];
    if (paid is! num ||
        !paid.isFinite ||
        paid <= 0 ||
        included is! num ||
        !included.isFinite ||
        included != 0 ||
        total is! num ||
        !total.isFinite ||
        total != paid) {
      return null;
    }
    return VerifiedPrepaidAiCredit._(
      ownerId: ownerId,
      ownerVisit: ownerVisit,
      generation: generation,
      requestedAt: requestedAt.toUtc(),
    );
  }

  bool current({
    required String? ownerId,
    required int ownerVisit,
    required int generation,
    required DateTime now,
  }) =>
      ownerId == this.ownerId &&
      ownerVisit == this.ownerVisit &&
      generation == this.generation &&
      !now.toUtc().isBefore(requestedAt) &&
      now.toUtc().isBefore(expiresAt);
}

final class AiCoachAccessSnapshotStore {
  bool? verifiedAccess;
  String? verifiedUsagePlan;
  DateTime? usageRequestedAt;
  DateTime? usageObservedAt;
  bool usageResponseFresh = false;
  int generation = 0;
  VerifiedPrepaidAiCredit? prepaidProof;

  bool hasFreshPrepaid({
    required String? ownerId,
    required int ownerVisit,
    required DateTime now,
  }) {
    final proof = prepaidProof;
    final request = usageRequestedAt;
    return verifiedAccess == true &&
        usageResponseFresh &&
        proof != null &&
        request != null &&
        request.isAtSameMomentAs(proof.requestedAt) &&
        proof.current(
          ownerId: ownerId,
          ownerVisit: ownerVisit,
          generation: generation,
          now: now,
        );
  }
}
