import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart sources contain no common UTF-8 mojibake signatures', () {
    const forbidden = <String>[
      'Ãƒ',
      'Ã¢',
      'Ã©',
      'Ã¨',
      'Ãª',
      'Ã¼',
      'Â·',
      'Â ',
      'Â©',
      'Ø§',
      'Ø¹',
      'Ù„',
      'Ù…',
      'â€™',
      'â€œ',
      'â€',
      'â€“',
      'â€”',
      'ðŸ',
      '\uFFFD',
    ];
    final violations = <String>[];
    for (final file in _dartSources()) {
      final source = file.readAsStringSync();
      for (final signature in forbidden) {
        if (source.contains(signature)) {
          violations.add('${file.path}: $signature');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('production sources never expose translation-system failure copy', () {
    const forbiddenPhrases = <String>[
      'translation_unavailable',
      'Text unavailable in your language',
      'Texte indisponible dans votre langue',
      'Texto no disponible en tu idioma',
      'Metin dilinizde kullanılamıyor',
      'النص غير متاح بلغتك',
    ];
    final violations = <String>[];
    for (final file in _dartSources()) {
      final source = file.readAsStringSync();
      for (final phrase in forbiddenPhrases) {
        if (source.contains(phrase)) violations.add('${file.path}: $phrase');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<File> _dartSources() => Directory('lib')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
