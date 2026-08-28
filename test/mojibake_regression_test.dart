import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production text sources contain no common mojibake markers', () {
    final corruptionPatterns = <RegExp>[
      // UTF-8 Arabic bytes decoded as Latin-1 (for example U+00D8 U+00A7).
      RegExp(r'[\u00D8\u00D9][\u0080-\u00BF]'),
      // Requiring a continuation-byte character avoids rejecting valid text
      // such as "Âge" or "AÇÃO".
      RegExp(r'[\u00C2\u00C3][\u0080-\u00BF]'),
      // Mis-decoded smart punctuation: UTF-8 E2 80 xx decoded through a
      // Windows-1252/Latin-1 path commonly starts with â + euro.
      RegExp(r'\u00E2\u20AC.'),
      RegExp(r'\uFFFD'),
    ];
    const extensions = <String>{
      '.dart',
      '.arb',
      '.json',
      '.yaml',
      '.yml',
      '.txt',
      '.csv',
    };
    final violations = <String>[];

    for (final rootPath in const ['lib', 'assets']) {
      final root = Directory(rootPath);
      if (!root.existsSync()) continue;

      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('bil_locale_catalog_quality.dart')) {
          // This production validator intentionally stores mojibake signatures.
          continue;
        }
        final name = entity.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final extension = dot == -1 ? '' : name.substring(dot).toLowerCase();
        if (!extensions.contains(extension)) continue;

        String content;
        try {
          content = entity.readAsStringSync();
        } on FileSystemException {
          continue;
        }

        for (final pattern in corruptionPatterns) {
          if (pattern.hasMatch(content)) {
            violations.add('${entity.path}: matches ${pattern.pattern}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Corrupted production text was found:\n'
          '${violations.join('\n')}',
    );
  });
}
