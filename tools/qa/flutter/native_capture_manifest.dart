import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:crypto/crypto.dart';

// QA-only transport: original PNG bytes stay on the native filesystem. The
// integration driver receives this small, independently verifiable description.
const nativeCaptureManifestKey = 'native_capture_manifest';
const nativeCaptureManifestFilename = 'native-capture-manifest.json';

bool isNativeCaptureName(String name) {
  for (final pattern in [
    r'^(recipes|videos|sleep|diet|coach|community)-(ar|en)-light-(normal|reduced)-(welcome|released)$',
    r'^coach-(reveal|history)-(ar|en)-light-(normal|reduced)-(first|reading|mid|end)$',
    r'^bil39-plan-(home|gym)-(ar|en)-(dark|light)-(1|2)x-(warmup|session)$',
    r'^bil39-community-(ar|en)-(dark|light)-(1|2)x-(reply|sent)$',
    r'^bil39-store-(ar|en)-(dark|light)-2x-pending$',
  ]) {
    final match = RegExp(pattern).firstMatch(name);
    if (match != null && match.start == 0 && match.end == name.length) {
      return true;
    }
  }
  return false;
}

({int width, int height}) inspectNativeCapturePng(List<int> input) {
  final bytes = input is Uint8List ? input : Uint8List.fromList(input);
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 57 ||
      List.generate(8, (i) => bytes[i] == signature[i]).contains(false)) {
    throw const FormatException('Native capture is not a complete PNG');
  }
  final view = ByteData.sublistView(bytes);
  var offset = 8;
  var width = 0;
  var height = 0;
  var hasData = false;
  var dataEnded = false;
  while (offset + 12 <= bytes.length) {
    final length = view.getUint32(offset);
    final end = offset + 12 + length;
    if (end > bytes.length) {
      throw const FormatException('Truncated native PNG chunk');
    }
    final kind = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(kind) ||
        getCrc32(Uint8List.sublistView(bytes, offset + 4, end - 4)) !=
            view.getUint32(end - 4)) {
      throw const FormatException('Invalid native PNG chunk or CRC');
    }
    if (offset == 8 && kind != 'IHDR') {
      throw const FormatException('Native PNG must start with IHDR');
    }
    if (kind == 'IHDR') {
      if (offset != 8 || length != 13) {
        throw const FormatException('Invalid native PNG IHDR');
      }
      width = view.getUint32(offset + 8);
      height = view.getUint32(offset + 12);
      final depth = bytes[offset + 16];
      final color = bytes[offset + 17];
      const depths = {
        0: [1, 2, 4, 8, 16],
        2: [8, 16],
        3: [1, 2, 4, 8],
        4: [8, 16],
        6: [8, 16],
      };
      if (width <= 0 ||
          height <= 0 ||
          width > 0x7fffffff ||
          height > 0x7fffffff ||
          !(depths[color]?.contains(depth) ?? false) ||
          bytes[offset + 18] != 0 ||
          bytes[offset + 19] != 0 ||
          bytes[offset + 20] > 1) {
        throw const FormatException('Invalid native PNG dimensions or format');
      }
    } else if (kind == 'IDAT') {
      if (dataEnded) {
        throw const FormatException('Discontinuous native PNG image data');
      }
      hasData = hasData || length > 0;
    } else if (kind == 'IEND') {
      if (!hasData || length != 0 || end != bytes.length) {
        throw const FormatException('Incomplete native PNG image data');
      }
      return (width: width, height: height);
    } else if (hasData) {
      dataEnded = true;
    }
    offset = end;
  }
  throw const FormatException('Native PNG has no complete IEND');
}

class NativeCaptureManifest {
  NativeCaptureManifest._({
    required this.name,
    required this.platform,
    required this.nativePath,
    required this.sha256Hex,
    required this.byteCount,
    required this.widthPixels,
    required this.heightPixels,
  });

