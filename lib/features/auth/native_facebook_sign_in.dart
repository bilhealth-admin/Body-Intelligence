import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The short-lived OIDC identity proof returned by Meta's native SDK.
///
/// It is exchanged with Supabase immediately and is never persisted in BIL.
final class BilFacebookIdentityToken {
  const BilFacebookIdentityToken({
    required this.idToken,
    this.accessToken,
    this.nonce,
  });

  final String idToken;
  final String? accessToken;
  final String? nonce;
}

abstract interface class BilFacebookLoginClient {
  Future<LoginResult> login({
    required List<String> permissions,
    required LoginBehavior loginBehavior,
    required LoginTracking loginTracking,
    required String nonce,
  });
}

final class MetaFacebookLoginClient implements BilFacebookLoginClient {
  const MetaFacebookLoginClient();

  @override
  Future<LoginResult> login({
    required List<String> permissions,
    required LoginBehavior loginBehavior,
    required LoginTracking loginTracking,
    required String nonce,
  }) => FacebookAuth.instance.login(
    permissions: permissions,
    loginBehavior: loginBehavior,
    loginTracking: loginTracking,
    nonce: nonce,
  );
}

/// Uses Meta's native Android/iOS SDK and returns the proof expected by
/// Supabase for the token type produced on each platform.
///
/// flutter_facebook_auth 7.2.0 exposes Meta's Android OIDC proof as
/// [ClassicToken.authenticationToken]. The classic [ClassicToken.tokenString]
/// is the matching Graph access token: it is sent only as the exchange's
/// `accessToken`, never as its `idToken`. On iOS Limited Login,
/// [LimitedToken.tokenString] is the nonce-bound OIDC JWT.
final class BilNativeFacebookSignIn {
  const BilNativeFacebookSignIn({
    this.client = const MetaFacebookLoginClient(),
  });

  final BilFacebookLoginClient client;

  static bool isStructurallyValidJwt(String value) {
    final segments = value.split('.');
    if (segments.length != 3) return false;
    final base64UrlSegment = RegExp(r'^[A-Za-z0-9_-]+$');
    return segments.every(
      (segment) => segment.isNotEmpty && base64UrlSegment.hasMatch(segment),
    );
  }

  /// Returns null only when the person dismisses Meta's authorization UI.
  /// Configuration, SDK, and token failures remain actionable auth errors.
  Future<BilFacebookIdentityToken?> authenticate({
    required String nonce,
  }) async {
    // Supabase's supported Android OIDC flow requires Facebook's web-only
    // behavior. nativeWithFallback can return an authentication token whose
    // email claims are not accepted by the hosted Auth exchange.
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final result = await client.login(
      permissions: const <String>['public_profile', 'email', 'openid'],
      loginBehavior: isAndroid
          ? LoginBehavior.webOnly
          : LoginBehavior.nativeWithFallback,
      loginTracking: isAndroid ? LoginTracking.enabled : LoginTracking.limited,
      nonce: nonce,
    );
    if (result.status == LoginStatus.cancelled) return null;
    if (result.status != LoginStatus.success) {
      throw const AuthException('Facebook sign-in could not be completed.');
    }

    final accessToken = result.accessToken;
    switch (accessToken) {
      case ClassicToken(:final authenticationToken, :final tokenString):
        final token = authenticationToken?.trim();
        if (token == null || !isStructurallyValidJwt(token)) {
          throw const AuthException(
            'Facebook did not return a valid identity token.',
          );
        }
        final graphAccessToken = tokenString.trim();
        if (graphAccessToken.isEmpty) {
          throw const AuthException(
            'Facebook did not return a valid access token.',
          );
        }
        return BilFacebookIdentityToken(
          idToken: token,
          accessToken: graphAccessToken,
          nonce: nonce,
        );
      case LimitedToken(:final tokenString):
        final token = tokenString.trim();
        if (!isStructurallyValidJwt(token)) {
          throw const AuthException(
            'Facebook did not return a valid identity token.',
          );
        }
        return BilFacebookIdentityToken(idToken: token, nonce: nonce);
      default:
        throw const AuthException('Facebook did not return a sign-in token.');
    }
  }
}
