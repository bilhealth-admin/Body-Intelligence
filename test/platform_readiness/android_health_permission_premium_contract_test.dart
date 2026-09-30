import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health Connect rationale is localized, scoped, and premium native UI', () {
    final activity = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
      'PermissionsRationaleActivity.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final lightStyles = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    final darkStyles = File(
      'android/app/src/main/res/values-night/styles.xml',
    ).readAsStringSync();

    expect(manifest, contains('@style/HealthPermissionRationaleTheme'));
    expect(lightStyles, contains('HealthPermissionRationaleTheme'));
    expect(darkStyles, contains('HealthPermissionRationaleTheme'));
    expect(activity, contains('Color.parseColor(if (isDark) "#030405"'));
    expect(activity, contains('R.drawable.bil_symbol_health'));
    expect(activity, contains('GradientDrawable.Orientation.TL_BR'));
    expect(activity, contains('health_permissions_rationale_body'));
    expect(activity, contains('health_permissions_release_scope_note'));
    expect(activity, contains('health_permissions_privacy_policy_action'));

    final locales = Directory('android/app/src/main/res')
        .listSync()
        .whereType<Directory>()
        .where((directory) {
          final name = directory.path.split(Platform.pathSeparator).last;
          return name == 'values' || name.startsWith('values-');
        })
        .where(
          (directory) => File('${directory.path}/strings.xml').existsSync(),
        )
        .toList(growable: false);
    final localized = locales.where((directory) {
      final text = File('${directory.path}/strings.xml').readAsStringSync();
      return text.contains('health_permissions_release_scope_note');
    }).length;
    expect(localized, greaterThanOrEqualTo(25));
  });
}
