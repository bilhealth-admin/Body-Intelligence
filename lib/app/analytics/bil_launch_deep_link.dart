/// Privacy-safe launch-link parsing. Only known routes and bounded campaign
/// fields survive; arbitrary redirect targets and health data are discarded.
final class BilLaunchDeepLink {
  const BilLaunchDeepLink({required this.route, required this.attribution});

  final String route;
  final Map<String, String> attribution;

  static const _routes = <String, String>{
    'plans': '/plans',
    'login': '/login',
    'register': '/register',
    'settings': '/settings',
    'notifications': '/notification-settings',
    'connected-health': '/connected-health',
    'privacy': '/legal/privacy',
  };
  static const _campaignKeys = <String>{
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
  };

  static BilLaunchDeepLink? parse(Uri uri) {
    final isCustom = uri.scheme.toLowerCase() == 'bil';
    final isWeb =
        uri.scheme.toLowerCase() == 'https' &&
        const {
          'bilhealth.com',
          'www.bilhealth.com',
        }.contains(uri.host.toLowerCase());
    if (!isCustom && !isWeb) return null;
    final segments = <String>[
      if (isCustom && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length != 1) return null;
    final route = _routes[segments.single.toLowerCase()];
    if (route == null) return null;

    final attribution = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      if (!_campaignKeys.contains(entry.key)) continue;
      final value = entry.value.trim();
      if (value.isEmpty || value.length > 80) continue;
      if (!RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value)) continue;
      attribution[entry.key] = value;
    }
    return BilLaunchDeepLink(
      route: route,
      attribution: Map.unmodifiable(attribution),
    );
  }
}
