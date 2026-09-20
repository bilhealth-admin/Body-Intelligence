import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UIScene native presenters never depend on AppDelegate.window', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final sceneDelegate = File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(plist, contains('UIApplicationSceneManifest'));
    expect(plist, contains(r'$(PRODUCT_MODULE_NAME).SceneDelegate'));
    expect(sceneDelegate, contains('FlutterSceneDelegate'));
    expect(appDelegate, contains('UIApplication.shared.connectedScenes'));
    expect(appDelegate, contains('contact_picker_unavailable'));
    expect(appDelegate, isNot(contains('self.window?.rootViewController')));
  });

  test('iOS permission and camera lifecycle operations are race safe', () {
    final speech = File('ios/Runner/BILSpeechBridge.swift').readAsStringSync();
    final camera = File(
      'lib/shared/widgets/bil_camera_capture_page.dart',
    ).readAsStringSync();
    final lifecycleStart = camera.indexOf('void didChangeAppLifecycleState');
    final lifecycleEnd = camera.indexOf(
      'Future<void> _capture()',
      lifecycleStart,
    );
    final lifecycle = camera.substring(lifecycleStart, lifecycleEnd);

    expect(speech, contains('pendingStartResult'));
    expect(speech, contains('finishPendingStart(nil)'));
    expect(speech, contains('case .authorized, .notDetermined:'));
    expect(speech, contains('case .denied, .restricted:'));
    expect(speech, isNot(contains('authorizationStatus() != .restricted')));
    expect(speech, contains('session.isInputAvailable'));
    expect(speech, contains('format.sampleRate > 0'));
    expect(camera, contains('_serializeCameraOperation'));
    expect(camera, contains('_cameraShouldRun = false'));
    // Permission sheets temporarily make iOS inactive. Stopping the camera
    // only for hidden/paused/detached prevents a permission-resume race.
    expect(lifecycle, isNot(contains('AppLifecycleState.inactive')));
  });

  test(
    'Apple capabilities and iOS-native interaction contracts stay enabled',
    () {
      final debugEntitlements = File(
        'ios/Runner/RunnerDebug.entitlements',
      ).readAsStringSync();
      final releaseEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final auth = File(
        'lib/features/auth/supabase_auth_service.dart',
      ).readAsStringSync();
      final profilePhoto = File(
        'lib/features/profile/services/profile_photo_service.dart',
      ).readAsStringSync();
      final appTheme = File(
        'lib/app/theme/app_theme_data.dart',
      ).readAsStringSync();
      final flagshipTheme = File(
        'lib/app/theme/bil_flagship_theme.dart',
      ).readAsStringSync();

      expect(debugEntitlements, contains('<string>development</string>'));
      expect(releaseEntitlements, contains('<string>production</string>'));
      for (final entitlements in [debugEntitlements, releaseEntitlements]) {
        expect(entitlements, contains('com.apple.developer.applesignin'));
        expect(entitlements, contains('com.apple.developer.healthkit'));
      }
      expect(project, contains('TARGETED_DEVICE_FAMILY = "1,2"'));
      expect(
        project,
        isNot(
          contains(
            'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon',
          ),
        ),
      );
      expect(auth, contains('signInWithAppleNative'));
      expect(auth, contains('generateRawNonce'));
      expect(auth, contains('nonce: rawNonce'));
      expect(profilePhoto, contains('image_picker.ImageSource.gallery'));
      expect(
        appTheme,
        contains('TargetPlatform.iOS: CupertinoPageTransitionsBuilder()'),
      );
      expect(
        flagshipTheme,
        contains('TargetPlatform.iOS: CupertinoPageTransitionsBuilder()'),
      );
    },
  );

  test('iOS review flows do not put a deferrable BIL dialog before consent', () {
    final onboarding = File(
      'lib/features/onboarding/onboarding_page.dart',
    ).readAsStringSync();
    final completion = File(
      'lib/features/onboarding/domain/onboarding_completion_service.dart',
    ).readAsStringSync();
    final cameraFlows = [
      'lib/features/dashboard/dashboard_page.dart',
      'lib/features/daily_log/daily_log_capture_actions.dart',
      'lib/features/nutrition/presentation/food_page_actions.dart',
      'lib/features/profile/premium_profile_actions.dart',
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    // Integrations is an Android-only onboarding stage.  Keep the stage
    // guarded so iOS review never sees it, while Android retains its contract.
    expect(
      onboarding,
      contains("if (defaultTargetPlatform != TargetPlatform.iOS) 'integrations',"),
    );
    expect(
      onboarding,
      isNot(contains('Enter the name you would like BIL to use.')),
    );
    expect(completion, isNot(contains('preferred_name_required')));
    expect(cameraFlows, isNot(contains('Allow camera for this action?')));
  });

  test(
    'HealthKit reads remain indeterminate and are not denied by write status',
    () {
      final swift = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final integration = File(
        'lib/features/global_platform/health_data/unified_health_data_integration.dart',
      ).readAsStringSync();

      expect(swift, contains('"readStatus": "indeterminate"'));
      expect(swift, contains('let deviceName: Any'));
      expect(swift, contains('deviceName = NSNull()'));
      expect(swift, contains('"deviceId": deviceName'));
      expect(swift, isNot(contains('sample.device?.name as Any')));
      expect(integration, contains('appleHealthReadStateIsIndeterminate'));
      expect(
        integration,
        contains(
          'appleHealthReadStateIsIndeterminate\n          ? requestedTypes',
        ),
      );
    },
  );
}
