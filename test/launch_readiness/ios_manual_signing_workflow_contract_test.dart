import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const workflowPath = '.github/workflows/bil_ios_signed_release.yml';

  test('iOS archive is forced to manual App Store distribution signing', () {
    final source = File(workflowPath).readAsStringSync();

    expect(source, contains('Configure manual App Store distribution signing'));
    expect(source, contains("PlistBuddy -c 'Print :Name'"));
    expect(source, contains("PlistBuddy -c 'Print :UUID'"));
    expect(source, contains('CODE_SIGN_STYLE = Manual'));
    expect(
      source,
      contains('CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution'),
    );
    expect(source, contains('PROVISIONING_PROFILE_SPECIFIER = %s'));
    expect(source, contains('PROVISIONING_PROFILE = %s'));
    expect(source, contains('IOS_MANUAL_DISTRIBUTION_SIGNING_GATE=PASS'));
  });

  test('IPA export uses a fail-closed explicit distribution profile map', () {
    final source = File(workflowPath).readAsStringSync();

    expect(source, contains("'method': 'app-store-connect'"));
    expect(source, contains("'signingStyle': 'manual'"));
    expect(source, contains("'signingCertificate': 'Apple Distribution'"));
    expect(
      source,
      contains("'com.bilhealth.bodyintelligencelog': profile_uuid"),
    );
    expect(source, contains("'manageAppVersionAndBuildNumber': False"));
    expect(
      source,
      contains(
        '--export-options-plist "\$RUNNER_TEMP/BIL-export-options.plist"',
      ),
    );
    expect(source, isNot(contains('--export-method app-store')));
  });

  test('resolved Xcode release settings are checked before archiving', () {
    final source = File(workflowPath).readAsStringSync();

    expect(source, contains('-workspace ios/Runner.xcworkspace'));
    expect(source, contains('-configuration Release'));
    expect(source, contains('-sdk iphoneos'));
    expect(source, contains('-showBuildSettings'));
    expect(source, contains("grep -Fq 'CODE_SIGN_STYLE = Manual'"));
    expect(
      source,
      contains("grep -Fq 'CODE_SIGN_IDENTITY = Apple Distribution'"),
    );
    expect(source, contains('grep -Fq "DEVELOPMENT_TEAM = \$APPLE_TEAM_ID"'));
  });

  test('signed IPA entitlements use literal plist keys instead of key paths', () {
    final source = File(workflowPath).readAsStringSync();

    expect(source, contains('codesign -d --entitlements -'));
    expect(source, contains("plistlib.load(handle)"));
    expect(
      source,
      contains("entitlements.get('com.apple.developer.healthkit')"),
    );
    expect(
      source,
      contains("entitlements.get('com.apple.developer.applesignin', [])"),
    );
    expect(source, contains("entitlements.get('aps-environment')"));
    expect(source, contains("entitlements.get('get-task-allow', False)"));
    expect(source, contains('SIGNED_IPA_ENTITLEMENTS_GATE=PASS'));
    expect(
      source,
      isNot(contains('plutil -extract com.apple.developer.healthkit')),
    );
  });
}
