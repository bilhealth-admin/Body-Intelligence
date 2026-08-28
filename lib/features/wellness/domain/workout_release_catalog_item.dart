enum WorkoutReleaseAvailability {
  approved,
  durationValidAwaitingHumanReview,
  durationNonconformant,
  unavailable,
}

/// Metadata-only view of one of the exact 200 release movements.
///
/// Approval grants catalog playback eligibility. The existing verified
/// content-pack/cache boundary still validates bytes and SHA before playback.
class WorkoutReleaseCatalogItem {
  const WorkoutReleaseCatalogItem({
    required this.bundleId,
    required this.contentPackId,
    required this.assetId,
    required this.exerciseId,
    required this.releaseKey,
    required this.slot,
    required this.objectPath,
    required this.primaryGroupId,
    required this.planGroupIds,
    required this.expectedSha256,
    required this.expectedBytes,
    required this.durationMilliseconds,
    required this.frameCount,
    required this.fpsNumerator,
    required this.fpsDenominator,
    required this.width,
    required this.height,
    required this.codecName,
    required this.availability,
  });

  final String bundleId;
  final String contentPackId;
  final String assetId;
  final String exerciseId;
  final String releaseKey;
  final String slot;
  final String? objectPath;
  final String primaryGroupId;
  final List<String> planGroupIds;
  final String? expectedSha256;
  final int? expectedBytes;
  final int? durationMilliseconds;
  final int? frameCount;
  final int? fpsNumerator;
  final int? fpsDenominator;
  final int? width;
  final int? height;
  final String? codecName;
  final WorkoutReleaseAvailability availability;

  /// Compatibility alias for existing movement-level callers.
  String get variationId => assetId;

  bool get canPlay => availability == WorkoutReleaseAvailability.approved;
}
