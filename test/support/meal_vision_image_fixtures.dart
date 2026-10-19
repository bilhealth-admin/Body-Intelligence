import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List validMealVisionJpegBytes() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 32, height: 24)));

Uint8List validMealVisionPngBytes() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 24)));
