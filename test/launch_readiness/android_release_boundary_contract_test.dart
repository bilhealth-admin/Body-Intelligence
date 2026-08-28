import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release identity and toolchain are explicit', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    for (final contract in <String>[
      'namespace = "com.bilhealth.bodyintelligencelog"',
      'applicationId = "com.bilhealth.bodyintelligencelog"',
      'compileSdk = 36',
      'minSdk = 26',
      'targetSdk = 36',
      'versionCode = flutter.versionCode',
      'versionName = flutter.versionName',
      'JavaVersion.VERSION_17',
      'JvmTarget.JVM_17',
    ]) {
      expect(gradle, contains(contract), reason: 'Missing: $contract');
    }
  });

  test('release signing is private complete and never debug-backed', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ignores = File('android/.gitignore').readAsStringSync();
    final example = File('android/key.properties.example').readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('val missingKeys = requiredKeys.filter'));
    expect(gradle, contains('require(missingKeys.isEmpty())'));
    expect(
      gradle,
      contains(
        'signingConfig = if (hasReleaseSigning) '
        'signingConfigs.getByName("release") else null',
      ),
    );
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));

    for (final ignored in <String>[
      'key.properties',
      '**/*.keystore',
      '**/*.jks',
    ]) {
      expect(ignores, contains(ignored), reason: 'Not ignored: $ignored');
    }
    expect(example, contains('CHANGE_ME'));
    expect(example, contains('bil-upload-key.jks'));
    expect(example, isNot(contains('storePassword=bil')));
  });

  test('manifest permission scope matches production bridge capabilities', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final bridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
    ).readAsStringSync();

    for (final permission in <String>[
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.BLUETOOTH_CONNECT',
      'android.permission.health.READ_STEPS',
      'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
      'android.permission.health.READ_EXERCISE',
      'android.permission.health.READ_SLEEP',
      'android.permission.health.READ_HEART_RATE',
      'android.permission.health.READ_RESTING_HEART_RATE',
      'android.permission.health.READ_HEART_RATE_VARIABILITY',
      'android.permission.health.READ_WEIGHT',
      'android.permission.health.WRITE_WEIGHT',
      'android.permission.health.READ_NUTRITION',
      'android.permission.health.WRITE_NUTRITION',
    ]) {
      expect(manifest, contains(permission), reason: 'Missing: $permission');
    }

    for (final excludedPermission in <String>[
      'READ_HYDRATION',
      'READ_OXYGEN_SATURATION',
      'READ_BLOOD_GLUCOSE',
      'READ_BLOOD_PRESSURE',
      'READ_BODY_TEMPERATURE',
      'READ_RESPIRATORY_RATE',
    ]) {
      expect(manifest, isNot(contains(excludedPermission)));
    }
    for (final excludedRecord in <String>[
      'OxygenSaturationRecord',
      'BloodGlucoseRecord',
      'BloodPressureRecord',
      'BodyTemperatureRecord',
      'RespiratoryRateRecord',
    ]) {
      expect(bridge, isNot(contains(excludedRecord)));
    }
    expect(bridge, isNot(contains('"oxygen"')));
    expect(bridge, contains('"weight" -> WeightRecord('));
    expect(
      bridge,
      contains('"steps", "activeEnergy", "workout", "sleep", "weight"'),
    );
    expect(bridge, contains('else -> null'));
  });

  test('Android privacy and rationale boundaries stay active', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final english = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final arabic = File(
      'android/app/src/main/res/values-ar/strings.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:maxSdkVersion="30"'));
    expect(manifest, contains('android.hardware.bluetooth_le'));
    expect(manifest, contains('android:required="false"'));
    expect(
      manifest,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
    expect(manifest, contains('android.intent.category.HEALTH_PERMISSIONS'));

    for (final key in <String>[
      'health_permissions_rationale_title',
      'health_permissions_rationale_body',
    ]) {
      expect(english, contains('name="$key"'));
      expect(arabic, contains('name="$key"'));
    }
  });
}
