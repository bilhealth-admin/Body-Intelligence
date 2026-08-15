import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('services contain no binary visible copy or mojibake', () {
    final files = Directory('lib/features/intelligence_center/services')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final visibleBranch = RegExp(r'''(?:arabic|isArabic)\s*\?\s*['"]''');
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(matches(visibleBranch)), reason: file.path);
      for (final marker in ['Ã˜', 'Ã™', 'Ãƒ', 'Ø', 'Ù']) {
        expect(source, isNot(contains(marker)), reason: file.path);
      }
    }
  });

  test('command labels and intents support all production locales', () {
    const parser = LocalCoachCommandParser();
    final cases = <(String, String)>[
      ('fr', 'supprimer mon compte'),
      ('es', 'eliminar mi cuenta'),
      ('tr', 'hesabımı sil'),
    ];
    for (final (locale, command) in cases) {
      final actions = parser.parse(command, locale: locale);
      expect(actions, hasLength(1));
      expect(actions.single.label, isNot(contains('Review account')));
      expect(actions.single.destructive, isTrue);
    }
  });
}
