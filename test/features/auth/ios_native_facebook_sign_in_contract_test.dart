import 'dart:io';

import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Facebook OAuth uses iOS system auth session without native Meta SDK',
    () {
      final service = File(
        'lib/features/auth/supabase_auth_service.dart',
      ).readAsStringSync();
      final loginPage = File(
        'lib/features/auth/premium_login_page.dart',
      ).readAsStringSync();
      final nativeTransport = File(
        'lib/features/auth/native_facebook_oauth.dart',
      ).readAsStringSync();
      final nativeBridge = File(
        'ios/Runner/BILFacebookOAuthBridge.swift',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final lock = File('pubspec.lock').readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final generatedRegistrant = File(
        'ios/Runner/GeneratedPluginRegistrant.m',
      ).readAsStringSync();
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final sceneDelegate = File(
        'ios/Runner/SceneDelegate.swift',
      ).readAsStringSync();
      final iosProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final privacyManifest = File(
        'ios/Runner/PrivacyInfo.xcprivacy',
      ).readAsStringSync();
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final androidStrings = File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsStringSync();

      expect(loginPage, contains("OAuthProvider.facebook"));
      expect(loginPage, contains("Key('oauth-facebook')"));
      expect(loginPage, contains('authService.signInWithOAuth(provider)'));
      // Apple AuthenticationServices is an OS OAuth transport, not Meta SDK.
      // Exercise the actual platform selector rather than banning its variable.
      for (final platform in TargetPlatform.values) {
        expect(
          SupabaseAuthService.usesNativeFacebookOAuth(
            OAuthProvider.facebook,
            isWeb: false,
            platform: platform,
          ),
          platform == TargetPlatform.iOS,
        );
        expect(
          SupabaseAuthService.usesNativeFacebookOAuth(
            OAuthProvider.facebook,
            isWeb: true,
            platform: platform,
          ),
          isFalse,
        );
      }
      for (final provider in [OAuthProvider.google, OAuthProvider.apple]) {
        expect(
          SupabaseAuthService.usesNativeFacebookOAuth(
            provider,
            isWeb: false,
            platform: TargetPlatform.iOS,
          ),
          isFalse,
        );
      }
      expect(
        loginPage,
        contains('SupabaseAuthService.usesNativeFacebookOAuth('),
      );
      expect(
        service,
        contains('BilNativeFacebookOAuth().authenticate(client)'),
      );
      expect(nativeTransport, contains("MethodChannel('bil/facebook_oauth')"));
      expect(appDelegate, contains('BILFacebookOAuthBridge('));
      expect(nativeBridge, contains('import AuthenticationServices'));
      expect(nativeBridge, contains('ASWebAuthenticationSession('));
      expect(nativeBridge, contains('if #available(iOS 17.4, *)'));
      expectIosFacebookSystemSessionCallbackPolicy(nativeBridge);
      expect(
        SupabaseAuthService.oauthRedirectUriFor(
          OAuthProvider.facebook,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        SupabaseAuthService.oauthRedirectUri,
      );
      expect(
        SupabaseAuthService.oauthLaunchModeFor(
          OAuthProvider.facebook,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        LaunchMode.externalApplication,
      );
      expect(service, contains('client.auth.signInWithOAuth('));
      expect(service, contains("'https://www.bilhealth.com/auth/callback'"));
      expect(service, contains('authScreenLaunchMode: oauthLaunchModeFor('));
      expect(service, isNot(contains('signInWithFacebookNative')));
      expect(service, isNot(contains('BilFacebookSessionAuthority')));

      expect(
        File('lib/features/auth/native_facebook_sign_in.dart').existsSync(),
        isFalse,
      );
      for (final source in [pubspec, lock]) {
        expect(source, isNot(contains('flutter_facebook_auth')));
        expect(
          source,
          isNot(contains('flutter_facebook_auth_platform_interface')),
        );
        expect(source, isNot(contains('flutter_facebook_auth_web')));
      }
      for (final source in [
        plist,
        generatedRegistrant,
        appDelegate,
        nativeTransport,
        nativeBridge,
        sceneDelegate,
        iosProject,
        privacyManifest,
        androidManifest,
        androidStrings,
      ]) {
        for (final removed in [
          'FacebookAppID',
          'FacebookClientToken',
          'FacebookDisplayName',
          'fb1384055070498598',
          'LSApplicationQueriesSchemes',
          'fbapi',
          'fb-messenger-share-api',
          'com.facebook.sdk',
          'facebook_app_id',
          'facebook_client_token',
          'FlutterFacebookAuthPlugin',
          'FBSDKCoreKit',
          'FBSDKLoginKit',
          'FBAEMKit',
          'FacebookCore',
          'FacebookLogin',
        ]) {
          expect(source, isNot(contains(removed)), reason: removed);
        }
      }
    },
  );
}

/// The same guard is used by the actual source contract and external RED/GREEN
/// input fixtures. This checks source policy, not successful native OS startup.
void expectIosFacebookSystemSessionCallbackPolicy(String nativeBridge) {
  expect(nativeBridge, contains('static let callbackMode = "legacy"'));
  expect(nativeBridge, contains('result(Self.callbackMode)'));
  expect(nativeBridge, contains('callback: .customScheme("bil")'));
  expect(nativeBridge, contains('callbackURLScheme: "bil"'));
  expect(nativeBridge, contains('usesHTTPS: Self.callbackMode == "https"'));
  expect(nativeBridge, isNot(contains('callback: .https(')));
}
