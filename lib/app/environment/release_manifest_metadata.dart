class ReleaseManifestMetadata {
  const ReleaseManifestMetadata({
    required this.stagingManifestComplete,
    required this.candidateFrozenOrAccepted,
    required this.unresolvedReviewCount,
    required this.releaseVersion,
    required this.releaseBuildNumber,
  });

  factory ReleaseManifestMetadata.parse(String source) {
    String? marker(String name) {
      final expression = RegExp(
        '^`?$name:\\s*([^`\\r\\n]+)`?\\s*\$',
        multiLine: true,
      );
      final matches = expression.allMatches(source).toList(growable: false);
      if (matches.length != 1) return null;
      return matches.single.group(1)?.trim();
    }

    bool yesMarker(String name) => marker(name)?.toUpperCase() == 'YES';

    return ReleaseManifestMetadata(
      stagingManifestComplete: yesMarker('STAGING_MANIFEST_COMPLETE'),
      candidateFrozenOrAccepted: yesMarker('CANDIDATE_FROZEN_OR_ACCEPTED'),
      unresolvedReviewCount: int.tryParse(
        marker('UNRESOLVED_REVIEW_COUNT') ?? '',
      ),
      releaseVersion: marker('RELEASE_VERSION') ?? '',
      releaseBuildNumber: int.tryParse(marker('RELEASE_BUILD_NUMBER') ?? ''),
    );
  }

  final bool stagingManifestComplete;
  final bool candidateFrozenOrAccepted;
  final int? unresolvedReviewCount;
  final String releaseVersion;
  final int? releaseBuildNumber;
}
