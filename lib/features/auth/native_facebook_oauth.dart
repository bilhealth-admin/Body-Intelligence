import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns the callback resolver for the currently mounted app-link bootstrap.
/// Native results from a replaced/disposed bootstrap cannot start an exchange.
final class BilFacebookOAuthCallbackOwner {
  BilFacebookOAuthCallbackOwner._(this.resolve);

  final Future<bool> Function(Uri) resolve;
  bool _mounted = true;

  void dispose() {
    if (!_mounted) return;
    _mounted = false;
    if (identical(BilNativeFacebookOAuth._owner, this)) {
      BilNativeFacebookOAuth._owner = null;
      BilNativeFacebookOAuth._cancelActive();
    }
  }
}

/// iOS Facebook uses an authentication session, never a general web browser.
/// Callback URLs and the PKCE verifier stay in memory/the existing Auth store.
final class BilNativeFacebookOAuth {
  const BilNativeFacebookOAuth({
    this.sessionTimeout = const Duration(minutes: 5),
    this.diagnosticRecorder,
  });

  final Duration sessionTimeout;
  final void Function(String stage, String reason)? diagnosticRecorder;

  void _record(String stage, String reason) {
    // Only fixed stage/reason enums reach this private diagnostic boundary.
    // A diagnostic sink must never change authentication behavior.
    try {
      if (diagnosticRecorder case final recorder?) {
        recorder(stage, reason);
      } else {
        debugPrint('BIL_FACEBOOK_OAUTH stage=$stage reason=$reason');
      }
    } catch (_) {}
  }

  /// Returns a fixed category, never an exception message or URL/token value.
  static String safeCallbackErrorReason(Object error) {
    if (error is AuthException &&
        error.message == 'Code verifier could not be found in local storage.') {
      return 'pkce_verifier_missing';
    }
    if (error is AuthPKCEGrantCodeExchangeError) return 'pkce_code_rejected';
    if (error is AuthException &&
        const {
          'access_denied',
          'server_error',
          'temporarily_unavailable',
        }.contains(error.code)) {
      return 'provider_error';
    }
    return error is AuthException ? 'auth_exception' : 'unexpected_error';
  }

  static const _channel = MethodChannel('bil/facebook_oauth');
  static const httpsCallback = 'https://www.bilhealth.com/auth/callback';
  static const legacyCallback = 'bil://auth-callback';
  static BilFacebookOAuthCallbackOwner? _owner;
  static String? _activeAttempt;

  static BilFacebookOAuthCallbackOwner attachCallbackOwner(
    Future<bool> Function(Uri) resolve,
  ) {
    _owner?.dispose();
    return _owner = BilFacebookOAuthCallbackOwner._(resolve);
  }

  static void _cancelActive() {
    final attempt = _activeAttempt;
    if (attempt == null) return;
    _cancelAttempt(attempt);
  }

  static void _cancelAttempt(String attempt) {
    if (_activeAttempt != attempt) return;
    unawaited(
      _channel
          .invokeMethod<void>('cancel', {'attemptId': attempt})
          .catchError((Object _) {}),
    );
  }

  Future<bool> authenticate(SupabaseClient client) async {
    final owner = _owner;
    if (owner == null || !owner._mounted || _activeAttempt != null) {
      _record('owner', 'unavailable_or_busy');
      throw const AuthException(
        'Facebook sign-in is already active or unavailable.',
      );
    }
    final attempt = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    ).replaceAll('=', '');
    _activeAttempt = attempt;
    final startingAuthOwner = client.auth.currentUser?.id;
    var pendingNativeResult = true;
    var authOwnerRetired = false;
    var firstAuthEvent = true;
    void retireChangedAuthOwner() {
      if (!pendingNativeResult || authOwnerRetired) return;
      // Retirement is irreversible, including A -> B -> A and logout/relogin.
      authOwnerRetired = true;
      _record('owner', 'retired');
      _cancelAttempt(attempt);
    }

    final authChanges = client.auth.onAuthStateChange.listen(
      (state) {
        // Auth replays its last event to new listeners. A sign-out that already
        // preceded this attempt is its starting state, not a new invalidation.
        final replayOfStartingState =
            firstAuthEvent && state.session?.user.id == startingAuthOwner;
        firstAuthEvent = false;
        if (state.event == AuthChangeEvent.signedOut &&
                !replayOfStartingState ||
            state.session?.user.id != startingAuthOwner) {
          retireChangedAuthOwner();
        }
      },
      onError: (Object _, StackTrace _) {
        if (client.auth.currentUser?.id != startingAuthOwner) {
          retireChangedAuthOwner();
        }
      },
    );
    bool ownsAttempt() {
      // Check synchronous state as well as the stream epoch; a queued auth event
      // must not leave a gap before verifier creation or trusted resolution.
      if (pendingNativeResult &&
          client.auth.currentUser?.id != startingAuthOwner) {
        retireChangedAuthOwner();
      }
      return identical(_owner, owner) &&
          owner._mounted &&
          _activeAttempt == attempt &&
          !authOwnerRetired;
    }

