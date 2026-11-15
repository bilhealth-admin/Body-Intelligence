import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  });

  final Duration sessionTimeout;

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
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      final result = await _channel
          .invokeMapMethod<String, dynamic>('authenticate', {
            'attemptId': attempt,
            'url': authorization.url,
          })
          .timeout(sessionTimeout);
      if (!ownsAttempt()) {
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      if (result == null) return false; // User dismissed the system sheet.
      if (result['attemptId'] != attempt || result['callbackUrl'] is! String) {
        throw const AuthException('Facebook returned an invalid callback.');
      }
      final Uri? callback;
      try {
        callback = Uri.tryParse(result['callbackUrl'] as String);
        if (callback == null || !_matchesCallback(callback, redirect)) {
          throw const FormatException();
        }
      } on FormatException {
        throw const AuthException('Facebook returned an invalid callback.');
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
      final completed = await owner.resolve(verifiedLocation);
      if (!ownsAttempt()) {
        throw const AuthException('Facebook sign-in was interrupted.');
      }
      return completed;
    } on PlatformException catch (error) {
      if (error.code == 'facebook_oauth_cancelled') return false;
      throw const AuthException('Facebook sign-in could not be completed.');
    } on TimeoutException {
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
