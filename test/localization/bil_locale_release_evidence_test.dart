import 'package:body_intelligence_log/app/localization/bil_locale_release_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
  final screenshots = {
    for (final surface in BilLocaleReleaseSurfaces.required)
      surface: 'artifacts/locale-smoke/de/$surface.png',
  };

  test(
    'release evidence requires human specialty approvals and full smoke',
    () {
      final evidence = BilLocaleReleaseEvidence(
        humanReview: BilLocaleHumanReviewEvidence(
          localeTag: 'de',
          reviewer: 'reviewer-id',
          reviewedAt: testedAt,
          glossaryApproved: true,
          safetyCopyApproved: true,
          commerceCopyApproved: true,
        ),
        deviceSmoke: BilLocaleDeviceSmokeEvidence(
          localeTag: 'de',
          device: 'Pixel 7',
          operatingSystem: 'Android 15',
          testedAt: testedAt,
          surfaceScreenshots: screenshots,
          textScales: {1.0, 1.3},
        ),
      );
      expect(evidence.valid, isTrue);
    },
  );

  test('missing one surface or review discipline fails closed', () {
    final incompleteScreenshots = Map<String, String>.from(screenshots)
      ..remove('commerce');
    final review = BilLocaleHumanReviewEvidence(
      localeTag: 'de',
      reviewer: 'reviewer-id',
      reviewedAt: testedAt,
      glossaryApproved: true,
      safetyCopyApproved: false,
      commerceCopyApproved: true,
    );
    final smoke = BilLocaleDeviceSmokeEvidence(
      localeTag: 'de',
      device: 'Pixel 7',
      operatingSystem: 'Android 15',
      testedAt: testedAt,
      surfaceScreenshots: incompleteScreenshots,
      textScales: {1.0},
    );
    expect(review.valid, isFalse);
    expect(smoke.valid, isFalse);
    expect(
      BilLocaleReleaseEvidence(humanReview: review, deviceSmoke: smoke).valid,
      isFalse,
    );
  });

  test('mismatched locale evidence cannot promote either locale', () {
    final review = BilLocaleHumanReviewEvidence(
      localeTag: 'de',
      reviewer: 'reviewer-id',
      reviewedAt: testedAt,
      glossaryApproved: true,
      safetyCopyApproved: true,
      commerceCopyApproved: true,
    );
    final smoke = BilLocaleDeviceSmokeEvidence(
      localeTag: 'it',
      device: 'iPhone 15',
      operatingSystem: 'iOS 18',
      testedAt: testedAt,
      surfaceScreenshots: screenshots,
      textScales: {1.0, 1.3},
    );
    expect(
      BilLocaleReleaseEvidence(humanReview: review, deviceSmoke: smoke).valid,
      isFalse,
    );
  });

  test('unknown or generic regional tags cannot create release evidence', () {
    final review = BilLocaleHumanReviewEvidence(
      localeTag: 'pt',
      reviewer: 'reviewer-id',
      reviewedAt: testedAt,
      glossaryApproved: true,
      safetyCopyApproved: true,
      commerceCopyApproved: true,
    );
    final smoke = BilLocaleDeviceSmokeEvidence(
      localeTag: 'zh',
      device: 'Pixel 7',
      operatingSystem: 'Android 15',
      testedAt: testedAt,
      surfaceScreenshots: screenshots,
      textScales: {1.0, 1.3},
    );
    expect(review.valid, isFalse);
    expect(smoke.valid, isFalse);
  });
}
