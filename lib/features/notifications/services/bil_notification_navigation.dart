import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/community_deep_link.dart';
import '../domain/daily_reminder.dart';

typedef BilNotificationNavigate = void Function(String route);

/// Stable payloads written into Android notifications.
///
/// They are BIL deep links instead of raw GoRouter paths so every tap passes
/// through the same explicit allow-list as external app links.
class BilNotificationPayload {
  const BilNotificationPayload._();

  static const activation = 'bil://notification-settings';
  static const fasting = 'bil://wellness/fasting';
  static const sleep = 'bil://wellness/sleep';
  static const dashboard = 'bil://dashboard';

  static String forDaily(DailyReminderKind kind) => switch (kind) {
    DailyReminderKind.weight => 'bil://daily-check-in',
    DailyReminderKind.meals => 'bil://daily-log?focus=meal',
    DailyReminderKind.water => 'bil://daily-log/water',
    DailyReminderKind.sleep => sleep,
    DailyReminderKind.fasting => fasting,
    DailyReminderKind.weeklyReview => 'bil://weekly-report',
    DailyReminderKind.returnAfter24Hours => dashboard,
  };
}

/// Resolves notification taps to audited app routes and rejects everything
/// outside the BIL deep-link allow-list. Legacy payloads remain supported so
/// notifications scheduled by an older installed build do not become dead.
class BilNotificationNavigation {
  const BilNotificationNavigation._();

  static BilNotificationNavigate? _navigate;
  static final ListQueue<String> _pendingRoutes = ListQueue<String>();
  static const int _maxPendingRoutes = 32;
  static bool _drainingPendingRoutes = false;
  static bool _remoteTapBridgeInitialized = false;
  static MethodChannel? _remoteTapChannel;
  static const MethodChannel _defaultRemoteTapChannel = MethodChannel(
    'bil/push',
  );

  /// Local-notification taps are wired only on the two shipped mobile
  /// platforms. Keeping this decision beside the payload allow-list prevents
  /// iOS from silently falling back to a no-op callback while leaving desktop
  /// notification behavior unchanged.
  static bool supportsPlatform(TargetPlatform platform) =>
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;

  static const _legacyPayloads = <String, String>{
    'notification_activation_check': BilNotificationPayload.activation,
    'weight': 'bil://daily-check-in',
    'meals': 'bil://daily-log?focus=meal',
    'water': 'bil://daily-log/water',
    'sleep': BilNotificationPayload.sleep,
    'fasting': BilNotificationPayload.fasting,
    'weeklyReview': 'bil://weekly-report',
    'returnAfter24Hours': BilNotificationPayload.dashboard,
    'fasting_target': BilNotificationPayload.fasting,
    'fasting_active': BilNotificationPayload.fasting,
    'fasting_hydration': BilNotificationPayload.fasting,
    'sleep_windDown': BilNotificationPayload.sleep,
    'sleep_bedtime': BilNotificationPayload.sleep,
    'sleep_wake': BilNotificationPayload.sleep,
    'return_after_24_hours': BilNotificationPayload.dashboard,
  };

  static void configure({required BilNotificationNavigate navigate}) {
    _navigate = navigate;
    _drainPendingRoutes();
  }

  static void _drainPendingRoutes() {
    final navigate = _navigate;
    if (navigate == null || _drainingPendingRoutes) return;
    _drainingPendingRoutes = true;
    try {
      // Remove only after navigation returns. A reentrant tap is queued at the
      // tail, preserving A,B,C rather than allowing A,C,B. If navigation
      // throws, the current route stays at the head for a later safe retry.
      while (_pendingRoutes.isNotEmpty) {
        final route = _pendingRoutes.first;
        navigate(route);
        _pendingRoutes.removeFirst();
      }
    } finally {
      _drainingPendingRoutes = false;
    }
  }

  static void _enqueuePendingRoute(String route) {
    if (_pendingRoutes.contains(route) ||
        _pendingRoutes.length >= _maxPendingRoutes) {
      return;
    }
    _pendingRoutes.addLast(route);
  }

  /// Installs the native remote-notification tap bridge and consumes a
  /// cold-start payload exactly once. Native and Dart both validate the
  /// payload, while [routeForPayload] remains the final route allow-list.
  static Future<void> initializeNativeRemoteTapBridge({
    TargetPlatform? platform,
    MethodChannel? channel,
  }) async {
    final targetPlatform = platform ?? defaultTargetPlatform;
    if (!supportsPlatform(targetPlatform) || _remoteTapBridgeInitialized) {
      return;
    }
    final effectiveChannel = channel ?? _defaultRemoteTapChannel;
    _remoteTapBridgeInitialized = true;
    _remoteTapChannel = effectiveChannel;
    effectiveChannel.setMethodCallHandler((call) async {
      if (call.method != 'notificationTap') return null;
      final arguments = call.arguments;
      handlePayload(arguments is String ? arguments : null);
      // Native keeps its pending copy until Dart explicitly acknowledges that
      // the bridge is installed. This closes the iOS cold-start race where the
      // Flutter channel can exist before this handler is ready.
      return true;
    });
    try {
      final initialPayload = await effectiveChannel.invokeMethod<Object?>(
        'takeInitialPayload',
      );
      for (final payload in _payloadsFromNative(initialPayload)) {
        handlePayload(payload);
      }
    } on MissingPluginException {
      // Older installed native shells have no remote-tap bridge. Local
      // notification routing remains available and no unsafe fallback runs.
    } on PlatformException {
      // Treat an unreadable native payload as absent. A future onNewIntent
      // callback can still deliver a valid allow-listed route.
    }
  }

  static String? routeForPayload(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty || value.length > 512) return null;
    final deepLink = _legacyPayloads[value] ?? value;
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return null;
    return CommunityDeepLink.routeFor(uri);
  }

  static void handlePayload(String? payload) {
    final route = routeForPayload(payload);
    if (route == null) return;
    final navigate = _navigate;
    if (navigate == null ||
        _drainingPendingRoutes ||
        _pendingRoutes.isNotEmpty) {
      // Preserve arrival order before the router is ready. Duplicates do not
      // represent distinct destinations and are coalesced while pending; the
      // bounded queue rejects overflow rather than evicting an earlier tap.
      _enqueuePendingRoute(route);
      _drainPendingRoutes();
      return;
    }
    navigate(route);
  }

  static Iterable<String> _payloadsFromNative(Object? value) sync* {
    if (value is String) {
      yield value;
      return;
    }
    if (value is List) {
      for (final item in value) {
        if (item is String) yield item;
      }
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _remoteTapChannel?.setMethodCallHandler(null);
    _remoteTapChannel = null;
    _remoteTapBridgeInitialized = false;
    _navigate = null;
    _pendingRoutes.clear();
    _drainingPendingRoutes = false;
  }
}
