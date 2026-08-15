import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard Dart sources contain no binary visible-copy branches', () {
    final files = Directory('lib/features/dashboard')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    expect(files, isNotEmpty);
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('arabic ?')), reason: file.path);
      expect(source, isNot(contains('widget.arabic ?')), reason: file.path);
      expect(source, isNot(contains('=> arabic ? ar : en')), reason: file.path);
    }
  });

  test('shared dashboard fallback has authored production locales', () {
    final source = File(
      'lib/features/dashboard/dashboard_five_locale_copy.dart',
    ).readAsStringSync();
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(source, contains("'$locale':"), reason: locale);
    }
  });
}
