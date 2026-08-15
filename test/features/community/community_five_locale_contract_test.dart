import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory('lib/features/community');
  final dartFiles = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('community visible copy has no Arabic-English binary branches', () {
    final source = dartFiles.map((file) => file.readAsStringSync()).join('\n');
    expect(source, isNot(contains('arabic ?')));
    expect(source, isNot(contains('_arabic ?')));
    expect(source, isNot(contains('widget.arabic')));
    expect(source, isNot(contains('required this.arabic')));
  });

  test('community copy explicitly supports all five release locales', () {
    final copy = File(
      'lib/features/community/presentation/community_copy.dart',
    ).readAsStringSync();
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(copy, contains("'$locale': {"), reason: locale);
    }
    final localizedPages =
        [
          'community_profile_page.dart',
          'community_people_page.dart',
          'community_connections_page.dart',
        ].map(
          (name) => File(
            'lib/features/community/presentation/$name',
          ).readAsStringSync(),
        );
    for (final source in localizedPages) {
      for (final locale in const ["'ar'", "'fr'", "'es'", "'tr'"]) {
        expect(source, contains(locale));
      }
    }
  });

  test('community sources contain no common mojibake markers', () {
    final source = dartFiles.map((file) => file.readAsStringSync()).join('\n');
    for (final marker in const ['Ã', 'Â', 'Ø', 'Ù', 'â€™']) {
      expect(source, isNot(contains(marker)), reason: marker);
    }
  });
}
