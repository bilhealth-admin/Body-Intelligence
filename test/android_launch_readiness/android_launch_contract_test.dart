import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launch configuration is explicit and store-safe', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final rationale = File(
      'android/app/src/main/kotlin/com/kadem/bil/PermissionsRationaleActivity.kt',
    ).readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('applicationId = "com.kadem.bil"'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));

    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
    expect(manifest, contains('android.intent.action.VIEW_PERMISSION_USAGE'));
    expect(manifest, contains('android.intent.category.HEALTH_PERMISSIONS'));
    expect(
      manifest,
      contains('android.permission.START_VIEW_PERMISSION_USAGE'),
    );
    expect(manifest, contains('android.hardware.bluetooth_le'));
    expect(manifest, contains('android:required="false"'));

    expect(rationale, contains('class PermissionsRationaleActivity'));
    expect(rationale, isNot(contains('http://')));
    expect(rationale, isNot(contains('https://')));
  });

  test('Health rationale is localized in English and Arabic', () {
    final english = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final arabic = File(
      'android/app/src/main/res/values-ar/strings.xml',
    ).readAsStringSync();

    for (final key in <String>[
      'health_permissions_rationale_title',
      'health_permissions_rationale_body',
    ]) {
      expect(english, contains('name="$key"'));
      expect(arabic, contains('name="$key"'));
    }
  });
}
