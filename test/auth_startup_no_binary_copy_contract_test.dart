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

  test('redesigned auth copy uses exact authored locale lookup', () {
    final source = File(
      'lib/features/auth/auth_entry_locale_copy.dart',
    ).readAsStringSync();
    expect(source, contains('authEntryHasExactLocale'));
    expect(source, contains('authEntryHasExactCopy'));
    expect(source, contains("'email': email"));
    expect(source, contains("'time': clock"));
  });
}
