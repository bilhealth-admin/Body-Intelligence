import 'dart:io';

import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    expect(service, contains('client.auth.getOAuthSignInUrl'));
    expect(service, contains('facebookOAuthLauncher.open'));
    expect(service, contains('signInWithAppleNative'));
    expect(service, contains('client.auth.signInWithIdToken'));
    expect(service, contains('client.auth.generateRawNonce'));
    expect(page, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    expect(page, isNot(contains('TargetPlatform.macOS')));
    expect(page, contains('authService.signInWithAppleNative()'));
    expect(page, contains("context.go('/startup')"));
    expect(page, contains('SignInWithAppleButton('));
    expect(page, contains('SignInWithAppleButtonStyle.black'));
    expect(page, contains('SignInWithAppleButtonStyle.white'));
    expect(service, contains("'https://www.bilhealth.com/auth/callback'"));
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

  test('Facebook OAuth selects the audited browser path per platform', () {
    expect(
      SupabaseAuthService.oauthLaunchModeFor(OAuthProvider.facebook),
      LaunchMode.inAppBrowserView,
    );
    expect(
      SupabaseAuthService.oauthLaunchModeFor(OAuthProvider.google),
      LaunchMode.externalApplication,
    );
    expect(
      SupabaseAuthService.oauthLaunchModeFor(OAuthProvider.apple),
      LaunchMode.externalApplication,
    );
    expect(
      SupabaseAuthService.usesNativeAndroidFacebookLauncher(
        OAuthProvider.facebook,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      SupabaseAuthService.usesNativeAndroidFacebookLauncher(
        OAuthProvider.facebook,
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
    expect(
      SupabaseAuthService.usesNativeAndroidFacebookLauncher(
        OAuthProvider.google,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      SupabaseAuthService.usesNativeAndroidFacebookLauncher(
        OAuthProvider.facebook,
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
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
