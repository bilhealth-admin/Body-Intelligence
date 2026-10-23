import 'dart:io';

Never _fail(String message) {
  stderr.writeln('EPIC14_RELEASE_AUDIT=FAIL');
  stderr.writeln(message);
  exit(1);
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing release file: $path');
  return file.readAsStringSync();
}

void _requires(String body, String value, String path) {
  if (!body.contains(value)) _fail('$path missing: $value');
}

String _releaseVersion(String pubspec) {
  final match = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)\s*(?:#.*)?$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) _fail('pubspec.yaml has no canonical release version.');
  return match.group(1)!;
}

bool debugPushEnvironmentIsValid(String entitlements) {
  final key = RegExp(r'<key>\s*aps-environment\s*</key>');
  if (!key.hasMatch(entitlements)) return true;
  final entries = RegExp(
    r'<key>\s*aps-environment\s*</key>\s*<string>\s*([^<]+?)\s*</string>',
  ).allMatches(entitlements).toList();
  return key.allMatches(entitlements).length == 1 &&
      entries.length == 1 &&
      entries.single.group(1)?.trim() == 'development';
}

String? splitIosReleaseWorkflowIssue(String signedIos, String uploadIos) {
  String source(String text) => text
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');
  final build = source(signedIos);
  final upload = source(uploadIos);
  const ciGate =
      'bil_candidate_release.py --verify-ci --platform ios --expected-head';
  for (final workflow in [build, upload]) {
    if (!RegExp(
          r'^  workflow_dispatch:\s*$',
          multiLine: true,
        ).hasMatch(workflow) ||
        RegExp(
          r'^\s+(?:push|pull_request|workflow_run):',
          multiLine: true,
        ).hasMatch(workflow)) {
      return 'iOS signing and promotion must remain manual workflows';
    }
    if (!workflow.contains(ciGate)) {
      return 'iOS workflow is missing the exact-source CI gate';
    }
  }
  for (final value in [
    'APPLE_DISTRIBUTION_CERTIFICATE_BASE64',
    'APPLE_PROVISIONING_PROFILE_BASE64',
    'APPLE_TEAM_ID',
    'flutter build ipa --release',
    'BIL-ios-build-only-receipt.json',
    'SIGNED_IPA_BUILT_AND_LOCALLY_VERIFIED',
    "'testflight_upload':'NOT_RUN'",
  ]) {
    if (!build.contains(value)) return 'signed iOS workflow missing: $value';
  }
  if (build.contains('altool --upload-app')) {
    return 'signing workflow must not upload to TestFlight';
  }
  if (build.indexOf(ciGate) > build.indexOf('secrets.APPLE_')) {
    return 'signing credentials precede the exact-source CI gate';
  }
  for (final name in ['KEY_ID', 'ISSUER_ID', 'PRIVATE_KEY_BASE64']) {
    final mapping = RegExp(
      r'^\s+ASC_' +
          name +
          r': \$\{\{ secrets\.APP_STORE_CONNECT_' +
          name +
          r' \}\}$',
      multiLine: true,
    );
    if (!mapping.hasMatch(upload)) {
      return 'TestFlight workflow missing credential mapping: $name';
    }
  }
  for (final value in [
    'BIL-ios-build-only-receipt.json',
    "receipt['status']=='SIGNED_IPA_BUILT_AND_LOCALLY_VERIFIED'",
    "receipt['source_sha']==os.environ['BIL_TESTED_SOURCE']",
    "receipt['ipa_sha256']==digest",
    "digest==os.environ['BIL_IPA_SHA256']",
    'SIGNED_IPA_CODESIGN_GATE=PASS',
    'SIGNED_IPA_FORBIDDEN_CRYPTO_MARKERS=0',
    'altool --validate-app',
    'altool --upload-app',
  ]) {
    if (!upload.contains(value)) return 'TestFlight workflow missing: $value';
  }
  final credentials = upload.indexOf('secrets.APP_STORE_CONNECT_');
  if (upload.indexOf(ciGate) > credentials ||
      upload.indexOf("receipt['ipa_sha256']==digest") > credentials) {
    return 'TestFlight credentials precede CI or signed-byte verification';
  }
  if (upload.contains('flutter build ipa')) {
    return 'TestFlight promotion must use the verified existing IPA';
  }
  if (upload.indexOf('altool --validate-app') >
      upload.indexOf('altool --upload-app')) {
    return 'Apple validation must precede upload';
  }
  return null;
}