    try {
      final mode = await _channel
          .invokeMethod<String>('callbackMode')
          .timeout(sessionTimeout);
      if (!ownsAttempt() || (mode != 'https' && mode != 'legacy')) {
        throw const AuthException('Facebook sign-in could not be started.');
      }
      final redirect = mode == 'https' ? httpsCallback : legacyCallback;
      // Lock is acquired before creating the verifier, so another BIL Facebook
      // attempt cannot overwrite it while the native session/exchange is active.
      if (!ownsAttempt()) {
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      final authorization = await client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.facebook,
        redirectTo: redirect,
      );
      if (!ownsAttempt()) {
        _record('owner', 'retired');
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      _record('authorize', 'pkce_url_ready');
      final result = await _channel
          .invokeMapMethod<String, dynamic>('authenticate', {
            'attemptId': attempt,
            'url': authorization.url,
          })
          .timeout(sessionTimeout);
      _record('native', 'returned');
      if (!ownsAttempt()) {
        _record('owner', 'retired');
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      if (result == null) {
        _record('native', 'cancelled');
        return false;
      }
      if (result['attemptId'] != attempt || result['callbackUrl'] is! String) {
        _record('native', 'result_binding_rejected');
        throw const AuthException('Facebook returned an invalid callback.');
      }
      final inspected = _inspectOwnedCallback(
        result['callbackUrl'] as String,
        redirect,
      );
      _record('callback', inspected.reason);
      final callback = inspected.callback;
      if (callback == null) {
        throw AuthException(
          'Facebook returned an invalid callback.',
          code: inspected.reason,
        );
      }
      // Only this active native completion may normalize the legacy result.
      // Generic bil:// app links remain rejected by BilAuthCallbackController.
      final verifiedLocation = callback.replace(
        scheme: 'https',
        host: 'www.bilhealth.com',
        path: '/auth/callback',
      );
      if (!ownsAttempt()) {
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      // From this synchronous boundary the trusted shared resolver owns the
      // exchange. Its own signedIn event is an expected new authenticated owner.
      pendingNativeResult = false;
      _record('resolver', 'entered');
      final completed = await owner.resolve(verifiedLocation);
      _record('resolver', completed ? 'succeeded' : 'failed');
      if (!ownsAttempt()) {
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      return completed;
    } on PlatformException catch (error) {
      // Do not copy untrusted native error.message/details into diagnostics.
      final reason =
          const {
            'facebook_oauth_cancelled',
            'facebook_oauth_failed',
            'facebook_oauth_start_failed',
            'facebook_oauth_timeout',
            'facebook_oauth_unavailable',
          }.contains(error.code)
          ? error.code
          : 'native_platform_error';
      _record('native', reason);
      if (error.code == 'facebook_oauth_cancelled') return false;
      throw const AuthException('Facebook sign-in could not be completed.');
    } on TimeoutException {
      _record('native', 'timeout');
      _cancelAttempt(attempt);
      throw const AuthException(
        'Facebook sign-in timed out. Please try again.',
      );
    } finally {
      pendingNativeResult = false;
      await authChanges.cancel();
      if (_activeAttempt == attempt) _activeAttempt = null;
    }
  }

  // This is called only after this native result passes the active owner,
  // attempt ID and mode fences. Generic app links never enter this boundary.
  static ({Uri? callback, String reason}) _inspectOwnedCallback(
    String raw,
    String expected,
  ) {
    final delimiter = raw.indexOf('#');
    final fragment = delimiter < 0 ? null : raw.substring(delimiter + 1);
    if (fragment != null && fragment.isNotEmpty && fragment != '_=_') {
      return (
        callback: null,
        reason:
            fragment.startsWith('error=') ||
                fragment.startsWith('error_code=') ||
                fragment.startsWith('error_description=')
            ? 'provider_error_fragment_rejected'
            : 'fragment_rejected',
      );
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return (callback: null, reason: 'shape_rejected');
    final clean = parsed.removeFragment();
    if (!_matchesCallback(clean, expected)) {
      return (callback: null, reason: 'shape_rejected');
    }
    return (
      callback: clean,
      reason: fragment == '_=_'
          ? 'facebook_marker_removed'
          : fragment == ''
          ? 'empty_fragment_removed'
          : 'accepted',
    );
  }

  static bool _matchesCallback(Uri callback, String expected) {
    final location = Uri.parse(expected);
    if (callback.userInfo.isNotEmpty ||
        callback.hasPort ||
        callback.scheme != location.scheme ||
        callback.host != location.host ||
        callback.path != location.path) {
      return false;
    }
    // This transport is PKCE-only: session tokens must never arrive as a URL.
    if (callback.fragment.isNotEmpty) return false;
    final parameters = callback.queryParametersAll;
    if (parameters.values.any((values) => values.length != 1) ||
        parameters.keys.any(
          (key) =>
              const {'access_token', 'refresh_token', 'id_token'}.contains(key),
        )) {
      return false;
    }
    return (callback.queryParameters['code']?.isNotEmpty ?? false) ||
        parameters.containsKey('error') ||
        parameters.containsKey('error_code') ||
        parameters.containsKey('error_description');
  }
}
