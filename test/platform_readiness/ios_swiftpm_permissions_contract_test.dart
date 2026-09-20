import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS permission strategies stay enabled in SwiftPM builds', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lock = File('pubspec.lock').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      pubspec,
      matches(
        RegExp(
          r'^flutter:\s+.*?^  config:\s+.*?^    enable-swift-package-manager: true$',
          multiLine: true,
          dotAll: true,
        ),
      ),
      reason: 'The project must not depend on a developer machine global flag.',
    );
    expect(
      lock,
      matches(
        RegExp(
          r'^  permission_handler_apple:\s+.*?^    version: "9\.5\.0"$',
          multiLine: true,
          dotAll: true,
        ),
      ),
      reason:
          '9.5.0 includes the SwiftPM Info.plist lookup used to compile permission strategies.',
    );
    expect(project, contains('FlutterGeneratedPluginSwiftPackage'));

    for (final key in <String>[
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
      'NSPhotoLibraryUsageDescription',
    ]) {
      expect(
        info,
        contains('<key>$key</key>'),
        reason: '$key enables its permission_handler_apple SwiftPM strategy.',
      );
    }

    // permission_handler_apple 9.5.0 enables PERMISSION_NOTIFICATIONS by
    // default because notification authorization has no Info.plist usage key.
    // Do not add fake usage-description keys for it.
    expect(info, isNot(contains('NSNotificationsUsageDescription')));
  });
}
