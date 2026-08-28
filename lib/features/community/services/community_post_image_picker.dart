import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const communityPostImageMaxBytes = 5 * 1024 * 1024;
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
  CommunityPostImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CommunityPostImageDraft?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const CommunityPostImageException(
        CommunityPostImageFailure.invalidImage,
      );
    }
    if (bytes.lengthInBytes > communityPostImageMaxBytes) {
      throw const CommunityPostImageException(
        CommunityPostImageFailure.tooLarge,
      );
    }
    return validateCommunityPostImageAsync(bytes);
  }
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
