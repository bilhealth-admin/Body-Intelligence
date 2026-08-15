enum WorkoutReleaseAvailability {
  durationValidAwaitingHumanReview,
  durationNonconformant,
  unavailable,
}

/// Metadata-only view of one of the exact 200 release movements.
///
/// A manifest row never grants playback authority. Only the existing trusted
/// content-pack/cache path may turn reviewed, hash-verified media into a
/// playable asset.
class WorkoutReleaseCatalogItem {
  const WorkoutReleaseCatalogItem({
    required this.slot,
    required this.variationId,
    required this.expectedSha256,
    required this.expectedBytes,
    required this.durationMilliseconds,
    required this.frameCount,
    required this.availability,
  });

  final String slot;
  final String variationId;
  final String? expectedSha256;
  final int? expectedBytes;
  final int? durationMilliseconds;
  final int? frameCount;
  final WorkoutReleaseAvailability availability;

  bool get canPlay => false;
}
