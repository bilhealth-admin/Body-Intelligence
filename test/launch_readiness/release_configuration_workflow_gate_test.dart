import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('iOS no-pub archive cannot consume a stale native ads Swift graph', () {
    final ios = _read('.github/workflows/bil_ios_signed_release.yml');
    final prepare = ios.indexOf('- name: Sanitize retained Swift graph');
    final signing = ios.indexOf('- name: Configure manual App Store');
    final archive = ios.indexOf('- name: Build signed archive');
    final postArchive = ios.indexOf(
      '- name: Verify regenerated iOS native plugin graph',
    );
    expect(prepare, greaterThanOrEqualTo(0));
    expect(signing, greaterThan(prepare));
    expect(archive, greaterThan(signing));
    expect(postArchive, greaterThan(archive));
    final beforeArchive = ios.substring(prepare, signing);
    expect(
      beforeArchive,
      contains('test_sanitize_ios_deferred_ads_swift_package.py'),
    );
    expect(
      beforeArchive,
      contains('sanitize_ios_deferred_ads_swift_package.py --project-root .'),
    );
    expect(
      beforeArchive,
      contains('verify_ios_deferred_ads_plugin_graph.py --project-root .'),
    );
    expect(ios, contains('verify_ios_deferred_ads_artifact.py'));
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
      expect(source, contains('BIL_FACEBOOK_REQUIRED: true'), reason: path);
      expect(
        source,
        contains('BIL_MOBILE_INTEGRITY_REQUIRED: true'),
        reason: path,
      );
    }

    final android = _read(workflows.first);
    final ios = _read(workflows.last);
    expect(android, contains('BIL_ANDROID_V9_AUDITED_SOURCE_SHA'));
    expect(android, contains('BIL_ANDROID_V9_STAGING_MANIFEST_SHA256'));
    expect(ios, contains('BIL_IOS_V11_AUDITED_SOURCE_SHA'));
    expect(ios, contains('BIL_IOS_V11_STAGING_MANIFEST_SHA256'));
    expect(ios, isNot(contains('BIL_PLUS8_AUDITED_SOURCE_SHA')));
    expect(ios, isNot(contains('BIL_PLUS8_STAGING_MANIFEST_SHA256')));
  });

  test('Android validator consumes the current frozen-source manifest', () {
    final source = _read(workflows.first);
    expect(
      source,
      contains(
        'BIL_RELEASE_MANIFEST_PATH: '
        'docs/release/BIL_ANDROID_V9_FROZEN_SOURCE_MANIFEST_2026-09-06.md',
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

  test('iOS validator consumes only the build 11 release manifest', () {
    final source = _read(workflows.last);
    expect(
      source,
      contains(
        'BIL_RELEASE_MANIFEST_PATH: '
        'docs/release/BIL_IOS_V11_FROZEN_SOURCE_MANIFEST_2026-09-09.md',
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
    expect(source, contains('(( BUILD_NUMBER == 11 ))'));
    expect(source, isNot(contains('(( BUILD_NUMBER == 9 ))')));
  });

  test('signed workflows pin actions and stable runner families', () {
    final android = _read(workflows.first);
    final ios = _read(workflows.last);
    const checkout =
        'actions/checkout@11d5960a326750d5838078e36cf38b85af677262';
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
