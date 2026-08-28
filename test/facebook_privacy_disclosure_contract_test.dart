import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public and in-app policies disclose optional Facebook authentication',
    () {
      final publicPolicy = File('public_site/app.js').readAsStringSync();
      final inAppPolicy = File(
        'lib/features/settings/legal_document_page.dart',
      ).readAsStringSync();

      for (final source in <String>[publicPolicy, inAppPolicy]) {
        expect(source, contains('Optional Facebook Login'));
        expect(source, contains('public_profile'));
        expect(source, contains('email'));
        expect(source, contains('Supabase'));
        expect(source, contains('does not post to Facebook'));
        expect(source, contains('advertising'));
        expect(source, contains('delete'));
      }
    },
  );
}
