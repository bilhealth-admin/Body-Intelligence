import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release remains Android-native and policy-minimal', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final auth = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final google = File(
      'lib/features/auth/native_google_sign_in.dart',
    ).readAsStringSync();

    expect(
      gradle,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(manifest, contains('android:resizeableActivity="true"'));
    expect(manifest, isNot(contains('android:screenOrientation=')));
    expect(main, contains('SystemUiMode.edgeToEdge'));
    expect(main, contains('DeviceOrientation.values'));

    final healthPermissions = RegExp(
      r'<uses-permission android:name="android\.permission\.health\.([A-Z0-9_]+)"\s*/>',
    ).allMatches(manifest).map((match) => match.group(1)).whereType<String>().toSet();
    expect(healthPermissions, <String>{
      'READ_STEPS',
      'READ_DISTANCE',
      'READ_ACTIVE_CALORIES_BURNED',
    });
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_VIDEO')));
    expect(manifest, isNot(contains('android.permission.READ_CONTACTS')));
    expect(manifest, contains('@style/HealthPermissionRationaleTheme'));
    expect(
      manifest,
      contains('Android Facebook sign-in intentionally uses Supabase'),
    );

    expect(auth, contains('usesNativeAndroidGoogleSignIn'));
    expect(auth, contains('usesNativeAndroidFacebookSignIn'));
    expect(google, contains('Android Credential Manager'));
    expect(google, contains('serverClientId: _serverClientId'));
    expect(
      google,
      contains('nonce: sha256.convert(utf8.encode(rawNonce)).toString()'),
    );
  });

  test(
    'iOS release remains Apple-native without a Flutter orientation override',
    () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final info = File('ios/Runner/Info.plist').readAsStringSync();
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      final auth = File(
        'lib/features/auth/supabase_auth_service.dart',
      ).readAsStringSync();

      expect(
        project,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;',
        ),
      );
      expect(project, contains('TARGETED_DEVICE_FAMILY = "1,2"'));
      expect(info, contains('<key>UISupportedInterfaceOrientations</key>'));
      expect(
        info,
        contains('<key>UISupportedInterfaceOrientations~ipad</key>'),
      );
      for (final orientation in <String>[
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]) {
        expect(info, contains(orientation));
      }
      expect(
        main,
        isNot(
          matches(
            RegExp(
              r'TargetPlatform\.iOS[\s\S]{0,320}'
              r'SystemChrome\.setPreferredOrientations',
            ),
          ),
        ),
      );

      for (final purpose in <String>[
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSMicrophoneUsageDescription',
        'NSSpeechRecognitionUsageDescription',
        'NSBluetoothAlwaysUsageDescription',
        'NSHealthShareUsageDescription',
        'NSHealthUpdateUsageDescription',
      ]) {
        expect(info, contains('<key>$purpose</key>'), reason: purpose);
      }
      expect(info, isNot(contains('NSUserTrackingUsageDescription')));
      expect(entitlements, contains('com.apple.developer.applesignin'));
      expect(entitlements, contains('com.apple.developer.healthkit'));
      expect(
        entitlements,
        contains('com.apple.developer.devicecheck.appattest-environment'),
      );
      expect(auth, contains('signInWithAppleNative'));
      expect(auth, contains('client.auth.generateRawNonce()'));
      expect(
        auth,
        contains('authorizationCode = credential.authorizationCode.trim()'),
      );
    },
  );

  test(
    'store restore and verification are platform-correct and fail closed',
    () {
      final restore = File(
        'lib/features/commerce/services/verified_store_purchase_restore.dart',
      ).readAsStringSync();
      final processing = File(
        'lib/features/commerce/services/verified_store_purchase_processing.dart',
      ).readAsStringSync();

      expect(restore, contains('Future<void> restore()'));
      expect(restore, contains('_syncAppleStoreForExplicitRestore()'));
      expect(restore, contains('await addition.sync()'));
      expect(restore, contains('await _purchase.restorePurchases()'));
      expect(processing, contains('case PurchaseStatus.pending:'));
      expect(processing, contains('_verifyOnServer'));
      expect(processing, contains('_verifyBoostOnServer'));
      expect(processing, contains('purchase.pendingCompletePurchase'));
      expect(processing, contains('.completePurchase(purchase)'));
      expect(processing, contains('queryPastPurchases()'));
    },
  );

  test('permissions and account deletion stay explicit and recoverable', () {
    final permissions = File(
      'lib/app/services/runtime_permission_policy.dart',
    ).readAsStringSync();
    final onboarding = File(
      'lib/features/onboarding/onboarding_detail_steps.dart',
    ).readAsStringSync();
    final deletion = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();

    expect(permissions, contains('BilRuntimeCapability.camera'));
    expect(permissions, contains('BilRuntimeCapability.microphone'));
    expect(permissions, contains('BilRuntimeCapability.notifications'));
    expect(permissions, isNot(contains('Permission.photos.request')));
    expect(onboarding, contains("actionLabel: t('Review permission')"));
    expect(onboarding, contains('requestPermission()'));
    expect(deletion, contains("'bil_request_account_deletion'"));
    expect(deletion, contains("toUpperCase() != 'DELETE'"));
    expect(deletion, contains('apps.apple.com/account/subscriptions'));
    expect(deletion, contains('play.google.com/store/account/subscriptions'));
    expect(deletion, contains('invalidateMatchingLocalSession'));
  });

  test('routes and production identifiers stay frozen', () {
    final routes = File('lib/app/router/app_router.dart').readAsStringSync();
    final android = File('android/app/build.gradle.kts').readAsStringSync();
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(routes, contains("path: '/dashboard'"));
    expect(routes, contains("path: '/help/delete-account'"));
    expect(
      android,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(
      ios,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.bilhealth.bodyintelligencelog;',
      ),
    );
  });
}
