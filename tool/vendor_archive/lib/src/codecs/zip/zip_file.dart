import 'dart:typed_data';

import '../../archive/compression_type.dart';
import '../../util/crc32.dart';
import '../../util/file_content.dart';
import '../../util/input_memory_stream.dart';
import '../../util/input_stream.dart';
import '../../util/output_memory_stream.dart';
import '../../util/output_stream.dart';
import '../bzip2_decoder.dart';
import '../zlib_decoder.dart';
import 'zip_file_header.dart';

const _compressionTypes = <int, CompressionType>{
  0: CompressionType.none,
  8: CompressionType.deflate,
  12: CompressionType.bzip2,
};

/// A file object used by [ZipDecoder].
class ZipFile extends FileContent {
  static const zipSignature = 0x04034b50;
  static const zipCompressionStore = 0;
  static const zipCompressionDeflate = 8;
  static const zipCompressionBZip2 = 12;
  int version = 0;
  int flags = 0;
  CompressionType compressionMethod = CompressionType.none;
  int lastModFileTime = 0;
  int lastModFileDate = 0;
  int crc32 = 0;
  int compressedSize = 0;
  int uncompressedSize = 0;
  String filename = '';
  Uint8List? extraField;
  ZipFileHeader? header;

  // Content of the file. If compressionMethod is not STORE, then it is
  // still compressed.
  InputStream? _rawContent;
  int? _computedCrc32;
  ZipFile(this.header);

  @override
  bool get isCompressed =>
      _rawContent != null && compressionMethod != CompressionType.none;

  void read(InputStream input, {String? password}) {
    if (password != null) {
      throw UnsupportedError(
        'Encrypted ZIP archives are disabled in the BIL crypto-free archive fork.',
      );
    }
    final sig = input.readUint32();
    if (sig != zipSignature) {
      return;
    }

    version = input.readUint16();
    flags = input.readUint16();
    final compression = input.readUint16();
    compressionMethod = _compressionTypes[compression] ?? CompressionType.none;
    lastModFileTime = input.readUint16();
    lastModFileDate = input.readUint16();
    crc32 = input.readUint32();
    compressedSize = input.readUint32();
    uncompressedSize = input.readUint32();
    final fnLen = input.readUint16();
    final exLen = input.readUint16();
    filename = input.readString(size: fnLen);
    extraField = input.readBytes(exLen).toUint8List();

    // Use the compressedSize and uncompressedSize from the CFD header.
    // For Zip64, the sizes in the local header will be 0xFFFFFFFF.
    compressedSize = header?.compressedSize ?? compressedSize;
    uncompressedSize = header?.uncompressedSize ?? uncompressedSize;

    if ((flags & 0x1) != 0) {
      throw UnsupportedError(
        'Encrypted ZIP archives are disabled in the BIL crypto-free archive fork.',
      );
    }

    // Read compressedSize bytes for the compressed data.
    _rawContent = input.readBytes(header!.compressedSize);

    // If bit 3 (0x08) of the flags field is set, then the CRC-32 and file
    // sizes are not known when the header is written. The fields in the
    // local header are filled with zero, and the CRC-32 and size are
    // appended in a 12-byte structure (optionally preceded by a 4-byte
    // signature) immediately after the compressed data:
    if (flags & 0x08 != 0) {
      final sigOrCrc = input.readUint32();
      if (sigOrCrc == 0x08074b50) {
        crc32 = input.readUint32();
      } else {
        crc32 = sigOrCrc;
      }

      compressedSize = input.readUint32();
      uncompressedSize = input.readUint32();
    }
  }

  /// This will decompress the data (if necessary) in order to calculate the
  /// crc32 checksum for the decompressed data and verify it with the value
  /// stored in the zip.
  bool verifyCrc32() {
    final contentStream = getStream();
    _computedCrc32 ??= getCrc32(contentStream.toUint8List());
    return _computedCrc32 == crc32;
  }

  @override
  void decompress(OutputStream output) {
    if (_rawContent == null) {
      return;
    }

    if (compressionMethod == CompressionType.deflate) {
      final savePos = _rawContent!.position;
      ZLibDecoder().decodeStream(_rawContent!, output, raw: true);
      _rawContent!.setPosition(savePos);
    } else if (compressionMethod == CompressionType.bzip2) {
      final savePos = _rawContent!.position;
      BZip2Decoder().decodeStream(_rawContent!, output);
      _rawContent!.setPosition(savePos);
    } else {
      output.writeStream(_rawContent!);
    }
  }

  @override
  int get length => getRawContent().length;

  /// Get the decompressed content from the file. The file isn't decompressed
  /// until it is requested.
  @override
  InputStream getStream({bool decompress = true}) {
    if (_rawContent == null) {
      return InputMemoryStream(Uint8List(0));
    }
    if (!decompress) {
      return _rawContent!;
    }

    const maxDecodeBufferSize = 500 * 1024 * 1024; // 500MB

    if (compressionMethod == CompressionType.deflate) {
      final savePos = _rawContent!.position;
      late Uint8List content;
      if (_rawContent!.length <= maxDecodeBufferSize) {
        final compressed = _rawContent!.toUint8List();
        content = ZLibDecoder().decodeBytes(compressed, raw: true);
      } else {
        final decompress = OutputMemoryStream(size: uncompressedSize);
        ZLibDecoder().decodeStream(_rawContent!, decompress, raw: true);
        content = decompress.getBytes();
      }
      _rawContent!.setPosition(savePos);
      return InputMemoryStream(content);
    } else if (compressionMethod == CompressionType.bzip2) {
      final output = OutputMemoryStream();
      final savePos = _rawContent!.position;
      BZip2Decoder().decodeStream(_rawContent!, output);
      final content = output.getBytes();
      _rawContent!.setPosition(savePos);
      return InputMemoryStream(content);
    } else {
      final content = _rawContent!.toUint8List();
      return InputMemoryStream(content);
    }
  }

  Uint8List getRawContent() {
    if (_rawContent == null) {
      return Uint8List(0);
    }
    return _rawContent!.toUint8List();
  }

  @override
  String toString() => filename;

  @override
  Future<void> close() async {
    await _rawContent?.close();
  }

  @override
  void closeSync() {
    _rawContent?.closeSync();
  }

  @override
  void write(OutputStream output) => output.writeStream(getStream());
}
