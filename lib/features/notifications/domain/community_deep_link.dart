class CommunityDeepLink {
  const CommunityDeepLink._();

  static const _appAliases = <String, String>{
    'connected-health': '/connected-health',
    'connected-health/steps': '/connected-health/steps',
    'connected-health/capabilities': '/connected-health/capabilities',
    'goals': '/goals',
    'weekly-report': '/weekly-report',
    'weekly-digest': '/weekly-report',
    'profile-summary': '/profile-summary',
    'profile': '/profile-summary',
    'profile-settings': '/profile-settings',
    'daily-check-in': '/daily-check-in',
    'daily-log': '/daily-log',
    'daily-log/water': '/daily-log/water',
    'nutrition': '/nutrition',
    'history': '/history',
    'analytics': '/analytics',
    'analytics/nutrition': '/analytics/nutrition',
    'food-libraries': '/food-libraries',
    'foods': '/foods',
    'advertising-privacy': '/advertising-privacy',
    'notification-settings': '/notification-settings',
    'intelligence-center': '/intelligence-center',
    'wellness/learn': '/wellness/learn',
    'wellness/sleep': '/wellness/sleep',
    'wellness/workouts': '/wellness/workouts',
    'workouts': '/wellness/workouts',
    'wellness/workouts/routines': '/wellness/workouts/routines',
    'wellness/workouts/log': '/wellness/workouts/log',
    'wellness/fasting': '/wellness/fasting',
    'fasting': '/wellness/fasting',
    'wellness/recipes': '/wellness/recipes',
    'recipes': '/wellness/recipes',
    'meal-planner': '/meal-planner',
    'dashboard': '/dashboard',
    'more': '/settings',
    'dashboard/preferences': '/dashboard/preferences',
    'settings/preferences': '/settings/preferences',
    'settings/language': '/settings/language',
    'settings/appearance': '/settings/appearance',
    'settings/diary': '/settings/diary',
    'settings/diary/search-tab': '/settings/diary/search-tab',
    'settings/diary/sharing': '/settings/diary/sharing',
    'settings/diary/meal-names': '/settings/diary/meal-names',
    'settings/sharing-privacy': '/settings/sharing-privacy',
    'settings/local-export': '/settings/local-export',
    'settings/nutrition-goals': '/settings/nutrition-goals',
    'trust-support': '/trust-support',
    'help': '/help',
    'help/faq': '/help/faq',
    'help/delete-account': '/help/delete-account',
    'legal/privacy': '/legal/privacy',
    'legal/terms': '/legal/terms',
    'legal/health-disclaimer': '/legal/health-disclaimer',
  };

  static String? routeFor(Uri uri) {
    if (uri.scheme.toLowerCase() != 'bil') return null;

    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.isEmpty) return null;

    final alias = _appAliases[segments.join('/')];
    if (alias != null) {
      final safeQuery = _safeQueryFor(alias, uri.queryParameters);
      return Uri(
        path: alias,
        queryParameters: safeQuery.isEmpty ? null : safeQuery,
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
        final rawUserId = segments[2];
        if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(rawUserId)) {
          return null;
        }
        final userId = Uri.encodeComponent(rawUserId.toLowerCase());
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

  static Map<String, String> _safeQueryFor(
    String route,
    Map<String, String> input,
  ) {
    final output = <String, String>{};
    void accept(String key, bool Function(String value) valid) {
      final value = input[key]?.trim();
      if (value != null && value.length <= 128 && valid(value)) {
        output[key] = value;
      }
    }

    switch (route) {
      case '/daily-log':
        accept(
          'meal',
          const {'breakfast', 'lunch', 'dinner', 'snack'}.contains,
        );
        accept('focus', const {'meal'}.contains);
        accept(
          'action',
          const {
            'barcode',
            'voice',
            'photo',
            'water',
            'notes',
            'exercise',
            'quick-macros',
          }.contains,
        );
        accept('from', const {'/dashboard', '/daily-log'}.contains);
      case '/analytics/nutrition':
        accept('tab', const {'calories', 'nutrients', 'macros'}.contains);
      case '/intelligence-center':
        accept('vision', const {'capture'}.contains);
        accept('barcode', (value) => RegExp(r'^[0-9]{8,14}$').hasMatch(value));
      case '/wellness/workouts/log':
        accept(
          'category',
          const {'all', 'cardio', 'strength', 'recovery'}.contains,
        );
      case '/settings/local-export':
        accept('from', _canonicalDate);
        accept('to', _canonicalDate);
    }
    return output;
  }

  static bool _canonicalDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }
}
