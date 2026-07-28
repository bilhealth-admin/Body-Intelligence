import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production metadata declares supported locales and non-required BLE',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
      expect(manifest, contains('android:supportsRtl="true"'));
      expect(
        manifest,
        contains('android.hardware.bluetooth_le" android:required="false"'),
      );

      final locales = File(
        'android/app/src/main/res/xml/locales_config.xml',
      ).readAsStringSync();
      expect(locales, contains('android:name="ar"'));
      expect(locales, contains('android:name="en"'));

      final ios = File('ios/Runner/Info.plist').readAsStringSync();
      expect(ios, contains('<key>CFBundleLocalizations</key>'));
      expect(ios, contains('<string>ar</string>'));
      expect(ios, contains('<string>en</string>'));

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('A new Flutter project.')));
    },
  );
}
