import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding contains no Arabic-English visible-copy ternaries', () {
    final files = Directory('lib/features/onboarding')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final visibleCopyBranch = RegExp(
      r'''(?:isArabic|_isArabic|\bar\b)\s*\?\s*['"]''',
      multiLine: true,
    );
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(matches(visibleCopyBranch)), reason: file.path);
      expect(
        source,
        isNot(contains('=> isArabic ? ar : en')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('=> _isArabic ? ar : en')),
        reason: file.path,
      );
      expect(source, isNot(contains('=> ar ? arText : en')), reason: file.path);
    }
  });

  test('onboarding locale contract declares all production languages', () {
    final source = File(
      'lib/features/onboarding/onboarding_locale_copy.dart',
    ).readAsStringSync();
    for (final code in ['fr', 'es', 'tr']) {
      expect(source, contains("'$code':"));
    }
  });
}
