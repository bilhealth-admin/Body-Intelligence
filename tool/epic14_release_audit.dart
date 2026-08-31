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
    (settings, 'com.android.application") version "9.2.1"'),
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
  if (debugEntitlements.contains('aps-environment')) {
    _fail('Production APNs entitlement leaked into Debug signing.');
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
  for (final value in <String>[
    'APPLE_DISTRIBUTION_CERTIFICATE_BASE64',
    'APPLE_PROVISIONING_PROFILE_BASE64',
    'APPLE_TEAM_ID',
    'APP_STORE_CONNECT_KEY_ID',
    'APP_STORE_CONNECT_ISSUER_ID',
    'APP_STORE_CONNECT_PRIVATE_KEY_BASE64',
    'flutter build ipa --release',
    'altool --validate-app',
  ]) {
    _requires(signedIos, value, 'signed iOS workflow');
  }

  for (final fitnessPermission in const <String>[
    'READ_STEPS',
    'READ_ACTIVE_CALORIES_BURNED',
    'READ_EXERCISE',
    'READ_SLEEP',
    'READ_HEART_RATE',
    'READ_RESTING_HEART_RATE',
    'READ_HEART_RATE_VARIABILITY',
    'READ_WEIGHT',
    'WRITE_WEIGHT',
    'READ_NUTRITION',
    'WRITE_NUTRITION',
  ]) {
    _requires(
      manifest,
      'android.permission.health.$fitnessPermission',
      'Android fitness permission contract',
    );
  }
  for (final medicalPermission in const <String>[
    'READ_BLOOD_PRESSURE',
    'READ_OXYGEN_SATURATION',
    'READ_BLOOD_GLUCOSE',
    'READ_BODY_TEMPERATURE',
  ]) {
    if (manifest.contains('android.permission.health.$medicalPermission')) {
      _fail('Android requests forbidden medical data: $medicalPermission');
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
