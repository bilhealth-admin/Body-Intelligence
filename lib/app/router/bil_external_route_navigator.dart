import 'package:go_router/go_router.dart';

/// Opens an allow-listed notification or app link without discarding Back.
/// The caller must resolve the original URI through BIL's audited parsers.
final class BilExternalRouteNavigator {
  const BilExternalRouteNavigator(this.router);

  final GoRouter router;

  void open(String location) {
    final target = Uri.tryParse(location);
    if (target == null ||
        target.scheme.isNotEmpty ||
        target.host.isNotEmpty ||
        target.fragment.isNotEmpty ||
        !target.path.startsWith('/') ||
        target.path.startsWith('//') ||
        target.pathSegments.contains('..')) {
      return;
    }

    final current = router.routeInformationProvider.value.uri;
    if (current.toString() == target.toString()) return;

    // Authentication callbacks and their security-bound state transitions are
    // not regular content screens and must never inherit a signed-in stack.
    if (const {
      '/login',
      '/register',
      '/reviewer-login',
      '/auth-callback',
      '/reset-password',
    }.contains(target.path)) {
      router.go(location);
      return;
    }

    if (current.path == '/startup') {
      // A killed app has no screen to pop. Seed the *semantic* parent so
      // private-message alerts return to Inbox, friend requests to Community,
      // and ordinary alerts to Home. Push is used only for the target itself.
      final parent = switch (target.path) {
        String path when path.startsWith('/community/chat/') =>
          '/community/messages',
        '/community/invite' => '/dashboard',
        String path when path.startsWith('/community/invite/') =>
          '/dashboard',
        String path when path.startsWith('/community/') => '/community',
        '/community' => '/community',
        _ => '/dashboard',
      };
      router.go(parent);
      if (target.path == parent) return;
    } else if (target.path == '/dashboard') {
      router.go(location);
      return;
    }

    // Warm taps leave the actual preceding page in place, including its
    // unsaved draft and scroll position. Authorization gates still apply.
    router.push(location);
  }
}
