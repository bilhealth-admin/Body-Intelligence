import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../tools/qa/flutter/native_capture_manifest.dart';

const _uuid =
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

bool _matchesEntire(RegExp expression, String value) {
  final match = expression.firstMatch(value);
  return match != null && match.start == 0 && match.end == value.length;
}

void validateNativeCapturePath(
  NativeCaptureManifest capture, {
  required String deviceId,
}) {
  final filename = '${capture.name}.png';
  final escaped = RegExp.escape(filename);
  if (capture.platform == 'android') {
    if (!_matchesEntire(RegExp(r'emulator-[0-9]+'), deviceId) ||
        !_matchesEntire(
          RegExp(
            '^(?:/sdcard|/storage/emulated/0)/Android/data/'
            'com\\.bilhealth\\.bodyintelligencelog/files/'
            'feature-splashes-native/$escaped\$',
          ),
          capture.nativePath,
        )) {
      throw StateError(
        'Android capture must belong to the selected QA emulator',
      );
    }
    return;
  }
  final expression = RegExp(
    '^/Users/[^/]+/Library/Developer/CoreSimulator/Devices/($_uuid)/'
    'data/Containers/Data/Application/($_uuid)/Documents/'
    'feature-splashes-native/$escaped\$',
  );
  final match = expression.firstMatch(capture.nativePath);
  if (!_matchesEntire(RegExp(_uuid), deviceId) ||
      match == null ||
      match.end != capture.nativePath.length ||
      match.group(1)!.toLowerCase() != deviceId.toLowerCase()) {
    throw StateError('iOS capture must belong to the selected QA simulator');
  }
}

List<String> nativeCaptureAdbArguments(
  NativeCaptureManifest capture, {
  required String deviceId,
}) {
  validateNativeCapturePath(capture, deviceId: deviceId);
  if (capture.platform != 'android') {
    throw StateError('ADB transport requires an Android capture');
  }
  // Process argv only: never interpolate a device path into a shell command.
  return ['-s', deviceId, 'exec-out', 'cat', capture.nativePath];
}

typedef NativeCaptureBytesReader =
    Future<List<int>> Function(
      NativeCaptureManifest capture,
      String deviceId,
      Duration timeout,
    );

const nativeCaptureCollectionConcurrency = 4;

typedef _NativeCaptureOutcome = ({
  Map<String, Object?>? evidence,
  Object? error,
  StackTrace? stack,
});

class NativeCaptureTransport {
  NativeCaptureTransport({
    required this.deviceId,
    NativeCaptureBytesReader? reader,
    this.timeout = const Duration(seconds: 20),
  }) : _reader = reader ?? _readOriginal;

  final String deviceId;
  final Duration timeout;
  final NativeCaptureBytesReader _reader;

  /// Bound both native readers and memory to four original PNGs. A failed
  /// batch still publishes every valid image in manifest order before throwing.
  Future<void> collectAll(
    List<NativeCaptureManifest> manifest,
    Directory output, {
    required List<Map<String, Object?>> captures,
    Future<void> Function(List<Map<String, Object?>> failures)? onProgress,
  }) async {
    final queue = List<NativeCaptureManifest>.of(manifest, growable: false);
    final names = <String>{};
    for (final capture in captures) {
      final name = capture['name'];
      if (name is! String || !names.add(name)) {
        throw StateError('Duplicate or invalid existing native PNG evidence');
      }
    }
    // Reject a collision or foreign path before starting any native reader.
    for (final capture in queue) {
      if (!names.add(capture.name)) {
        throw StateError('Duplicate original native PNG evidence');
      }
      validateNativeCapturePath(capture, deviceId: deviceId);
    }
    for (var offset = 0; offset < queue.length;) {
      final end = offset + nativeCaptureCollectionConcurrency < queue.length
          ? offset + nativeCaptureCollectionConcurrency
          : queue.length;
      final batch = queue.sublist(offset, end);
      // Each outcome consumes its own error; wait for the bounded readers so
      // an early error cannot drop successful in-flight captures or hang a batch.
      final outcomes = await Future.wait([
        for (final capture in batch) _collectOutcome(capture, output),
      ]);
      final failures = <Map<String, Object?>>[];
      for (var i = 0; i < outcomes.length; i++) {
        final outcome = outcomes[i];
        if (outcome.evidence != null) captures.add(outcome.evidence!);
        if (outcome.error != null) {
          failures.add({
            'name': batch[i].name,
            'error_type': outcome.error.runtimeType.toString(),
            'error': outcome.error.toString(),
          });
        }
      }
      // Serialized checkpoint per batch, including valid partials and every
      // transfer error, before that error escapes to the driver's final receipt.
      await onProgress?.call(List.unmodifiable(failures));
      for (final outcome in outcomes) {
        if (outcome.error != null) {
          Error.throwWithStackTrace(outcome.error!, outcome.stack!);
        }
      }
      offset = end;
    }
  }

