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
    expect(workflow, contains('actions/upload-artifact@v4'));
    expect(workflow, contains('UNSIGNED_VALIDATION_ONLY'));
    expect(workflow, isNot(contains('certificate')));
    expect(workflow, isNot(contains('provisioning')));
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
