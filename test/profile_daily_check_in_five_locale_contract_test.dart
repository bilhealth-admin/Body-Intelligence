import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile and daily check-in contain no binary visible-copy branches',
    () {
      final files =
          [
            Directory('lib/features/profile'),
            Directory('lib/features/daily_check_in'),
          ].expand(
            (directory) => directory
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart')),
          );
      final visibleBranch = RegExp(
        r'''(?:\bar\b|arabic|isArabic)\s*\?\s*['"]''',
        multiLine: true,
      );
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(matches(visibleBranch)), reason: file.path);
        expect(source, isNot(contains('=> ar ?')), reason: file.path);
        expect(source, isNot(contains('=> arabic ?')), reason: file.path);
      }
    },
  );

  test('profile locale contract declares every production translation', () {
    final source = File(
      'lib/features/profile/profile_locale_copy.dart',
    ).readAsStringSync();
    for (final code in ['fr', 'es', 'tr']) {
      expect(source, contains("'$code':"));
    }
  });
}