  Future<_NativeCaptureOutcome> _collectOutcome(
    NativeCaptureManifest capture,
    Directory output,
  ) async {
    try {
      return (
        evidence: await collect(capture, output),
        error: null,
        stack: null,
      );
    } catch (error, stack) {
      return (evidence: null, error: error, stack: stack);
    }
  }

  Future<Map<String, Object?>> collect(
    NativeCaptureManifest capture,
    Directory output,
  ) async {
    validateNativeCapturePath(capture, deviceId: deviceId);
    final bytes = await _reader(capture, deviceId, timeout).timeout(timeout);
    capture.verify(bytes);
    await output.create(recursive: true);
    final file = File('${output.path}/${capture.name}.png');
    await file.writeAsBytes(bytes, flush: true);
    capture.verify(await file.readAsBytes());
    return {
      ...capture.toJson(),
      'classification':
          'native Flutter screenshot captured by integration_test; original PNG',
      'transport': capture.platform == 'ios'
          ? 'selected CoreSimulator filesystem'
          : 'selected emulator adb exec-out cat',
      'selected_device': deviceId,
    };
  }
}

Future<List<int>> _readOriginal(
  NativeCaptureManifest capture,
  String deviceId,
  Duration timeout,
) async {
  if (capture.platform == 'ios') {
    if (!Platform.isMacOS) {
      throw StateError('Original iOS PNG requires its macOS simulator host');
    }
    final file = File(capture.nativePath);
    // Reject symlinks escaping the exact owned Documents directory.
    if (await file.resolveSymbolicLinks() != capture.nativePath ||
        await file.length() != capture.byteCount) {
      throw StateError('Native iOS capture path or stored size changed');
    }
    return _readBounded(file.openRead(), capture.byteCount).timeout(timeout);
  }
  final process = await Process.start(
    'adb',
    nativeCaptureAdbArguments(capture, deviceId: deviceId),
  );
  // Drain errors without retaining arbitrary process output in the evidence.
  final errors = process.stderr.drain<void>();
  final result = process.exitCode;
  try {
    final values = await Future.wait<Object>([
      _readBounded(process.stdout, capture.byteCount),
      result,
    ], eagerError: true).timeout(timeout);
    if (values[1] != 0) {
      throw StateError('ADB failed to read original native PNG (${values[1]})');
    }
    return values[0] as List<int>;
  } finally {
    // An unresponsive adb client belongs to this transfer only. Never kill
    // other adb/Flutter processes or hide the transfer's failure/timeout.
    process.kill();
    try {
      await result.timeout(const Duration(seconds: 2));
      await errors.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

Future<List<int>> _readBounded(
  Stream<List<int>> stream,
  int expectedSize,
) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > expectedSize) {
      throw StateError('Native PNG stream exceeds its verified manifest size');
    }
    bytes.add(chunk);
  }
  if (bytes.length != expectedSize) {
    throw StateError(
      'Native PNG stream ended before its verified manifest size',
    );
  }
  return bytes.takeBytes();
}
