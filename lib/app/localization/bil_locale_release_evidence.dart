import 'bil_locale_rollout_manifest.dart';

abstract final class BilLocaleReleaseSurfaces {
  static const required = <String>{
    'auth',
    'dashboard',
    'diary',
    'nutrition',
    'settings',
    'commerce',
    'ai_coach',
    'vision_review',
  };
}

class BilLocaleHumanReviewEvidence {
  const BilLocaleHumanReviewEvidence({
    required this.localeTag,
    required this.reviewer,
    required this.reviewedAt,
    required this.glossaryApproved,
    required this.safetyCopyApproved,
    required this.commerceCopyApproved,
  });

  final String localeTag;
  final String reviewer;
  final DateTime reviewedAt;
  final bool glossaryApproved;
  final bool safetyCopyApproved;
  final bool commerceCopyApproved;

  bool get valid =>
      BilLocaleRolloutManifest.releaseTargets25.contains(localeTag) &&
      reviewer.trim().isNotEmpty &&
      reviewedAt.isUtc &&
      !reviewedAt.isAfter(DateTime.now().toUtc()) &&
      glossaryApproved &&
      safetyCopyApproved &&
      commerceCopyApproved;
}

class BilLocaleDeviceSmokeEvidence {
  const BilLocaleDeviceSmokeEvidence({
    required this.localeTag,
    required this.device,
    required this.operatingSystem,
    required this.testedAt,
    required this.surfaceScreenshots,
    required this.textScales,
  });

  final String localeTag;
  final String device;
  final String operatingSystem;
  final DateTime testedAt;
  final Map<String, String> surfaceScreenshots;
  final Set<double> textScales;

  bool get valid {
    final covered = surfaceScreenshots.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => entry.key)
        .toSet();
    return BilLocaleRolloutManifest.releaseTargets25.contains(localeTag) &&
        device.trim().isNotEmpty &&
        operatingSystem.trim().isNotEmpty &&
        testedAt.isUtc &&
        !testedAt.isAfter(DateTime.now().toUtc()) &&
        covered.containsAll(BilLocaleReleaseSurfaces.required) &&
        textScales.containsAll({1.0, 1.3});
  }
}

class BilLocaleReleaseEvidence {
  const BilLocaleReleaseEvidence({
    required this.humanReview,
    required this.deviceSmoke,
  });

  final BilLocaleHumanReviewEvidence humanReview;
  final BilLocaleDeviceSmokeEvidence deviceSmoke;

  bool get valid =>
      humanReview.valid &&
      deviceSmoke.valid &&
      humanReview.localeTag == deviceSmoke.localeTag;
}
