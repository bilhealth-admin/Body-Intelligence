import 'dart:io';

import 'package:body_intelligence_log/features/notifications/services/bil_notification_navigation.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timezoneChannel = MethodChannel('flutter_timezone');
  const navigationTestChannel = MethodChannel('bil/ios-push-navigation-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakeIosNotificationsPlugin fakeIos;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    BilNotificationNavigation.resetForTesting();
    BilNotificationService.resetLaunchDetailsHandlingForTesting();
    fakeIos = _FakeIosNotificationsPlugin();
    FlutterLocalNotificationsPlatform.instance = fakeIos;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (_) async => 'UTC');
  });

  tearDown(() {
    BilNotificationNavigation.resetForTesting();
    BilNotificationService.resetLaunchDetailsHandlingForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
    messenger.setMockMethodCallHandler(navigationTestChannel, null);
  });

  test('mobile notification navigation includes iOS and Android only', () {
    expect(
      BilNotificationNavigation.supportsPlatform(TargetPlatform.iOS),
      isTrue,
    );
    expect(
      BilNotificationNavigation.supportsPlatform(TargetPlatform.android),
      isTrue,
    );
    expect(
      BilNotificationNavigation.supportsPlatform(TargetPlatform.macOS),
      isFalse,
    );
    expect(
      BilNotificationNavigation.supportsPlatform(TargetPlatform.windows),
      isFalse,
    );
  });

  test(
    'iOS cold launch and running-app taps use the audited route allow-list',
    () async {
      final routes = <String>[];
      BilNotificationNavigation.configure(navigate: routes.add);
      fakeIos.launchDetails = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'bil://daily-log?focus=meal',
        ),
      );

      await BilNotificationService(
        FlutterLocalNotificationsPlugin(),
      ).initialize();

      expect(fakeIos.initializeCalls, 1);
      expect(fakeIos.launchDetailCalls, 1);
      expect(fakeIos.onResponse, isNotNull);
      expect(routes, const <String>['/daily-log?focus=meal']);

      fakeIos.respond(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'bil://wellness/sleep',
        ),
      );
      expect(routes, const <String>[
        '/daily-log?focus=meal',
        '/wellness/sleep',
      ]);

      fakeIos.respond(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'https://example.invalid/escape',
        ),
      );
      fakeIos.respond(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.notificationDismissed,
          payload: 'bil://dashboard',
        ),
      );
      expect(routes, const <String>[
        '/daily-log?focus=meal',
        '/wellness/sleep',
      ]);
    },
  );

  test(
    'iOS cold-launch route waits until GoRouter navigation is configured',
    () async {
      fakeIos.launchDetails = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'bil://weekly-report',
        ),
      );

      await BilNotificationService(
        FlutterLocalNotificationsPlugin(),
      ).initialize();

      final routes = <String>[];
      expect(routes, isEmpty);
      BilNotificationNavigation.configure(navigate: routes.add);
      expect(routes, const <String>['/weekly-report']);
    },
  );

  test('iOS remote APNs bridge handles cold and warm audited taps', () async {
    final nativeCalls = <String>[];
    messenger.setMockMethodCallHandler(navigationTestChannel, (call) async {
      nativeCalls.add(call.method);
      if (call.method == 'takeInitialPayload') {
        return <String>['bil://weekly-report', 'bil://daily-log/water'];
      }
      return null;
    });
    final routes = <String>[];
    BilNotificationNavigation.configure(navigate: routes.add);

    await BilNotificationNavigation.initializeNativeRemoteTapBridge(
      platform: TargetPlatform.iOS,
      channel: navigationTestChannel,
    );

    expect(nativeCalls, ['takeInitialPayload']);
    expect(routes, ['/weekly-report', '/daily-log/water']);

    Object? acknowledged;
    await messenger.handlePlatformMessage(
      navigationTestChannel.name,
      navigationTestChannel.codec.encodeMethodCall(
        const MethodCall('notificationTap', 'bil://wellness/sleep'),
      ),
      (data) {
        acknowledged = navigationTestChannel.codec.decodeEnvelope(data!);
      },
    );
    await messenger.handlePlatformMessage(
      navigationTestChannel.name,
      navigationTestChannel.codec.encodeMethodCall(
        const MethodCall('notificationTap', 'https://example.invalid/escape'),
      ),
      null,
    );
    expect(routes, ['/weekly-report', '/daily-log/water', '/wellness/sleep']);
    expect(acknowledged, isTrue);
  });

  test('iOS native APNs bridge retains taps until Dart is ready', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      appDelegate,
      contains('UNUserNotificationCenter.current().delegate = self'),
    );
    expect(
      appDelegate,
      contains('notification.request.trigger is UNPushNotificationTrigger'),
    );
    expect(
      appDelegate,
      contains(
        'response.notification.request.trigger is UNPushNotificationTrigger',
      ),
    );
    expect(appDelegate, contains('case "takeInitialPayload"'));
    expect(appDelegate, contains('channel.invokeMethod("notificationTap"'));
    expect(appDelegate, contains('pendingRemotePushDeepLinks: [String] = []'));
    expect(appDelegate, contains('pendingRemotePushDeepLinks.first'));
    expect(appDelegate, contains('launchOptions?[.remoteNotification]'));
    expect(appDelegate, contains('pendingRemotePushDeepLinks.count < 32'));
    expect(appDelegate, contains('result as? Bool == true'));
    expect(appDelegate, contains('url.scheme?.lowercased() == "bil"'));
    expect(info, isNot(contains('<string>remote-notification</string>')));
  });
}

class _FakeIosNotificationsPlugin extends IOSFlutterLocalNotificationsPlugin {
  DidReceiveNotificationResponseCallback? onResponse;
  NotificationAppLaunchDetails? launchDetails;
  int initializeCalls = 0;
  int launchDetailCalls = 0;

  @override
  Future<bool?> initialize({
    required DarwinInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls += 1;
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    launchDetailCalls += 1;
    return launchDetails;
  }

  void respond(NotificationResponse response) => onResponse?.call(response);
}
