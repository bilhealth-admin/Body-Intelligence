import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple cloud build is manual, unsigned, and evidence producing', () {
    final workflow = File(
      '.github/workflows/bil_ios_unsigned_release.yml',
    ).readAsStringSync();
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('runs-on: macos-latest'));
    expect(workflow, contains('flutter build ios --release --no-codesign'));
    expect(
      workflow,
      contains(
        'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
      ),
    );
    expect(workflow, contains('UNSIGNED_VALIDATION_ONLY'));
    expect(workflow, isNot(contains('certificate')));
    expect(workflow, isNot(contains('provisioning')));
  });

  test('both legacy iOS entrypoints use the exact audited toolchain', () {
    for (final path in [
      '.github/workflows/ios_test_build.yml',
      '.github/workflows/bil_ios_unsigned_release.yml',
    ]) {
      final workflow = File(path).readAsStringSync();
      expect(workflow, contains("flutter-version: '3.44.6'"));
      expect(
        workflow,
        contains(
          'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
        ),
      );
      expect(workflow, contains('persist-credentials: false'));
      expect(workflow, isNot(contains('git clone --depth 1 --branch stable')));
    }
  });

  test('documentation prohibits false IPA and signing claims', () {
    final doc = File(
      'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_004_APPLE_CLOUD_BUILD.md',
    ).readAsStringSync();
    expect(doc, contains('not a distributable IPA'));
    expect(doc, contains('protected secrets'));
    expect(doc, contains('successful remote'));
    expect(doc, contains('downloaded artifact evidence'));
  });
}