  factory NativeCaptureManifest.fromPng({
    required String name,
    required String platform,
    required String nativePath,
    required List<int> bytes,
  }) {
    final size = inspectNativeCapturePng(bytes);
    return NativeCaptureManifest.parse({
      'schema': 1,
      'name': name,
      'platform': platform,
      'native_path': nativePath,
      'sha256': sha256.convert(bytes).toString(),
      'byte_count': bytes.length,
      'width_pixels': size.width,
      'height_pixels': size.height,
    });
  }

  factory NativeCaptureManifest.parse(Object? value) {
    if (value is! Map ||
        value['schema'] != 1 ||
        value['name'] is! String ||
        !isNativeCaptureName(value['name'] as String) ||
        !['android', 'ios'].contains(value['platform']) ||
        value['native_path'] is! String ||
        !value['native_path'].startsWith('/') ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value['native_path'] as String) ||
        value['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sha256'] as String) ||
        value['byte_count'] is! int ||
        (value['byte_count'] as int) <= 0 ||
        value['width_pixels'] is! int ||
        (value['width_pixels'] as int) <= 0 ||
        value['height_pixels'] is! int ||
        (value['height_pixels'] as int) <= 0) {
      throw const FormatException('Invalid native capture manifest');
    }
    return NativeCaptureManifest._(
      name: value['name'] as String,
      platform: value['platform'] as String,
      nativePath: value['native_path'] as String,
      sha256Hex: value['sha256'] as String,
      byteCount: value['byte_count'] as int,
      widthPixels: value['width_pixels'] as int,
      heightPixels: value['height_pixels'] as int,
    );
  }

  final String name;
  final String platform;
  final String nativePath;
  final String sha256Hex;
  final int byteCount;
  final int widthPixels;
  final int heightPixels;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'name': name,
    'platform': platform,
    'native_path': nativePath,
    'sha256': sha256Hex,
    'byte_count': byteCount,
    'width_pixels': widthPixels,
    'height_pixels': heightPixels,
  };

  void verify(List<int> bytes) {
    if (bytes.length != byteCount ||
        sha256.convert(bytes).toString() != sha256Hex) {
      throw const FormatException('Native capture size or SHA-256 mismatch');
    }
    final size = inspectNativeCapturePng(bytes);
    if (size.width != widthPixels || size.height != heightPixels) {
      throw const FormatException('Native capture PNG dimensions mismatch');
    }
  }
}

List<NativeCaptureManifest> readNativeCaptureManifest(Object? data) {
  if (data is! Map || data['schema'] != 1 || data['captures'] is! List) {
    throw const FormatException('Native capture manifest is missing');
  }
  final result = (data['captures'] as List)
      .map(NativeCaptureManifest.parse)
      .toList(growable: false);
  final names = result.map((capture) => capture.name).toSet();
  if (names.length != result.length) {
    throw const FormatException('Duplicate native capture manifest name');
  }
  return result;
}

// Call only after persisting and verifying this capture. Retain every unrelated
// SDK entry, and never detach a mismatching or duplicate screenshot by name.
void detachPersistedNativeCapture(
  Map<String, dynamic> reportData,
  NativeCaptureManifest capture,
) {
  final screenshots = reportData['screenshots'];
  if (screenshots is! List) {
    throw StateError('SDK screenshot entry unavailable after native capture');
  }
  final indexes = <int>[];
  for (var index = 0; index < screenshots.length; index++) {
    final entry = screenshots[index];
    if (entry is Map && entry['screenshotName'] == capture.name) {
      indexes.add(index);
    }
  }
  if (indexes.length != 1) {
    throw StateError('SDK screenshot must have one exact native capture entry');
  }
  final bytes = (screenshots[indexes.single] as Map)['bytes'];
  if (bytes is! List<int>) {
    throw StateError('SDK native capture bytes unavailable');
  }
  capture.verify(bytes);
  screenshots.removeAt(indexes.single);
}
