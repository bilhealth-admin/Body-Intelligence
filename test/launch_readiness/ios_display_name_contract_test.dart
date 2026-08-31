import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS device display and bundle names use the approved public name', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      matches(
        RegExp(
          r'<key>CFBundleDisplayName</key>\s*<string>Body Intelligence Log</string>',
        ),
      ),
    );
    expect(
      plist,
      matches(
        RegExp(
          r'<key>CFBundleName</key>\s*<string>Body Intelligence Log</string>',
        ),
      ),
    );
    expect(
      plist,
      isNot(
        matches(
          RegExp(r'<key>CFBundleDisplayName</key>\s*<string>BIL</string>'),
        ),
      ),
    );
  });

  test('Android launcher names keep the full name without a BIL prefix', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final defaultStrings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final localizedStrings = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('strings.xml'))
        .where((file) => file.readAsStringSync().contains('name="app_name"'))
        .toList(growable: false);

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(
      defaultStrings,
      contains('<string name="app_name">Body Intelligence Log</string>'),
    );
    expect(localizedStrings, hasLength(25));
    for (final file in localizedStrings) {
      final appName = RegExp(
        r'<string name="app_name">([^<]+)</string>',
      ).firstMatch(file.readAsStringSync())?.group(1);
      expect(appName, isNotNull, reason: file.path);
      expect(appName!.trim(), isNotEmpty, reason: file.path);
      expect(
        appName,
        isNot(matches(RegExp(r'^\s*BIL\s*(?:-|–|—)\s*'))),
        reason: file.path,
      );
    }
  });
}
