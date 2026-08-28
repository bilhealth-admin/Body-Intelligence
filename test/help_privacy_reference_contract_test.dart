import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'help delete-account action uses the real deletion request workflow',
    () {
      final help = File(
        'lib/features/settings/help_center_page.dart',
      ).readAsStringSync();
      final deletion = File(
        'lib/features/settings/account_deletion_page.dart',
      ).readAsStringSync();
      final router = File('lib/app/router/app_router.dart').readAsStringSync();

      expect(help, contains("context.push('/help/delete-account')"));
      expect(help, isNot(contains("_email('BIL account deletion request')")));
      expect(deletion, contains("'bil_request_account_deletion'"));
      expect(deletion, contains("client.auth.currentUser == null"));
      expect(deletion, contains("toUpperCase() != 'DELETE'"));
      expect(router, contains("path: '/help/delete-account'"));
    },
  );

  test('privacy shell exposes all reference destinations in five locales', () {
    final source = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();

    for (final locale in const ["'en'", "'ar'", "'fr'", "'es'", "'tr'"]) {
      expect(source, contains(locale));
    }
    for (final route in const [
      '/legal/terms',
      '/legal/privacy',
      '/advertising-privacy',
      '/settings/email',
      '/trust-support',
    ]) {
      expect(source, contains(route));
    }
    expect(source, contains('privacy@bilhealth.com'));
  });
}
