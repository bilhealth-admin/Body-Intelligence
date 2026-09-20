import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unfinished provider linking is not exposed from settings', () {
    final page = File(
      'lib/features/settings/account_connection_settings_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final privacy = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();
    expect(page, contains('Account linking is unavailable on this build.'));
    expect(page, contains('onPressed: null'));
    expect(page, contains("Key('connect-\${provider.name}')"));
    expect(privacy, isNot(contains("account-connections/facebook")));
    expect(privacy, isNot(contains("account-connections/google")));
    expect(router, contains("'/settings/account-connections/facebook'"));
    expect(router, contains("'/settings/account-connections/google'"));
  });

  test('connection-settings copy has direct extended translations', () {
    const keys = <String>{
      'Facebook settings',
      'Google settings',
      'Account linking is unavailable on this build.',
      'BIL will enable this control only after the provider consent and account-linking flow is verified.',
      'Connect Facebook',
      'Connect Google',
    };
    for (final key in keys) {
      for (final locale in RuntimeCopy.supported.skip(5)) {
        final resolved = RuntimeCopy.resolve(key, locale);
        expect(resolved, isNotNull, reason: '$key / $locale');
        expect(resolved!.trim(), isNotEmpty, reason: '$key / $locale');
        expect(resolved, isNot(key), reason: 'English leak: $key / $locale');
      }
    }
  });
}
