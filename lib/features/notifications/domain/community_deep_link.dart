class CommunityDeepLink {
  const CommunityDeepLink._();

  static const _appAliases = <String, String>{
    'connected-health': '/connected-health',
    'connected-health/steps': '/connected-health/steps',
    'connected-health/capabilities': '/connected-health/capabilities',
    'goals': '/goals',
    'weekly-report': '/weekly-report',
    'profile-summary': '/profile-summary',
    'profile-settings': '/profile-settings',
    'daily-log': '/daily-log',
    'nutrition': '/nutrition',
    'history': '/history',
    'analytics': '/analytics',
    'analytics/nutrition': '/analytics/nutrition',
    'wellness/workouts': '/wellness/workouts',
    'wellness/workouts/routines': '/wellness/workouts/routines',
    'wellness/workouts/log': '/wellness/workouts/log',
    'wellness/fasting': '/wellness/fasting',
    'wellness/recipes': '/wellness/recipes',
    'meal-planner': '/meal-planner',
    'dashboard': '/dashboard',
    'dashboard/preferences': '/dashboard/preferences',
    'settings/preferences': '/settings/preferences',
    'settings/language': '/settings/language',
    'trust-support': '/trust-support',
    'help': '/help',
    'help/faq': '/help/faq',
    'help/delete-account': '/help/delete-account',
    'legal/privacy': '/legal/privacy',
    'legal/terms': '/legal/terms',
    'legal/health-disclaimer': '/legal/health-disclaimer',
  };

  static String? routeFor(Uri uri) {
    if (uri.scheme != 'bil') return null;

    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];
    if (segments.isEmpty) return null;

    final alias = _appAliases[segments.join('/')];
    if (alias != null) {
      return Uri(
        path: alias,
        queryParameters: uri.queryParameters.isEmpty
            ? null
            : uri.queryParameters,
      ).toString();
    }

    if (segments.first == 'community') {
      if (segments.length == 1) return '/community';
      if (segments.length == 2 && segments[1] == 'connections') {
        return '/community/connections';
      }
      if (segments.length == 2 && segments[1] == 'people') {
        return '/community/people';
      }
      if (segments.length == 2 && segments[1] == 'messages') {
        return '/community/messages';
      }
      if (segments.length == 3 &&
          segments[1] == 'messages' &&
          segments[2] == 'new') {
        return '/community/messages/new';
      }
      if (segments.length == 2 && segments[1] == 'safety') {
        return '/community/safety';
      }
      if (segments[1] == 'chat' && segments.length == 3) {
        final userId = Uri.encodeComponent(segments[2]);
        return '/community/chat/$userId';
      }
      return null;
    }

    if (segments.first == 'settings') {
      if (segments.length == 1) return '/settings';
      if (segments.length == 2 && segments[1] == 'notifications') {
        return '/notification-settings';
      }
      return null;
    }
    return null;
  }
}