void main() {
  final pubspec = _read('pubspec.yaml');
  final releaseVersion = _releaseVersion(pubspec);
  final candidateGate = _read(
    'docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md',
  );
  _requires(
    candidateGate,
    'Version metadata: `$releaseVersion`',
    'release candidate gate',
  );
  final appGradle = _read('android/app/build.gradle.kts');
  final settings = _read('android/settings.gradle.kts');
  final properties = _read('android/gradle.properties');
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final ignores = _read('.gitignore') + _read('android/.gitignore');
  final info = _read('ios/Runner/Info.plist');
  final entitlements = _read('ios/Runner/Runner.entitlements');
  final debugEntitlements = _read('ios/Runner/RunnerDebug.entitlements');
  final privacy = _read('ios/Runner/PrivacyInfo.xcprivacy');
  final project = _read('ios/Runner.xcodeproj/project.pbxproj');

  for (final pair in <(String, String)>[
    (appGradle, 'applicationId = "com.bilhealth.bodyintelligencelog"'),
    (appGradle, 'namespace = "com.bilhealth.bodyintelligencelog"'),
    (appGradle, 'compileSdk = 36'),
    (appGradle, 'targetSdk = 36'),
    (appGradle, 'minSdk = 26'),
    (appGradle, 'isMinifyEnabled = true'),
    (appGradle, 'isShrinkResources = true'),
    (appGradle, 'proguard-rules.pro'),
    (appGradle, 'abiFilters += listOf("arm64-v8a", "x86_64")'),
    (appGradle, 'excludes += setOf("**/armeabi-v7a/**")'),
    (settings, 'com.android.application") version "9.0.1"'),
    (properties, 'android.builtInKotlin=false'),
    (manifest, 'android:allowBackup="false"'),
    (manifest, 'android:usesCleartextTraffic="false"'),
    (manifest, 'android:usesPermissionFlags="neverForLocation"'),
    (project, 'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;'),
    (project, 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;'),
    (project, 'PrivacyInfo.xcprivacy in Resources'),
    (info, 'NSHealthShareUsageDescription'),
    (info, 'NSHealthUpdateUsageDescription'),
    (info, 'NSMicrophoneUsageDescription'),
    (info, 'NSSpeechRecognitionUsageDescription'),
    (entitlements, '<key>aps-environment</key>'),
    (entitlements, '<key>com.apple.developer.healthkit</key>'),
    (debugEntitlements, '<key>com.apple.developer.healthkit</key>'),
    (privacy, '<key>NSPrivacyTracking</key><false/>'),
  ]) {
    if (!pair.$1.contains(pair.$2)) {
      _fail('Missing release contract: ${pair.$2}');
    }
  }
  if (!debugPushEnvironmentIsValid(debugEntitlements)) {
    _fail('Debug APNs must be absent or use the development environment.');
  }

  for (final secretPattern in <String>[
    'key.properties',
    '*.jks',
    '*.keystore',
  ]) {
    _requires(ignores, secretPattern, '.gitignore');
  }

  final androidWorkflow = _read(
    '.github/workflows/bil_android_release_candidate.yml',
  );
  final unsignedIos = _read('.github/workflows/bil_ios_unsigned_release.yml');
  final signedIos = _read('.github/workflows/bil_ios_signed_release.yml');
  for (final value in <String>[
    'flutter build appbundle --release --no-pub',
    'jarsigner -verify',
    'ANDROID_KEYSTORE_BASE64',
  ]) {
    _requires(androidWorkflow, value, 'Android workflow');
  }
  for (final value in <String>[
    'flutter build ios --release --no-codesign',
    'UNSIGNED_VALIDATION_ONLY',
    'plutil -lint ios/Runner/PrivacyInfo.xcprivacy',
  ]) {
    _requires(unsignedIos, value, 'unsigned iOS workflow');
  }

  final ownerInputs = _read('docs/release/BIL_EPIC14_OWNER_INPUTS.json');
  if (!ownerInputs.contains('OWNER_INPUT_REQUIRED') ||
      ownerInputs.contains('https://example.com')) {
    _fail('Owner input registry is missing or contains a fabricated URL.');
  }
  final officialRequirements = _read(
    'docs/release/BIL_EPIC14_OFFICIAL_REQUIREMENTS.md',
  );
  for (final authority in <String>[
    'developer.android.com/google/play/requirements/target-sdk',
    'developer.android.com/guide/practices/page-sizes',
    'developer.apple.com/documentation/bundleresources/privacy-manifest-files',
  ]) {
    _requires(officialRequirements, authority, 'official requirements');
  }
  final uploadIos = _read(
    '.github/workflows/bil_ios_upload_existing_testflight.yml',
  );
  final iosWorkflowIssue = splitIosReleaseWorkflowIssue(signedIos, uploadIos);
  if (iosWorkflowIssue != null) _fail(iosWorkflowIssue);

  const allowedHealthPermissions = <String>{
    'READ_STEPS',
    'READ_DISTANCE',
    'READ_ACTIVE_CALORIES_BURNED',
  };
  for (final fitnessPermission in allowedHealthPermissions) {
    _requires(
      manifest,
      'android.permission.health.$fitnessPermission',
      'Android fitness permission contract',
    );
  }
  final declaredHealthPermissions = RegExp(
    r'android:name="android\.permission\.health\.([^"]+)"',
  ).allMatches(manifest).map((match) => match.group(1)!);
  for (final permission in declaredHealthPermissions) {
    if (!allowedHealthPermissions.contains(permission)) {
      _fail('Android requests out-of-scope Health Connect data: $permission');
    }
  }
  if (appGradle.contains('signingConfigs.getByName("debug")')) {
    _fail('Release configuration falls back to debug signing.');
  }

  stdout.writeln('EPIC14_RELEASE_AUDIT=PASS');
  stdout.writeln('ANDROID_ID=com.bilhealth.bodyintelligencelog');
  stdout.writeln('APPLE_ID=com.bilhealth.bodyintelligencelog');
  stdout.writeln('VERSION=$releaseVersion');
  stdout.writeln('TARGET_API=36');
  stdout.writeln(
    'APPLE_SIGNED_BUILD=EXTERNAL_CREDENTIALS_REQUIRED_NOT_CLAIMED',
  );
}
