import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple preparation files and contracts are present', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(project, contains('InfoPlist.strings in Resources'));
    expect(privacy, contains('<key>NSPrivacyTracking</key><false/>'));
    for (final locale in ['en', 'ar']) {
      final strings = File(
        'ios/Runner/$locale.lproj/InfoPlist.strings',
      ).readAsStringSync();
      for (final key in [
        'NSHealthShareUsageDescription',
        'NSHealthUpdateUsageDescription',
        'NSBluetoothAlwaysUsageDescription',
        'NSBluetoothPeripheralUsageDescription',
      ]) {
        expect(strings, contains('"$key"'));
      }
    }
  });
}
