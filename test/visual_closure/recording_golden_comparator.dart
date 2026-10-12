import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Records the real raster even when a reference is missing. The original
/// comparator still decides pass/fail; no tolerance or approval is added.
class RecordingGoldenComparator extends GoldenFileComparator {
  RecordingGoldenComparator(this.delegate, this.testFile);

  final GoldenFileComparator delegate;
  final String testFile;

  @override
  Uri getTestUri(Uri key, int? version) => delegate.getTestUri(key, version);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final source = File(testFile).absolute.parent.uri;
    final resolved = source.resolveUri(golden).normalizePath().toFilePath();
    final root = '${Directory.current.absolute.path}${Platform.pathSeparator}';
    if (!resolved.startsWith(root)) {
      throw StateError('Golden reference escaped the test workspace');
    }
    final relative = resolved.substring(root.length);
    final output = File('build/golden-review/current/$relative.actual.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(imageBytes);
    return delegate.compare(imageBytes, golden);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      delegate.update(golden, imageBytes);
}
