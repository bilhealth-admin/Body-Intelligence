import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../app/services/recoverable_image_picker.dart';

const communityPostImageMaxBytes = 5 * 1024 * 1024;
// Keep a safety margin below the Storage/RPC 5 MiB contract. Users should be
// able to choose the camera's original image; the app owns this conversion.
const communityPostImageTargetBytes = 4 * 1024 * 1024;
const communityPostImageProcessingMaxDimension = 2048;
const communityPostImageMaxDimension = 8192;
const communityPostImageMaxPixels = 40000000;

enum CommunityPostImageFailure {
  tooLarge,
  unsupportedType,
  invalidImage,
  invalidDimensions,
}

class CommunityPostImageException implements Exception {
  const CommunityPostImageException(this.failure);

  final CommunityPostImageFailure failure;
}

class CommunityPostImageDraft {
  const CommunityPostImageDraft({
    required this.bytes,
    required this.mimeType,
    required this.extension,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
  final int width;
  final int height;

  int get byteLength => bytes.lengthInBytes;
  double get aspectRatio => width / height;
}

abstract interface class CommunityPostImagePickerContract {
  Future<CommunityPostImageDraft?> pick();
}

class CommunityPostImagePicker implements CommunityPostImagePickerContract {
  CommunityPostImagePicker({
    ImagePicker? picker,
    BilRecoverableImagePicker? recoverablePicker,
  }) : _picker =
           recoverablePicker ??
           (picker == null
               ? BilRecoverableImagePicker.instance
               : BilRecoverableImagePicker(picker: picker));

  final BilRecoverableImagePicker _picker;

  @override
  Future<CommunityPostImageDraft?> pick() async {
    final file = await _picker.pickImage(
      purpose: BilImagePickerPurpose.communityPost,
      source: ImageSource.gallery,
      // Ask the native picker to do the cheap first pass. The Dart fallback
      // below still handles PNGs and platforms that ignore imageQuality.
      maxWidth: communityPostImageProcessingMaxDimension.toDouble(),
      maxHeight: communityPostImageProcessingMaxDimension.toDouble(),
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const CommunityPostImageException(
        CommunityPostImageFailure.invalidImage,
      );
    }
    return prepareCommunityPostImageAsync(bytes);
  }
}

/// Validates an image selected from the device, transparently re-encoding a
/// large original instead of making the user learn an image-conversion tool.
Future<CommunityPostImageDraft> prepareCommunityPostImageAsync(
  Uint8List bytes,
) async {
  if (bytes.isEmpty) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidImage,
    );
  }
  if (bytes.lengthInBytes <= communityPostImageMaxBytes) {
    return validateCommunityPostImageAsync(bytes);
  }

  try {
    final compressed = await compute(
      _compressOversizedCommunityPostImage,
      bytes,
    );
    if (compressed.isEmpty ||
        compressed.lengthInBytes > communityPostImageMaxBytes) {
      throw const FormatException('community_image_compression_limit');
    }
    return validateCommunityPostImageAsync(compressed);
  } on CommunityPostImageException {
    rethrow;
  } on Object {
    throw const CommunityPostImageException(CommunityPostImageFailure.tooLarge);
  }
}

Uint8List _compressOversizedCommunityPostImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('invalid_image');
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  Uint8List? last;

  // Most phone photos fit at 2048px/quality 84. Noisy camera images get a
  // second, still-readable pass at a smaller dimension before failing closed.
  for (final dimension in <int>[2048, 1600, 1280]) {
    final scale = longest > dimension ? dimension / longest : 1.0;
    final resized = scale < 1
        ? img.copyResize(
            oriented,
            width: (oriented.width * scale).round(),
            height: (oriented.height * scale).round(),
            interpolation: img.Interpolation.linear,
          )
        : oriented;
    for (final quality in <int>[84, 76, 68, 60]) {
      last = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (last.lengthInBytes <= communityPostImageTargetBytes) return last;
    }
  }
  return last ?? Uint8List(0);
}

CommunityPostImageDraft validateCommunityPostImage(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidImage,
    );
  }
  if (bytes.lengthInBytes > communityPostImageMaxBytes) {
    throw const CommunityPostImageException(CommunityPostImageFailure.tooLarge);
  }
  final metadata = _inspectCommunityPostImage(bytes);
  return CommunityPostImageDraft(
    bytes: bytes,
    mimeType: metadata.mimeType,
    extension: metadata.extension,
    width: metadata.width,
    height: metadata.height,
  );
}

Future<CommunityPostImageDraft> validateCommunityPostImageAsync(
  Uint8List bytes,
) async {
  if (bytes.isEmpty) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidImage,
    );
  }
  if (bytes.lengthInBytes > communityPostImageMaxBytes) {
    throw const CommunityPostImageException(CommunityPostImageFailure.tooLarge);
  }
  final metadata = await compute(_inspectCommunityPostImage, bytes);
  return CommunityPostImageDraft(
    bytes: bytes,
    mimeType: metadata.mimeType,
    extension: metadata.extension,
    width: metadata.width,
    height: metadata.height,
  );
}

typedef _CommunityPostImageMetadata = ({
  String mimeType,
  String extension,
  int width,
  int height,
});

_CommunityPostImageMetadata _inspectCommunityPostImage(Uint8List bytes) {
  final (mimeType, extension, decoder) = _allowedDecoder(bytes);
  img.DecodeInfo? info;
  try {
    info = decoder.startDecode(bytes);
  } on Object {
    info = null;
  }
  if (info == null) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidImage,
    );
  }
  if (!_dimensionsAllowed(info.width, info.height)) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidDimensions,
    );
  }

  img.Image? decoded;
  try {
    decoded = decoder.decodeFrame(0);
  } on Object {
    decoded = null;
  }
  if (decoded == null) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidImage,
    );
  }
  final oriented = img.bakeOrientation(decoded);
  if (!_dimensionsAllowed(oriented.width, oriented.height)) {
    throw const CommunityPostImageException(
      CommunityPostImageFailure.invalidDimensions,
    );
  }
  return (
    mimeType: mimeType,
    extension: extension,
    width: oriented.width,
    height: oriented.height,
  );
}

(String, String, img.Decoder) _allowedDecoder(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return ('image/jpeg', 'jpg', img.JpegDecoder());
  }
  const pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= pngSignature.length) {
    var png = true;
    for (var index = 0; index < pngSignature.length; index++) {
      if (bytes[index] != pngSignature[index]) {
        png = false;
        break;
      }
    }
    if (png) return ('image/png', 'png', img.PngDecoder());
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return ('image/webp', 'webp', img.WebPDecoder());
  }
  throw const CommunityPostImageException(
    CommunityPostImageFailure.unsupportedType,
  );
}

bool _dimensionsAllowed(int width, int height) =>
    width > 0 &&
    height > 0 &&
    width <= communityPostImageMaxDimension &&
    height <= communityPostImageMaxDimension &&
    width * height <= communityPostImageMaxPixels;
