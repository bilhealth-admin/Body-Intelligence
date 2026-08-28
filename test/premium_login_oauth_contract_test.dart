import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium login exposes guarded OAuth and required privacy access', () {
    final page = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();

    for (final provider in ['google', 'apple', 'facebook']) {
      expect(page, contains('OAuthProvider.$provider'));
      expect(page, contains("Key('oauth-$provider')"));
    }
    expect(page, contains('AppEnvironment.cloudConfigured'));
    expect(page, contains("context.push('/legal/privacy')"));
    expect(page, contains('AuthEntryCopyKey.privacyPolicy'));
    expect(service, contains('client.auth.signInWithOAuth'));
    expect(service, contains("'bil://auth-callback'"));
    expect(service, contains('redirectTo: oauthRedirectUri'));

    for (final removed in [
      'Welcome back',
      'Your private health intelligence is ready',
      'We will never post anything without your permission',
      'Continue privately on this device',
      'Create a BIL account',
    ]) {
      expect(page, isNot(contains(removed)), reason: removed);
    }
  });

  test('ordinary emulator builds cannot silently disable production auth', () {
    final environment = File(
      'lib/app/environment/app_environment.dart',
    ).readAsStringSync();
    expect(
      environment,
      contains("defaultValue: 'https://tgmanzhqulksykhslrzb.supabase.co'"),
    );
    expect(environment, contains("defaultValue: 'sb_publishable_"));
    expect(
      environment,
      contains("'BIL_USE_SUPABASE',\n    defaultValue: true"),
    );
  });

  test('new premium login source is clean UTF-8', () {
    final page = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();
    for (final marker in ['Ã', 'Â', 'â€™', 'â€”', 'Ø§', 'Ù']) {
      expect(page, isNot(contains(marker)), reason: marker);
    }
  });
}
