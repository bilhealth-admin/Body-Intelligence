import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Facebook sign-in uses HTTPS Supabase OAuth without native Meta SDK',
    () {
      final service = File(
        'lib/features/auth/supabase_auth_service.dart',
      ).readAsStringSync();
      final loginPage = File(
        'lib/features/auth/premium_login_page.dart',
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
      expect(loginPage, isNot(contains('nativeFacebook')));
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
        ]) {
          expect(source, isNot(contains(removed)), reason: removed);
        }
      }
    },
  );
}
