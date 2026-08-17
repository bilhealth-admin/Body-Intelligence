import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release builder removes only the dev integration plugin fail closed',
    () {
      final script = File(
        'tool/final_proof/build_android_release.ps1',
      ).readAsStringSync();

      expect(script, contains('flutter pub get'));
      expect(script, contains("'build', 'appbundle', '--release', '--no-pub'"));
      expect(
        script,
        contains(
          'dev\\.flutter\\.plugins\\.integration_test\\.IntegrationTestPlugin',
        ),
      );
      expect(script, contains(r'$matches.Count -gt 1'));
      expect(
        script,
        contains(
          'io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin',
        ),
      );
      expect(script, contains('android/key.properties is missing'));
      expect(script, contains('Get-FileHash -Algorithm SHA256'));
      expect(script, isNot(contains('storePassword=')));
      expect(script, isNot(contains('keyPassword=')));
    },
  );
}
