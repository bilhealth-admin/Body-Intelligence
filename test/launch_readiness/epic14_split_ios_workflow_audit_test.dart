import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/epic14_release_audit.dart' as audit;

void main() {
  late String signing;
  late String promotion;

  setUpAll(() {
    signing = File(
      '.github/workflows/bil_ios_signed_release.yml',
    ).readAsStringSync();
    promotion = File(
      '.github/workflows/bil_ios_upload_existing_testflight.yml',
    ).readAsStringSync();
  });

  test('actual separate signing and promotion workflows satisfy the audit', () {
    expect(audit.splitIosReleaseWorkflowIssue(signing, promotion), isNull);
  });

  test('promotion must map the private key; comments cannot supply it', () {
    final changed = promotion.replaceAll(
      r'ASC_PRIVATE_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY_BASE64 }}',
      '# ASC_PRIVATE_KEY_BASE64: '
          r'${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY_BASE64 }}',
    );
    expect(changed, isNot(promotion));
    expect(
      audit.splitIosReleaseWorkflowIssue(signing, changed),
      contains('credential mapping'),
    );
  });

  test('promotion rejects a removed signed receipt digest comparison', () {
    final changed = promotion.replaceAll(
      "receipt['ipa_sha256']==digest",
      'True',
    );
    expect(changed, isNot(promotion));
    expect(audit.splitIosReleaseWorkflowIssue(signing, changed), isNotNull);
  });

  test(
    'promotion rejects a receipt disconnected from the requested source',
    () {
      final changed = promotion.replaceAll(
        "receipt['source_sha']==os.environ['BIL_TESTED_SOURCE']",
        'True',
      );
      expect(changed, isNot(promotion));
      expect(audit.splitIosReleaseWorkflowIssue(signing, changed), isNotNull);
    },
  );

  test('promotion rejects credentials before the source and byte gates', () {
    final changed =
        'env:\n  ASC_KEY_ID: '
        r'${{ secrets.APP_STORE_CONNECT_KEY_ID }}'
        '\n$promotion';
    expect(
      audit.splitIosReleaseWorkflowIssue(signing, changed),
      contains('credentials precede'),
    );
  });

  test('a signing-only workflow cannot acquire an upload command', () {
    expect(
      audit.splitIosReleaseWorkflowIssue(
        '$signing\nrun: xcrun altool --upload-app\n',
        promotion,
      ),
      contains('must not upload'),
    );
  });

  test('promotion cannot rebuild the IPA after its receipt was verified', () {
    expect(
      audit.splitIosReleaseWorkflowIssue(
        signing,
        '$promotion\nrun: flutter build ipa --release\n',
      ),
      contains('verified existing IPA'),
    );
  });

  test('Apple validation cannot be moved after upload', () {
    final changed = promotion
        .replaceAll('altool --validate-app', 'altool --temporary-marker')
        .replaceAll('altool --upload-app', 'altool --validate-app')
        .replaceAll('altool --temporary-marker', 'altool --upload-app');
    expect(
      audit.splitIosReleaseWorkflowIssue(signing, changed),
      contains('validation must precede'),
    );
  });

  test('signing cannot be changed into an automatic push workflow', () {
    final changed = signing.replaceFirst('  workflow_dispatch:', '  push:');
    expect(changed, isNot(signing));
    expect(
      audit.splitIosReleaseWorkflowIssue(changed, promotion),
      contains('manual workflows'),
    );
  });
}
