part of 'app_router.dart';

// Resolve trusted callback and deep-link destinations before route construction.
// Entitlement gates remain with their existing route owners.
String? _redirectAppRoute(Uri uri) {
  if (BilAuthCallbackController.isSupportedCallbackLocation(uri)) {
    if (!AppEnvironment.cloudConfigured) return '/login';
    final isPasswordRecovery =
        BilAuthCallbackController.isPasswordRecoveryLocation(uri);
    return isPasswordRecovery ? '/reset-password' : '/auth-callback';
  }
  final launchLink = BilLaunchDeepLink.parse(uri);
  if (launchLink != null) return launchLink.route;
  final deepLinkRoute = CommunityDeepLink.routeFor(uri);
  if (deepLinkRoute == null) return null;
  if (deepLinkRoute.startsWith('/community') &&
      !AppEnvironment.communityConfigured) {
    return '/settings';
  }
  return deepLinkRoute;
}
