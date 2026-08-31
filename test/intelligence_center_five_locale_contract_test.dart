import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intelligence center has no binary visible-copy branches', () {
    final files = Directory('lib/features/intelligence_center')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final localeStringBranch = RegExp(
      r'''(?:arabic|isArabic|\bar\b)\s*\?\s*(['"])(.*?)\1\s*:\s*(['"])(.*?)\3''',
      multiLine: true,
      dotAll: true,
    );
    final visibleLetter = RegExp(r'[A-Za-z\u0600-\u06FF]');
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in localeStringBranch.allMatches(source)) {
        final choices = [match.group(2)!, match.group(4)!].map(
          (choice) => choice.replaceAll(
            RegExp(r'''\\(?:u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|.)'''),
            '',
          ),
        );
        expect(
          choices.any(visibleLetter.hasMatch),
          isFalse,
          reason:
              '${file.path}: locale ternaries may select punctuation, but '
              'visible copy must come from the locale catalog.',
        );
      }
      for (final marker in ['Ø', 'Ù', 'Ã']) {
        expect(source, isNot(contains(marker)), reason: file.path);
      }
    }
  });

  test('intelligence locale contract declares every production language', () {
    final source = [
      'lib/features/intelligence_center/intelligence_locale_copy.dart',
      'lib/features/intelligence_center/intelligence_service_locale_copy.dart',
      'lib/features/intelligence_center/intelligence_ui_locale_copy.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    for (final code in ['fr', 'es', 'tr']) {
      expect(source, contains("'$code':"));
    }
  });
}
