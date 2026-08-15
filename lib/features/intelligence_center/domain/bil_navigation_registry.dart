/// Model-facing navigation uses stable target identifiers, never raw paths.
class BilNavigationRegistry {
  const BilNavigationRegistry();

  static const targets = <String, String>{
    'dashboard': '/dashboard',
    'daily_log': '/daily-log',
    'nutrition': '/nutrition',
    'weight_history': '/weight-history',
    'measurements': '/advanced-body-measurements',
    'goals': '/goals',
    'analytics': '/analytics',
    'profile': '/profile-summary',
    'settings': '/settings',
    'notifications': '/notification-settings',
    'ai_coach': '/intelligence-center',
  };

  String? resolve(String target) => targets[target];
}
