part of 'community_post_image_picker.dart';

/// Display-only pixels. A preview cannot be passed to a draft-save or publish
/// API, both of which require the separately validated original image draft.
class CommunityPostImagePreview {
  CommunityPostImagePreview._({
    required Uint8List bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  }) : bytes = bytes.asUnmodifiableView() {
    if (bytes.isEmpty ||
        bytes.lengthInBytes > maxBytes ||
        width < 1 ||
        height < 1 ||
        width > maxDimension ||
        height > maxDimension) {
      throw const FormatException('Invalid bounded Community preview');
    }
  }

  static const maxDimension = 256;
  static const maxBytes = 64 * 1024;

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;

  int get byteLength => bytes.lengthInBytes;
}

typedef _CommunityPostPreviewInput = ({
  Uint8List bytes,
  String mimeType,
  int byteLength,
  int width,
  int height,
});

/// Verifies the downloaded original against the same authoritative metadata
/// used by the editor, then retains only a bounded local thumbnail. Decoding,
/// validation and resizing share one worker and one decoded original frame.
Future<CommunityPostImagePreview> createCommunityPostImagePreviewAsync(
  Uint8List bytes, {
  required String expectedMimeType,
  required int expectedByteLength,
  required int expectedWidth,
  required int expectedHeight,
}) async {
  if (bytes.isEmpty ||
      bytes.lengthInBytes > communityPostImageMaxBytes ||
      bytes.lengthInBytes != expectedByteLength) {
    throw const FormatException('Invalid Community preview source size');
  }
  return compute(_createCommunityPostImagePreview, (
    bytes: bytes,
    mimeType: expectedMimeType,
    byteLength: expectedByteLength,
    width: expectedWidth,
    height: expectedHeight,
  ));
}

CommunityPostImagePreview _createCommunityPostImagePreview(
  _CommunityPostPreviewInput input,
) {
  final source = _decodeCommunityPostImage(input.bytes);
  final original = source.image;
  if (input.bytes.lengthInBytes != input.byteLength ||
      source.mimeType != input.mimeType ||
      original.width != input.width ||
      original.height != input.height) {
    throw const FormatException('Community draft preview media mismatch');
  }
  final longest = original.width > original.height
      ? original.width
      : original.height;
  // Most photos fit at256px. Smaller passes impose the same encoded byte
  // ceiling even for high-entropy PNGs while retaining alpha where present.
  for (final dimension in const [
    CommunityPostImagePreview.maxDimension,
    192,
    128,
    96,
  ]) {
    final scale = longest > dimension ? dimension / longest : 1.0;
    final resized = scale < 1
        ? img.copyResize(
            original,
            width: (original.width * scale).round().clamp(1, dimension),
            height: (original.height * scale).round().clamp(1, dimension),
            interpolation: img.Interpolation.linear,
          )
        : original;
    final encoded = Uint8List.fromList(
      resized.hasAlpha
          ? img.encodePng(resized, level: 6)
          : img.encodeJpg(resized, quality: 84),
    );
    if (encoded.lengthInBytes <= CommunityPostImagePreview.maxBytes) {
      return CommunityPostImagePreview._(
        bytes: encoded,
        mimeType: resized.hasAlpha ? 'image/png' : 'image/jpeg',
        width: resized.width,
        height: resized.height,
      );
    }
  }
  throw const FormatException('Community preview exceeds its byte limit');
}
