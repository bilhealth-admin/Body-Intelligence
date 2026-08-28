import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commerce and Coach UI contain no hardcoded monetary price', () {
    final roots = [
      Directory('lib/features/commerce'),
      Directory('lib/features/intelligence_center'),
    ];
    final monetary = RegExp(
      r'(?<!\.)\$\s*\d|€\s*\d|£\s*\d|\d+[.,]\d{2}\s*(?:\$|USD|EUR|GBP)',
      caseSensitive: false,
    );
    final violations = <String>[];
    for (final root in roots) {
      for (final file
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        if (monetary.hasMatch(file.readAsStringSync())) {
          violations.add(file.path);
        }
      }
    }
    expect(violations, isEmpty);
  });
}
