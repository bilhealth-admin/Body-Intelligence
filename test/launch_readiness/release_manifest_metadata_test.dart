import 'package:body_intelligence_log/app/environment/release_manifest_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses exact platform release build markers', () {
    final metadata = ReleaseManifestMetadata.parse('''
`STAGING_MANIFEST_COMPLETE: YES`
`CANDIDATE_FROZEN_OR_ACCEPTED: YES`
`UNRESOLVED_REVIEW_COUNT: 0`
`RELEASE_VERSION: 1.0.0`
`RELEASE_BUILD_NUMBER_IOS: 26`
`RELEASE_BUILD_NUMBER_ANDROID: 21`
''');

    expect(metadata.stagingManifestComplete, isTrue);
    expect(metadata.candidateFrozenOrAccepted, isTrue);
    expect(metadata.unresolvedReviewCount, 0);
    expect(metadata.releaseVersion, '1.0.0');
    expect(metadata.releaseBuildNumberIos, 26);
    expect(metadata.releaseBuildNumberAndroid, 21);
  });

  test('missing, negative, or duplicate markers fail closed', () {
    final metadata = ReleaseManifestMetadata.parse('''
`STAGING_MANIFEST_COMPLETE: YES`
`STAGING_MANIFEST_COMPLETE: YES`
`CANDIDATE_FROZEN_OR_ACCEPTED: NO`
`UNRESOLVED_REVIEW_COUNT: 172`
''');

    expect(metadata.stagingManifestComplete, isFalse);
    expect(metadata.candidateFrozenOrAccepted, isFalse);
    expect(metadata.unresolvedReviewCount, 172);
    expect(metadata.releaseVersion, isEmpty);
    expect(metadata.releaseBuildNumber, isNull);
  });
}
