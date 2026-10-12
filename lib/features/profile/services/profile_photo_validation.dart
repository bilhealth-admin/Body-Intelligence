import 'dart:typed_data';
import 'package:image/image.dart' as image;

/// Used with compute so decoding corrupted persisted replacements cannot block
/// the frame or retire a previously decoded, same-owner account photo.
bool isDecodableProfilePhoto(Uint8List bytes) =>
    image.decodeImage(bytes) != null;
