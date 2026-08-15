import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics and weekly report use five-locale copy recursively', () {
    final root = Directory('lib/features/analytics');
    final sources = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources, contains("'ar'"));
    expect(sources, contains("'en'"));
    expect(sources, contains("'fr'"));
    expect(sources, contains("'es'"));
    expect(sources, contains("'tr'"));
    expect(sources, isNot(contains('arabic ?')));
    expect(sources, isNot(contains('=> arabic ?')));
    expect(sources, isNot(contains('Ø')));
    expect(sources, isNot(contains('Ù')));
  });
}
