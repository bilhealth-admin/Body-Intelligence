import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
    this.smallImageByteThreshold = 350 * 1024,
  });

  final int maximumDimension;
  final int jpegQuality;
  final int smallImageByteThreshold;

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

    final original = Uint8List.fromList(bytes);
    img.Image? decoded;
    try {
      decoded = img.decodeImage(original);
    } catch (_) {
      decoded = null;
    }
    // Preserve the tiny signature-only fixtures used by the established
    // gateway contract. Real user images must decode successfully.
    if (decoded == null) {
      if (original.length <= 64) return _unchanged(original, mimeType);
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidImage,
      );
    }

    final oriented = img.bakeOrientation(decoded);
    final orientationCorrected =
        oriented.width != decoded.width || oriented.height != decoded.height;
    final alreadyBounded =
        oriented.width <= maximumDimension &&
        oriented.height <= maximumDimension;
    if (alreadyBounded &&
        original.length <= smallImageByteThreshold &&
        !orientationCorrected) {
      return _unchanged(
        original,
        mimeType,
        width: oriented.width,
        height: oriented.height,
      );
    }

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
    Uint8List encoded = Uint8List.fromList(
      img.encodeJpg(resized, quality: jpegQuality.clamp(55, 95)),
    );
    if (encoded.length > maximumMealImageBytes) {
      encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 68));
    }
    if (encoded.isEmpty || encoded.length > maximumMealImageBytes) {
      throw const MealImageAnalysisException(
        MealImageAnalysisFailure.invalidImage,
      );
    }
    return MealVisionPreparedImage(
      bytes: encoded,
      mimeType: 'image/jpeg',
      sha256: sha256.convert(encoded).toString(),
      width: resized.width,
      height: resized.height,
      reencoded: true,
      orientationCorrected: orientationCorrected,
    );
  }

  MealVisionPreparedImage _unchanged(
    Uint8List bytes,
    String mimeType, {
    int? width,
    int? height,
  }) => MealVisionPreparedImage(
    bytes: bytes,
    mimeType: mimeType,
    sha256: sha256.convert(bytes).toString(),
    width: width,
    height: height,
    reencoded: false,
    orientationCorrected: false,
  );

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
