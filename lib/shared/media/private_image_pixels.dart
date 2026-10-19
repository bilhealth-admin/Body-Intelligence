import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Copy pixels into a fresh image, carrying no EXIF, XMP, comments or profiles.
img.Image privateImagePixels(img.Image source, {bool flattenAlpha = false}) {
  if (!source.hasAlpha) {
    final rgb = source.getBytes(order: img.ChannelOrder.rgb);
    return img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: rgb.buffer,
      bytesOffset: rgb.offsetInBytes,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );
  }
  final rgba = source.getBytes(order: img.ChannelOrder.rgba);
  if (!flattenAlpha) {
    final clean = Uint8List.fromList(rgba);
    for (var i = 0; i < clean.length; i += 4) {
      if (clean[i + 3] == 0) {
        clean[i] = clean[i + 1] = clean[i + 2] = 0;
      }
    }
    return img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: clean.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }
  final rgb = Uint8List(source.width * source.height * 3);
  for (var src = 0, dst = 0; src < rgba.length; src += 4, dst += 3) {
    final alpha = rgba[src + 3];
    for (var channel = 0; channel < 3; channel++) {
      rgb[dst + channel] =
          (rgba[src + channel] * alpha + 255 * (255 - alpha) + 127) ~/ 255;
    }
  }
  return img.Image.fromBytes(
    width: source.width,
    height: source.height,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}

/// A strict container check, used only after successful pixel decoding.
/// Unknown segments/chunks and trailing bytes force pixel-only re-encoding.
/// This preserves clean media byte-for-byte through repeated validation.
bool imageBytesAreMetadataFree(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return _cleanJpeg(bytes);
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
    var at = 8;
    final view = ByteData.sublistView(bytes);
    while (at + 12 <= bytes.length) {
      final size = view.getUint32(at);
      if (size > bytes.length - at - 12) return false;
      final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
      if (!const {'IHDR', 'PLTE', 'tRNS', 'IDAT', 'IEND'}.contains(type)) {
        return false;
      }
      at += size + 12;
      if (type == 'IEND') return size == 0 && at == bytes.length;
    }
    return false;
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(4, Endian.little) != bytes.length - 8) return false;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final type = String.fromCharCodes(bytes.sublist(at, at + 4));
      final size = view.getUint32(at + 4, Endian.little);
      if (size > bytes.length - at - 8 ||
          !const {'VP8X', 'ALPH', 'VP8 ', 'VP8L'}.contains(type)) {
        return false;
      }
      // ICC, EXIF, XMP and animation need normalization, even if malformed
      // flags claim a missing chunk. Only ordinary pixels/alpha pass through.
      if (type == 'VP8X' && (size != 10 || (bytes[at + 8] & 0x2e) != 0)) {
        return false;
      }
      at += 8 + size + (size & 1);
      if (at > bytes.length) return false;
      if (size.isOdd && bytes[at - 1] != 0) return false;
    }
    return at == bytes.length;
  }
  return false;
}

bool _cleanJpeg(Uint8List bytes) {
  var at = 2;
  var scan = false;
  const coding = {
    0xc0,
    0xc1,
    0xc2,
    0xc3,
    0xc4,
    0xc5,
    0xc6,
    0xc7,
    0xc9,
    0xca,
    0xcb,
    0xcc,
    0xcd,
    0xce,
    0xcf,
    0xda,
    0xdb,
    0xdc,
    0xdd,
    0xde,
    0xdf,
  };
  const jfif = [0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0];
  while (at < bytes.length) {
    int? marker;
    if (scan) {
      while (at < bytes.length) {
        if (bytes[at++] != 0xff) continue;
        while (at < bytes.length && bytes[at] == 0xff) {
          at++;
        }
        if (at == bytes.length) return false;
        final next = bytes[at++];
        if (next == 0 || next >= 0xd0 && next <= 0xd7) continue;
        marker = next;
        scan = false;
        break;
      }
    } else {
      if (bytes[at++] != 0xff) return false;
      while (at < bytes.length && bytes[at] == 0xff) {
        at++;
      }
      if (at == bytes.length) return false;
      marker = bytes[at++];
    }
    if (marker == null) return false;
    if (marker == 0xd9) return at == bytes.length;
    if (marker == 1 || marker >= 0xd0 && marker <= 0xd7) continue;
    if (at + 2 > bytes.length) return false;
    final size = bytes[at] * 256 + bytes[at + 1];
    if (size < 2 || size > bytes.length - at) return false;
    if (marker == 0xe0) {
      if (size != jfif.length + 2) return false;
      for (var i = 0; i < jfif.length; i++) {
        if (bytes[at + 2 + i] != jfif[i]) return false;
      }
    } else if (!coding.contains(marker)) {
      return false;
    }
    at += size;
    if (marker == 0xda) scan = true;
  }
  return false;
}
