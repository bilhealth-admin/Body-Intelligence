import '../../../shared/media/private_image_pixels.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'meal_image_gateway_contract.dart';

class MealVisionPreparedImage {
  const MealVisionPreparedImage({
    required this.bytes,
    required this.mimeType,
    required this.sha256,
    required this.width,
    required this.height,
    required this.reencoded,
    required this.orientationCorrected,
  });

  final Uint8List bytes;
  final String mimeType;
  final String sha256;
  final int? width;
  final int? height;
  final bool reencoded;
  final bool orientationCorrected;
}

abstract interface class MealVisionImagePreprocessor {
  Future<MealVisionPreparedImage> prepare({
    required List<int> bytes,
    required String mimeType,
  });
}

class DefaultMealVisionImagePreprocessor
    implements MealVisionImagePreprocessor {
  const DefaultMealVisionImagePreprocessor({
    this.maximumDimension = 1600,
    this.jpegQuality = 84,
  });

  final int maximumDimension;
  final int jpegQuality;

  @override
  Future<MealVisionPreparedImage> prepare({
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty || bytes.length > maximumMealImageBytes) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidImage,
      );
    }
    if (!_supported.contains(mimeType) || !_signature(bytes, mimeType)) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidImage,
      );
    }

    final prepared = await compute(_prepareMealVisionImage, <String, Object>{
      'bytes': Uint8List.fromList(bytes),
      'maximumDimension': maximumDimension,
      'jpegQuality': jpegQuality,
    });

    return MealVisionPreparedImage(
      bytes: prepared['bytes']! as Uint8List,
      mimeType: prepared['mimeType']! as String,
      sha256: prepared['sha256']! as String,
      width: prepared['width'] as int?,
      height: prepared['height'] as int?,
      reencoded: prepared['reencoded']! as bool,
      orientationCorrected: prepared['orientationCorrected']! as bool,
    );
  }

  static const _supported = <String>{'image/jpeg', 'image/png', 'image/webp'};

  static bool _signature(List<int> bytes, String mimeType) {
    if (mimeType == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mimeType == 'image/png') {
      const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }
    return bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }
}

Map<String, Object?> _prepareMealVisionImage(Map<String, Object> request) {
  final original = request['bytes']! as Uint8List;
  final maximumDimension = request['maximumDimension']! as int;
  final jpegQuality = request['jpegQuality']! as int;

  int? encodedOrientation;
  if (original.length >= 2 && original[0] == 0xff && original[1] == 0xd8) {
    try {
      // The JPEG decoder already rotates pixels and removes this tag.
      encodedOrientation = img.decodeJpgExif(original)?.imageIfd.orientation;
    } on Object {
      // Pixel decoding below remains the validity gate for damaged metadata.
    }
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(original);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const MealImageAnalysisException(
      MealImageAnalysisFailure.invalidImage,
    );
  }
  final orientation = encodedOrientation ?? decoded.exif.imageIfd.orientation;
  final orientationCorrected =
      orientation != null && orientation >= 2 && orientation <= 8;
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final scale = longest > maximumDimension ? maximumDimension / longest : 1.0;
  final resized = scale < 1
      ? img.copyResize(
          oriented,
          width: (oriented.width * scale).round(),
          height: (oriented.height * scale).round(),
          interpolation: img.Interpolation.linear,
        )
      : oriented;
  // A fresh pixel-only image cannot carry EXIF GPS, private thumbnails,
  // comments, XMP, PNG text or other metadata retained by decode/resize.
  // Composite transparency onto white instead of exposing hidden RGB pixels.
  final clean = privateImagePixels(resized, flattenAlpha: true);
  Uint8List encoded = Uint8List.fromList(
    img.encodeJpg(clean, quality: jpegQuality.clamp(55, 95)),
  );
  if (encoded.length > maximumMealImageBytes) {
    encoded = Uint8List.fromList(img.encodeJpg(clean, quality: 68));
  }
  if (encoded.isEmpty || encoded.length > maximumMealImageBytes) {
    throw const MealImageAnalysisException(
      MealImageAnalysisFailure.invalidImage,
    );
  }
  return _mealVisionPreparedResult(
    bytes: encoded,
    mimeType: 'image/jpeg',
    width: resized.width,
    height: resized.height,
    reencoded: true,
    orientationCorrected: orientationCorrected,
  );
}

Map<String, Object?> _mealVisionPreparedResult({
  required Uint8List bytes,
  required String mimeType,
  required int? width,
  required int? height,
  required bool reencoded,
  required bool orientationCorrected,
}) => <String, Object?>{
  'bytes': bytes,
  'mimeType': mimeType,
  'sha256': sha256.convert(bytes).toString(),
  'width': width,
  'height': height,
  'reencoded': reencoded,
  'orientationCorrected': orientationCorrected,
};
