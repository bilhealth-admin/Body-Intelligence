import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

import '../tools/qa/flutter/native_capture_manifest.dart';

/// Receives native screenshots on the host before the test app is removed.
/// A valid capture is evidence, not an automatic Apple visual-match approval.
Future<void> main() async {
  final output = Directory(
    Platform.environment['BIL_NATIVE_SETTINGS_OUTPUT'] ??
        'docs/qa/native_settings_20260910',
  );
  await output.create(recursive: true);
  final captures = <String>[];
  final evidence = <Map<String, Object?>>[];
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(
            r'^(?:(?:profile|settings)-ar|pearl-(?:goal|voice)-(?:ar|en)-(?:light|dark-200))-(?:android|iOS)$',
          ).hasMatch(name) ||
          captures.contains(name)) {
        throw StateError('Unexpected screenshot name');
      }
      final png = inspectNativeCapturePng(bytes);
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      captures.add(name);
      evidence.add({
        'name': name,
        'sha256': sha256.convert(bytes).toString(),
        'width_pixels': png.width,
        'height_pixels': png.height,
        'byte_count': bytes.length,
      });
      await File('${output.path}/capture-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(evidence),
        flush: true,
      );
      return true;
    },
    responseDataCallback: (_) async {
      final platform = Platform.isMacOS ? 'iOS' : 'android';
      final expected = {
        'profile-ar-$platform',
        'settings-ar-$platform',
        for (final language in ['ar', 'en'])
          for (final mode in ['light', 'dark-200']) ...[
            'pearl-goal-$language-$mode-$platform',
            if (platform == 'android') 'pearl-voice-$language-$mode-$platform',
          ],
      };
      if (captures.length != expected.length ||
          !captures.toSet().containsAll(expected)) {
        throw StateError('Native pages and platform-font dialogs are required');
      }
    },
  );
}
