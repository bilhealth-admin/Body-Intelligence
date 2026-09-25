import 'dart:io';

import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Android uses native Google and native OIDC login for Meta', () {
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final nativeGoogle = File(
      'lib/features/auth/native_google_sign_in.dart',
    ).readAsStringSync();
    final nativeFacebook = File(
      'lib/features/auth/native_facebook_sign_in.dart',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(service, contains('usesNativeAndroidGoogleSignIn'));
    expect(service, contains('usesNativeAndroidFacebookSignIn'));
    expect(service, contains('usesNativeGoogleSignIn('));
    expect(service, contains('usesNativeFacebookSignIn('));
    expect(service, isNot(contains('getOAuthSignInUrl')));
    expect(service, isNot(contains('BilGoogleOAuthLauncher')));
    expect(service, isNot(contains('BilFacebookOAuthLauncher')));

    // google_sign_in_android 7.2 implements Android Credential Manager. BIL
    // gives it the reviewed web client so the plugin does not need a browser
    // redirect or a generated google-services.json file.
    expect(nativeGoogle, contains('GoogleSignIn.instance.initialize('));
    expect(nativeGoogle, contains('serverClientId: _serverClientId'));
    expect(
      nativeGoogle,
      contains('nonce: sha256.convert(utf8.encode(rawNonce)).toString()'),
    );
    expect(nativeGoogle, contains('signIn.authenticate()'));
    expect(nativeGoogle, contains('authorizationForScopes'));
    expect(nativeGoogle, contains('authorizeScopes'));

    // Meta Android returns a ClassicToken. Supabase's Flutter Facebook
    // exchange accepts its tokenString as idToken; unlike iOS Limited Login,
    // this token is not nonce-bound and must not be treated as a JWT.
    expect(
      SupabaseAuthService.usesNativeAndroidFacebookSignIn(
        OAuthProvider.facebook,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(nativeFacebook, contains('FacebookAuth.instance.login('));
    expect(nativeFacebook, contains('ClassicToken(:final tokenString)'));
    expect(nativeFacebook, contains('LimitedToken(:final tokenString)'));
    expect(nativeFacebook, contains("'public_profile', 'email', 'openid'"));
    expect(nativeFacebook, contains('nonce: nonce'));
    expect(service, contains('nonce: token.nonce'));

    expect(manifest, contains('com.facebook.sdk.ApplicationId'));
    expect(manifest, contains('com.facebook.sdk.ClientToken'));
    expect(manifest, contains('com.facebook.sdk.AutoLogAppEventsEnabled'));
    expect(
      manifest,
      contains('com.facebook.sdk.AdvertiserIDCollectionEnabled'),
    );
    expect(
      manifest,
      contains('android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE'),
    );
    expect(strings, contains('Body Intelligence Log™'));
    expect(strings, contains('name="facebook_app_id"'));
    expect(strings, contains('name="facebook_client_token"'));
    expect(strings, contains('1384055070498598'));
    expect(gradle, contains('com.bilhealth.bodyintelligencelog'));
    expect(nativeFacebook, isNot(contains('print(')));
    expect(nativeFacebook, isNot(contains('debugPrint(')));

    expect(activity, isNot(contains('BILGoogleOAuthBridge')));
    expect(activity, isNot(contains('BILFacebookOAuthBridge')));
    expect(gradle, isNot(contains('androidx.browser:browser')));
    expect(
      File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGoogleOAuthBridge.kt',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFacebookOAuthBridge.kt',
      ).existsSync(),
      isFalse,
    );
  });
}
