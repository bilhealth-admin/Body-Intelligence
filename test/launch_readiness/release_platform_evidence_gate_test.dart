import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String get _python => Platform.isWindows ? 'python' : 'python3';

void main() {
  const iosWorkflow = '.github/workflows/bil_ios_signed_release.yml';
  const androidWorkflow = '.github/workflows/bil_android_release_candidate.yml';
  const appleGate = 'tool/release/verify_apple_release_toolchain.py';
  const androidGate = 'tool/release/verify_android_16k_alignment.py';
  const androidTargetSdkGate = 'tool/release/verify_android_target_sdk.py';
  const associationGenerator = 'tool/release/generate_app_link_associations.py';

  test('Apple gate validates the selected Xcode and iPhoneOS SDK at 26+', () {
    final workflow = _read(iosWorkflow);
    final verifier = _read(appleGate);

    expect(workflow, contains('Verify selected Xcode 26+ and iOS SDK 26+'));
    expect(workflow, contains('verify_apple_release_toolchain.py'));
    expect(workflow, contains('BIL-apple-release-toolchain.txt'));
    expect(workflow, contains('BIL-apple-release-toolchain.json'));
    expect(workflow, contains('bil-ios-toolchain-evidence-'));
    expect(workflow, isNot(contains('xcode-select -s')));
    expect(workflow, isNot(contains('/Applications/Xcode_')));

    expect(verifier, contains('MINIMUM_XCODE_MAJOR = 26'));
    expect(verifier, contains('MINIMUM_IOS_SDK_MAJOR = 26'));
    expect(verifier, contains('developer.apple.com/app-store/submitting'));
    expect(verifier, contains('["xcode-select", "-p"]'));
    expect(verifier, contains('["xcodebuild", "-version"]'));
    expect(
      verifier,
      contains('["xcrun", "--sdk", "iphoneos", "--show-sdk-version"]'),
    );
    expect(verifier, contains('APPLE_RELEASE_TOOLCHAIN_GATE={status}'));
    expect(verifier, contains('APPLE_RELEASE_TOOLCHAIN_GATE=PASS'));
  });

  test('iOS profile and signed-app gates require the production applink', () {
    final workflow = _read(iosWorkflow);
    final signedVerifier = _read(
      'tool/release/verify_signed_ios_entitlements.py',
    );

    for (final source in <String>[workflow, signedVerifier]) {
      expect(source, contains('com.apple.developer.associated-domains'));
      expect(source, contains('applinks:www.bilhealth.com'));
    }
  });

  test('iOS evidence is extracted and verified from the exported IPA app', () {
    final workflow = _read(iosWorkflow);
    final signedVerifier = _read(
      'tool/release/verify_signed_ios_entitlements.py',
    );

    expect(workflow, contains('unzip -qq "\$IPA" -d "\$SIGNED_IPA_DIR"'));
    expect(workflow, contains('"\$SIGNED_IPA_DIR/Payload"'));
    expect(
      workflow,
      contains('codesign --verify --deep --strict --verbose=4 "\$SIGNED_APP"'),
    );
    expect(workflow, contains('"\$SIGNED_APP/embedded.mobileprovision"'));
    expect(workflow, contains('security cms -D -i "\$EMBEDDED_PROFILE"'));
    expect(
      workflow,
      contains('--embedded-profile BIL-ios-embedded-profile.plist'),
    );
    expect(workflow, contains('BIL-ios-codesign-verify.txt'));
    expect(workflow, contains('SIGNED_IPA_CODESIGN_GATE=PASS'));
    expect(workflow, contains('BIL-ios-embedded-profile.plist'));
    expect(
      workflow,
      isNot(
        contains(
          'build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app',
        ),
      ),
    );
    expect(signedVerifier, contains('SIGNED_IPA_EMBEDDED_PROFILE_GATE=PASS'));
    expect(signedVerifier, contains('profile.get("TeamIdentifier")'));
    expect(signedVerifier, contains('profile.get("ExpirationDate")'));
  });

  test('final AAB gate pins official bundletool by version and digest', () {
    final workflow = _read(androidWorkflow);

    expect(workflow, contains('BUNDLETOOL_VERSION=1.18.3'));
    expect(
      workflow,
      contains(
        'BUNDLETOOL_SHA256='
        'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29',
      ),
    );
    expect(
      workflow,
      contains('https://github.com/google/bundletool/releases/download/'),
    );
    expect(workflow, contains('Pinned official bundletool checksum mismatch'));
    expect(workflow, contains('verify_android_16k_alignment.py'));
    expect(
      workflow,
      contains('build/app/outputs/bundle/release/app-release.aab'),
    );
  });

  test('final AAB gate proves bundle and every ELF LOAD alignment', () {
    final workflow = _read(androidWorkflow);
    final verifier = _read(androidGate);

    expect(verifier, contains('REQUIRED_BUNDLE_PAGE_ALIGNMENT'));
    expect(verifier, contains('PAGE_ALIGNMENT_16K'));
    expect(verifier, contains('PAGE_ALIGNMENT_4K'));
    expect(
      verifier,
      contains('developer.android.com/guide/practices/page-sizes'),
    );
    expect(verifier, contains('"dump", "config"'));
    expect(verifier, contains('"validate"'));
    expect(verifier, contains('MINIMUM_ELF_LOAD_ALIGNMENT_BYTES = 16 * 1024'));
    expect(verifier, contains('[readelf, "-lW", str(extracted)]'));
    expect(verifier, contains('if minimum < MINIMUM_ELF_LOAD_ALIGNMENT_BYTES'));
    expect(verifier, contains('if not native_entries'));

    expect(workflow, contains('BIL-android-16k-bundletool.txt'));
    expect(workflow, contains('BIL-android-16k-elf.txt'));
    expect(workflow, contains('BIL-android-16k-summary.json'));
    expect(workflow, contains('bil-android-16k-evidence-'));
    expect(workflow, contains('if-no-files-found: error'));
  });

  test('final AAB manifest must prove targetSdkVersion 36', () {
    final workflow = _read(androidWorkflow);
    final verifier = _read(androidTargetSdkGate);

    expect(workflow, contains('java -jar "\$BUNDLETOOL_JAR" dump manifest'));
    expect(workflow, contains('--bundle="\$AAB"'));
    expect(workflow, contains('--module=base'));
    expect(workflow, contains('BIL-android-base-manifest.xml'));
    expect(workflow, contains('verify_android_target_sdk.py'));
    expect(workflow, contains('BIL-android-target-sdk.txt'));
    expect(workflow, contains('BIL-android-target-sdk.json'));
    expect(verifier, contains('EXPECTED_TARGET_SDK = 36'));
    expect(verifier, contains('ANDROID_FINAL_AAB_TARGET_SDK_GATE=PASS'));
  });

  test('association documents require real inputs and cannot SPA-fallback', () {
    final generator = _read(associationGenerator);
    final worker = _read('tool/release/bilhealth_site_worker.mjs');
    final wrangler = _read('wrangler.site.jsonc');
    final gitignore = _read('.gitignore');

    expect(generator, contains('OWNER_INPUT_REQUIRED: APPLE_TEAM_ID'));
    expect(
      generator,
      contains('OWNER_INPUT_REQUIRED: PLAY_APP_SIGNING_SHA256'),
    );
    expect(generator, contains('Play Console > App integrity'));
    expect(generator, contains('APP_LINK_PATHS'));
    expect(generator, isNot(contains('APPLE_TEAM_ID =')));
    expect(generator, isNot(contains('PLAY_APP_SIGNING_SHA256 =')));

    expect(wrangler, contains('"binding": "ASSETS"'));
    expect(wrangler, contains('"run_worker_first": ["/.well-known/*"]'));
    expect(worker, contains("sourceType.includes('text/html')"));
    expect(worker, contains("url.pathname.startsWith('/.well-known/')"));
    expect(worker, contains('return failClosed(404'));
    expect(
      gitignore,
      contains('public_site/.well-known/apple-app-site-association'),
    );
    expect(gitignore, contains('public_site/.well-known/assetlinks.json'));
  });

  test('well-known Worker behavior fails closed under Node', () {
    final result = Process.runSync('node', <String>[
      '--test',
      'tool/release/bilhealth_site_worker.test.mjs',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('portable release gate parsers reject ambiguous and 4 KB evidence', () {
    for (final script in <String>[
      appleGate,
      androidGate,
      androidTargetSdkGate,
      associationGenerator,
    ]) {
      final result = Process.runSync(_python, <String>[script, '--self-test']);
      expect(
        result.exitCode,
        0,
        reason: '$script\n${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('SELF_TEST=PASS'));
    }
  });
}
