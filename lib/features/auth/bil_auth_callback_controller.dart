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
  final Set<Uri> _failed = <Uri>{};
  final Map<Uri, Future<bool>> _inFlight = <Uri, Future<bool>>{};
  Uri? _lastStarted;
  Uri? _lastFailed;

  Future<bool> handle(Uri uri) async {
    if (!isSupportedCallbackLocation(uri)) return false;
    _lastStarted = uri;

    // Android may expose the cold-start URI through more than one delivery
    // path. A successful PKCE authorization code is single-use, while a failed
    // exchange must remain available for an explicit user retry.
    if (_handled.contains(uri) || _failed.contains(uri)) return true;
    final existing = _inFlight[uri];
    if (existing != null) {
      await existing;
      return true;
    }

    await _run(uri);
    return true;
  }

  /// Waits for the current callback, or retries the most recent failed one.
  ///
  /// Failed callbacks are not replayed automatically when the operating
  /// system delivers a duplicate link. Only an explicit user action reaches
  /// this method.
  Future<bool> retryLastFailed() async {
    // The callback page can time out while a slow exchange is still running.
    // Rejoin that exact operation so tapping Retry cannot cancel the only UI
    // listener and strand an eventually successful sign-in.
    final activeUri = _lastStarted;
    final active = activeUri == null ? null : _inFlight[activeUri];
    if (active != null) return active;

    final uri = _lastFailed;
    if (uri == null) return false;

    final existing = _inFlight[uri];
    if (existing != null) return existing;

    _failed.remove(uri);
    return _run(uri);
  }

  Future<bool> _run(Uri uri) {
    final operation = _exchange(uri);
    _inFlight[uri] = operation;
    return operation.whenComplete(() => _inFlight.remove(uri));
  }

  Future<bool> _exchange(Uri uri) async {
    final isPasswordRecovery = isPasswordRecoveryLocation(uri);
    navigate(isPasswordRecovery ? '/reset-password' : '/auth-callback');

    try {
      await resolve(uri);
      _handled.add(uri);
      _failed.remove(uri);
      if (_lastFailed == uri) _lastFailed = null;
      // `getSessionFromUrl` emits passwordRecovery before its Future returns.
      // The reset page can be mounted after that one-shot event, so explicitly
      // carry only the verified outcome (never the code/token) in our internal
      // route after the exchange completes.
      if (isPasswordRecovery) {
        navigate('/reset-password?verified=1');
      }
      return true;
    } catch (error, stackTrace) {
      _failed.add(uri);
      _lastFailed = uri;
      onError(error, stackTrace);
      navigate(
        isPasswordRecovery
            ? '/reset-password?failed=1'
            : '/auth-callback?failed=1',
      );
      return false;
    }
  }

  /// Returns true only for BIL's exact verified HTTPS callback origin.
  /// Credential-bearing custom-scheme callbacks are deliberately rejected
  /// because another installed app can register the same scheme.
  static bool isSupportedCallbackLocation(Uri uri) {
    if (!_hasSupportedCallbackOrigin(uri)) return false;

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

  static bool isPasswordRecoveryLocation(Uri uri) {
    final path = uri.pathSegments;
    if (uri.scheme.toLowerCase() == 'https') {
      return path.length == 2 &&
          path.first == 'auth' &&
          path.last == 'reset-password';
    }
    return false;
  }

  static bool _hasSupportedCallbackOrigin(Uri uri) {
    if (uri.userInfo.isNotEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (scheme == 'https' && host == 'www.bilhealth.com') {
      if (uri.hasPort && uri.port != 443) return false;
      final path = uri.pathSegments;
      return path.length == 2 &&
          path.first == 'auth' &&
          (path.last == 'callback' || path.last == 'reset-password');
    }
    return false;
  }
}
