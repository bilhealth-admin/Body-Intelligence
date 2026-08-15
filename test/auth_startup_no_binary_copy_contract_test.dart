import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth and startup contain no binary visible-copy branches', () {
    final files = [
      ...Directory('lib/features/auth').listSync(recursive: true),
      ...Directory('lib/features/startup').listSync(recursive: true),
    ].whereType<File>().where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('arabic ?')), reason: file.path);
      expect(source, isNot(contains('=> arabic ? ar : en')), reason: file.path);
      expect(source, isNot(contains('Ø')), reason: file.path);
      expect(source, isNot(contains('Ù')), reason: file.path);
    }
  });

  test('auth copy contract includes all production languages', () {
    final source = File(
      'lib/features/auth/auth_five_locale_copy.dart',
    ).readAsStringSync();
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(source, contains("'$locale':"), reason: locale);
    }
    expect(source, contains('authFiveLocaleTextFor'));
  });
}
