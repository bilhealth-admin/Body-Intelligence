import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Google sign-in uses the reviewed native client and return scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final nativeGoogle = File(
      'lib/features/auth/native_google_sign_in.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();

    expect(plist, contains('Body Intelligence Log™'));
    expect(plist, contains('<key>GIDClientID</key>'));
    expect(
      plist,
      contains(
        '1041595138122-1bpu2k7vs1fjkkm1d3tg6o0rnn4i15fh.apps.googleusercontent.com',
      ),
    );
    expect(plist, contains('<key>GIDServerClientID</key>'));
    expect(
      plist,
      contains(
        '1041595138122-hpe2ke9c5rpphijvmk2ssvsbggvbp14j.apps.googleusercontent.com',
      ),
    );
    expect(plist, contains('<string>bil</string>'));
    expect(
      plist,
      contains(
        'com.googleusercontent.apps.1041595138122-1bpu2k7vs1fjkkm1d3tg6o0rnn4i15fh',
      ),
    );

    expect(nativeGoogle, contains('GoogleSignIn.instance.initialize('));
    expect(nativeGoogle, contains('serverClientId: _serverClientId'));
    expect(nativeGoogle, contains('signIn.authenticate()'));
    expect(nativeGoogle, contains('authorizationForScopes'));
    expect(nativeGoogle, contains('authorizeScopes'));
    expect(nativeGoogle, contains('GoogleSignInExceptionCode.canceled'));
    expect(service, contains('client.auth.signInWithIdToken'));
    expect(service, contains('accessToken: tokens.accessToken'));
  });
}
