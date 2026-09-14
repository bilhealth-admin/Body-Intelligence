import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal vision decoding and compression stay off the UI isolate', () {
    final source = File(
      'lib/features/nutrition/services/meal_vision_image_preprocessor.dart',
    ).readAsStringSync();

    expect(source, contains("import 'package:flutter/foundation.dart';"));
    expect(source, contains('await compute(_prepareMealVisionImage'));
    expect(source, contains('img.decodeImage(original)'));
    expect(source, contains('img.encodeJpg(resized'));
  });
}
