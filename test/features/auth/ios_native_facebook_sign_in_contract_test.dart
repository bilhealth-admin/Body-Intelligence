import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Facebook sign-in uses Meta SDK and exchanges a native token', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final nativeFacebook = File(
      'lib/features/auth/native_facebook_sign_in.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final loginPage = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();

    expect(plist, contains('<key>FacebookAppID</key>'));
    expect(plist, contains('<string>1384055070498598</string>'));
    expect(plist, contains('<key>FacebookClientToken</key>'));
    expect(plist, contains('<key>FacebookDisplayName</key>'));
    expect(plist, contains('<string>Body Intelligence Log™</string>'));
    expect(plist, contains('<string>fb1384055070498598</string>'));
    expect(plist, contains('<string>fbapi</string>'));

    expect(nativeFacebook, contains('FacebookAuth.instance.login('));
    expect(nativeFacebook, contains("'public_profile', 'email', 'openid'"));
    expect(nativeFacebook, contains('LoginTracking.limited'));
    expect(nativeFacebook, contains('LoginBehavior.nativeWithFallback'));
    expect(nativeFacebook, contains('LoginStatus.cancelled'));
    expect(nativeFacebook, contains('LimitedToken(:final tokenString)'));
    expect(
      nativeFacebook,
      contains('ClassicToken(:final authenticationToken)'),
    );

    expect(service, contains('usesNativeIosFacebookSignIn'));
    expect(service, contains('signInWithFacebookNative'));
    expect(service, contains('provider: OAuthProvider.facebook'));
    expect(service, contains('idToken: token.idToken'));
    expect(service, contains('nonce: token.nonce'));
    expect(service, isNot(contains('LaunchMode.inAppBrowserView')));
    expect(loginPage, contains('authService.signInWithFacebookNative()'));
    expect(loginPage, contains('nativeGoogle && !nativeFacebook'));
  });
}
