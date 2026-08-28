import 'package:flutter/foundation.dart';

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
  static String? _pendingRoute;

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
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) navigate(pending);
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
    if (navigate == null) {
      _pendingRoute = route;
      return;
    }
    navigate(route);
  }

  @visibleForTesting
  static void resetForTesting() {
    _navigate = null;
    _pendingRoute = null;
  }
}
