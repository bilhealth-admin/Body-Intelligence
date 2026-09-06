import 'package:mobile_scanner/mobile_scanner.dart';

/// Extracts the first non-empty scanner value for both live-camera and image
/// analysis captures. Validation stays downstream in BarcodeIdentity.
String? barcodeRawValueFromCapture(BarcodeCapture? capture) {
  if (capture == null) return null;
  return capture.barcodes
      .map((barcode) => barcode.rawValue?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .firstOrNull;
}

typedef BarcodeGalleryPickResult<T> = ({T? value, Object? error});

/// Keeps native photo-picker failures inside the barcode route instead of
/// surfacing them as unhandled async callback errors.
Future<BarcodeGalleryPickResult<T>> guardBarcodeGalleryPick<T>(
  Future<T?> Function() picker,
) async {
  try {
    return (value: await picker(), error: null);
  } on Object catch (error) {
    return (value: null, error: error);
  }
}
