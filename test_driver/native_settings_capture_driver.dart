import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Receives native screenshots on the host before the test app is removed.
/// A valid capture is evidence, not an automatic Apple visual-match approval.
Future<void> main() async {
  final output = Directory('docs/qa/native_settings_20260910');
  await output.create(recursive: true);
  final captures = <String>[];
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^(profile|settings)-ar-(android|iOS)$').hasMatch(name)) {
        throw StateError('Unexpected screenshot name');
      }
      const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < pngHeader.length ||
          List.generate(
            pngHeader.length,
            (i) => bytes[i] == pngHeader[i],
          ).contains(false)) {
        throw StateError('Native screenshot is not a PNG');
      }
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      captures.add(name);
      return true;
    },
    responseDataCallback: (_) async {
      if (captures.toSet().length != 2) {
        throw StateError('Both native page captures are required');
      }
    },
  );
}
