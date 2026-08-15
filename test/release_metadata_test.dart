import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release metadata uses BIL identity and privacy-safe local backup', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(android, contains('android:label="@string/app_name"'));
    final androidDefaultStrings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(
      androidDefaultStrings,
      contains('<string name="app_name">BIL - Body Intelligence Log</string>'),
    );
    expect(android, contains('android:allowBackup="false"'));
    expect(android, contains('android:fullBackupContent="false"'));

    final web =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(web['name'], startsWith('BIL'));
    expect(web['short_name'], 'BIL');
    expect(web, isNot(contains('orientation')));
    expect(web['description'], isNot(contains('new Flutter project')));

    final windows = File('windows/runner/Runner.rc').readAsStringSync();
    expect(windows, contains('BIL - Body Intelligence Log'));
    expect(windows, isNot(contains('com.example')));

    final masterIcon = File('assets/branding/bil_icon_master.png');
    expect(masterIcon.lengthSync(), greaterThan(100000));
    expect(masterIcon.readAsBytesSync().take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
  });
}
