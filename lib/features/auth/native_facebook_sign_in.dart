import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The short-lived OIDC identity proof returned by Meta's native SDK.
///
/// It is exchanged with Supabase immediately and is never persisted in BIL.
final class BilFacebookIdentityToken {
  const BilFacebookIdentityToken({required this.idToken, required this.nonce});

  final String idToken;
  final String nonce;
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

/// Uses Meta's native Android/iOS SDK and accepts only a real OIDC JWT.
///
/// On Android, [ClassicToken.tokenString] is a Graph API access token and is
/// never an identity token. flutter_facebook_auth 7.2.0 exposes Meta's OIDC
/// AuthenticationToken separately as [ClassicToken.authenticationToken]. On
/// iOS Limited Login, [LimitedToken.tokenString] is the identity JWT.
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
    final result = await client.login(
      permissions: const <String>['public_profile', 'email', 'openid'],
      loginBehavior: LoginBehavior.nativeWithFallback,
      loginTracking: LoginTracking.limited,
      nonce: nonce,
    );
    if (result.status == LoginStatus.cancelled) return null;
    if (result.status != LoginStatus.success) {
      throw const AuthException('Facebook sign-in could not be completed.');
    }

    final accessToken = result.accessToken;
    final identityToken = switch (accessToken) {
      ClassicToken(:final authenticationToken) => authenticationToken?.trim(),
      LimitedToken(:final tokenString) => tokenString.trim(),
      _ => null,
    };
    if (identityToken == null || !isStructurallyValidJwt(identityToken)) {
      throw const AuthException(
        'Facebook did not return a valid identity token.',
      );
    }
    return BilFacebookIdentityToken(idToken: identityToken, nonce: nonce);
  }
}
