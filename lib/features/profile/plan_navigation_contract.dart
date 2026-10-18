enum PlanPageOrigin {
  profile('profile', '/profile-settings'),
  dashboard('dashboard', '/dashboard'),
  coach('coach', '/intelligence-center');

  const PlanPageOrigin(this.queryValue, this.returnLocation);

  final String queryValue;
  final String returnLocation;

  /// Only the two app-owned origins are accepted. Unknown/deep-link values
  /// resolve to Dashboard instead of becoming an arbitrary return route.
  static PlanPageOrigin fromQuery(String? value) => switch (value) {
    'profile' => PlanPageOrigin.profile,
    'dashboard' => PlanPageOrigin.dashboard,
    'coach' => PlanPageOrigin.coach,
    _ => PlanPageOrigin.dashboard,
  };
}
