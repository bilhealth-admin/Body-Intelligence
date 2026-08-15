import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium login exposes guarded Supabase OAuth and privacy', () {
    final page = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final copy = File(
      'lib/features/auth/auth_five_locale_copy.dart',
    ).readAsStringSync();

    for (final provider in ['google', 'apple', 'facebook']) {
      expect(page, contains('OAuthProvider.$provider'));
      expect(page, contains("Key('oauth-$provider')"));
    }
    expect(page, contains('AppEnvironment.cloudConfigured'));
    expect(page, contains("context.push('/legal/privacy')"));
    expect(service, contains('client.auth.signInWithOAuth'));
    expect(service, contains("'bil://auth-callback'"));
    expect(service, contains('redirectTo: oauthRedirectUri'));

    for (final key in [
      'Continue with Google',
      'Continue with Apple',
      'Continue with Facebook',
      'We will never post anything without your permission.',
      'Read the Privacy Policy',
      'This sign-in provider is unavailable or not configured.',
      'Could not open secure sign-in. Try again.',
    ]) {
      expect(copy, contains("'$key':"), reason: key);
    }
  });

  test('new premium login copy is clean UTF-8', () {
    final page = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();
    for (final marker in ['Ã', 'Â', 'â€™', 'â€”', 'Ø§', 'Ù']) {
      expect(page, isNot(contains(marker)), reason: marker);
    }
  });
}
