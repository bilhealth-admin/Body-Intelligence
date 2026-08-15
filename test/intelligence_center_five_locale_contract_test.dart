import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intelligence center has no binary visible-copy branches', () {
    final files = Directory('lib/features/intelligence_center')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final visibleBranch = RegExp(
      r'''(?:arabic|isArabic|\bar\b)\s*\?\s*['"]''',
      multiLine: true,
    );
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(matches(visibleBranch)), reason: file.path);
      expect(source, isNot(contains('=> arabic ?')), reason: file.path);
      expect(source, isNot(contains('=> ar ?')), reason: file.path);
      for (final marker in ['Ø', 'Ù', 'Ã']) {
        expect(source, isNot(contains(marker)), reason: file.path);
      }
    }
  });

  test('intelligence locale contract declares every production language', () {
    final source = File(
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
    ).readAsStringSync();
    for (final code in ['fr', 'es', 'tr']) {
      expect(source, contains("'$code':"));
    }
  });
}
