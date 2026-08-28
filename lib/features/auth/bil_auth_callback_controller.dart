/// Resolves BIL's native Supabase callback while the app remains the sole
/// owner of the platform app-link stream.
///
/// `supabase_flutter` normally performs this exchange with its own app-link
/// observer. BIL deliberately disables that observer during startup, so the
/// same `getSessionFromUrl` operation is injected here instead. Callback URLs
/// and their one-time codes are never logged.
final class BilAuthCallbackController {
  BilAuthCallbackController({
    required this.resolve,
    required this.navigate,
    required this.onError,
  });

  final Future<void> Function(Uri uri) resolve;
  final void Function(String route) navigate;
  final void Function(Object error, StackTrace stackTrace) onError;

  final Set<Uri> _handled = <Uri>{};

  Future<bool> handle(Uri uri) async {
    if (!_isNativeAuthCallback(uri)) return false;

    // Android may expose the cold-start URI through both getInitialLink and
    // uriLinkStream. PKCE authorization codes are single-use, so exchange an
    // identical callback at most once during this process lifetime.
    if (!_handled.add(uri)) return true;

    final isPasswordRecovery =
        uri.pathSegments.length == 1 &&
        uri.pathSegments.single == 'reset-password';
    navigate(isPasswordRecovery ? '/reset-password' : '/auth-callback');

    try {
      await resolve(uri);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      if (!isPasswordRecovery) {
        navigate('/auth-callback?failed=1');
      }
    }
    return true;
  }

  static bool _isNativeAuthCallback(Uri uri) {
    if (uri.scheme.toLowerCase() != 'bil' ||
        uri.host.toLowerCase() != 'auth-callback') {
      return false;
    }

    Map<String, String> fragmentParameters;
    try {
      fragmentParameters = Uri.splitQueryString(uri.fragment);
    } on FormatException {
      fragmentParameters = const <String, String>{};
    }
    bool hasParameter(String key) =>
        uri.queryParameters.containsKey(key) ||
        fragmentParameters.containsKey(key);

    return hasParameter('code') ||
        hasParameter('access_token') ||
        hasParameter('error') ||
        hasParameter('error_code') ||
        hasParameter('error_description');
  }
}
