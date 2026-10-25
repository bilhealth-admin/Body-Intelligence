import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('manual QA workflow resolves runner paths only inside steps', () {
    final source = _read(
      '.github/workflows/bil_ios_plus8_dual_simulator_qa.yml',
    );
    expect(source, isNot(contains(r'${{ runner.temp }}')));
    expect(source, contains('Initialize runner-local QA state path'));
    expect(source, contains('Initialize runner-local watchdog paths'));
    expect(source, contains(r'"$RUNNER_TEMP" >> "$GITHUB_ENV"'));
    expect(source, contains('workflow_dispatch:'));
    expect(source, isNot(contains('\n  push:')));
  });

  test('iOS signed archive retains production Google Mobile Ads', () {
    final ios = _read('.github/workflows/bil_ios_signed_release.yml');
    expect(
      ios,
      contains(
        'dart run tool/release/sanitize_flutter_release_plugins.dart --platform=ios',
      ),
    );
    expect(ios, isNot(contains('--defer-ios-google-mobile-ads')));
    expect(ios, contains("grep -Fq 'google_mobile_ads'"));
    expect(ios, contains("grep -Fq 'FLTGoogleMobileAdsPlugin'"));
    expect(ios, contains('validate_admob_production_configuration.py'));
  });

  const workflows = <String>[
    '.github/workflows/bil_android_release_candidate.yml',
    '.github/workflows/bil_ios_signed_release.yml',
  ];

  test('both signed workflows execute the frozen configuration validator', () {
    for (final path in workflows) {
      final source = _read(path);
      expect(
        source,
        contains('dart run tool/release/validate_release_configuration.dart'),
        reason: path,
      );
      expect(source, contains(r'BIL_SOURCE_COMMIT: ${{ github.sha }}'));
      expect(source, contains(r'BIL_AUDITED_SOURCE_COMMIT: ${{ github.sha }}'));
      final build = path.contains('ios') ? '38' : '33';
      expect(source, contains("BIL_RELEASE_EXPECTED_BUILD_NUMBER: '$build'"));
      expect(source, contains('--verify-ci --platform'));
      expect(
        source.indexOf('bil_candidate_release.py --verify-ci'),
        lessThan(source.indexOf('secrets.')),
      );
      expect(
        source,
        contains('test/features/commerce/app_purchase_confirmation_test.dart'),
        reason: '$path must keep the focused purchase regression gate.',
      );
      expect(
        source,
        contains(
          'test/features/commerce/app_subscription_confirmation_test.dart',
        ),
        reason: '$path must keep the focused subscription regression gate.',
      );
      expect(
        source,
        isNot(contains('run_portable_release_tests.py --code-only')),
        reason: '$path must not duplicate the independent owner suite.',
      );
      expect(source, contains('BIL_FACEBOOK_REQUIRED: true'), reason: path);
      expect(
        source,
        contains('BIL_MOBILE_INTEGRITY_REQUIRED: true'),
        reason: path,
      );
    }

    final guard = _read('tools/qa/bil_candidate_release.py');
    expect(guard, contains("os.environ.get('GITHUB_SHA') != head"));
    expect(guard, contains("os.environ.get('GITHUB_REF_NAME') != BRANCH"));
    expect(guard, contains("git', 'status', '--porcelain'"));
    expect(guard, contains('delivery.validate_prerequisites'));
    expect(guard, contains('delivery.verify_security'));
    expect(
      guard,
      contains('Protected original branch changed; signing is blocked'),
    );
  });

  test('signed build workflows require complete frozen candidate records', () {
    final androidWorkflow = _read(workflows.first);
    final iosWorkflow = _read(workflows.last);
    final androidManifest = _read(
      'docs/release/BIL_ANDROID_V33_REVISED_CANDIDATE_2026-10-22.md',
    );
    final iosManifest = _read(
      'docs/release/BIL_IOS_V38_CANDIDATE_2026-10-22.md',
    );

    expect(androidManifest, contains('RELEASE_BUILD_NUMBER: 33'));
    expect(androidManifest, contains('CANDIDATE_FROZEN_OR_ACCEPTED:'));
    expect(iosManifest, contains('RELEASE_BUILD_NUMBER: 38'));
    expect(iosManifest, contains('CANDIDATE_FROZEN_OR_ACCEPTED:'));
    for (final workflow in <String>[androidWorkflow, iosWorkflow]) {
      expect(workflow, contains('bil_candidate_release.py --verify-ci'));
    }
    final guard = _read('tools/qa/bil_candidate_release.py');
    expect(guard, contains('STAGING_MANIFEST_COMPLETE: YES'));
    expect(guard, contains('CANDIDATE_FROZEN_OR_ACCEPTED: YES'));
    expect(guard, contains('UNRESOLVED_REVIEW_COUNT: 0'));
    expect(guard, contains('text.splitlines().count(line) != 1'));
  });

  test('Android validator consumes the current frozen-source manifest', () {
    final source = _read(workflows.first);
    expect(
      source,
      contains(
        'BIL_RELEASE_MANIFEST_PATH: '
        'docs/release/BIL_ANDROID_V33_REVISED_CANDIDATE_2026-10-22.md',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'BIL_RELEASE_MANIFEST_PATH: '
          'docs/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md',
        ),
      ),
    );
  });

  test('iOS38 manifest selection remains explicit and defaults to strict CI', () {
    final source = _read(workflows.last);
    expect(
      source,
      contains(
        r'BIL_RELEASE_MANIFEST_PATH: ${{ '
        'inputs.internal_testflight_existing_evidence && '
        "'docs/release/BIL_IOS38_INTERNAL_TESTFLIGHT_FREEZE_2026-10-23.md' "
        "|| 'docs/release/BIL_IOS_V38_CANDIDATE_2026-10-22.md' }}",
      ),
    );
    expect(
      source,
      contains(
        '        type: boolean\n'
        '        default: false\n',
      ),
      reason: 'The prior internal-only authorization is never the default.',
    );
    expect(
      source,
      contains(
        r"BIL_VALIDATION_MODE: ${{ inputs.internal_testflight_existing_evidence "
        "&& 'owner_authorized_internal_prior_app_evidence' || 'all_exact_source_ci' }}",
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'BIL_RELEASE_MANIFEST_PATH: '
          'docs/release/BIL_PLUS8_FROZEN_SOURCE_MANIFEST_2026-09-06.md',
        ),
      ),
    );
    expect(source, contains('(( BUILD_NUMBER == 38 ))'));
    expect(source, isNot(contains('(( BUILD_NUMBER == 35 ))')));
  });

  test('signed workflows pin actions and stable runner families', () {
    final android = _read(workflows.first);
    final ios = _read(workflows.last);
    const checkout =
        'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1';
    const flutter =
        'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2';
    const artifact =
        'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02';

    for (final source in <String>[android, ios]) {
      expect(source, contains(checkout));
      expect(source, contains(flutter));
      expect(source, contains(artifact));
      expect(source, isNot(contains('uses: actions/checkout@v')));
      expect(source, isNot(contains('uses: subosito/flutter-action@v')));
      expect(source, isNot(contains('uses: actions/upload-artifact@v')));
    }
    expect(android, contains('runs-on: ubuntu-24.04'));
    expect(
      android,
      contains(
        'reactivecircus/android-emulator-runner@'
        '4c44018e59b437e86cdfc41da381398f93ed8808',
      ),
    );
    expect(ios, contains('runs-on: macos-26'));
  });

  test('validator executable reports only gate status, not bound values', () {
    final source = _read('tool/release/validate_release_configuration.dart');
    final manifestParser = _read(
      'lib/app/environment/release_manifest_metadata.dart',
    );
    expect(source, contains('RELEASE_CONFIGURATION_GATE=PASS'));
    expect(source, contains('AUDITED_SOURCE_COMMIT_GATE=PASS'));
    expect(source, contains('AUDITED_FREEZE_MANIFEST_GATE=PASS'));
    expect(source, contains('FROZEN_MANIFEST_CONTENT_GATE=PASS'));
    expect(manifestParser, contains('CANDIDATE_FROZEN_OR_ACCEPTED'));
    expect(manifestParser, contains('UNRESOLVED_REVIEW_COUNT'));
    expect(manifestParser, contains('RELEASE_BUILD_NUMBER'));
    expect(source, isNot(contains("stdout.writeln(environment")));
    expect(source, isNot(contains("stderr.writeln(environment")));
  });
}
