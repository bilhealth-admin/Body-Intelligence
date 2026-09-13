import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The short-lived identity proof returned by Meta's native SDK.
///
/// It is exchanged with Supabase immediately and is never persisted in BIL.
final class BilFacebookIdentityToken {
  const BilFacebookIdentityToken(this.idToken);

  final String idToken;
}

/// Uses Meta's native login SDK on Android and iOS instead of opening a
/// Supabase OAuth URL.
///
/// Meta controls its own authorization UI, including its privacy-preserving
/// limited-login mode where applicable. Android explicitly requests the
/// platform's native-with-fallback behavior, never an embedded WebView.
/// Supabase documents this exact native token exchange for Facebook, so BIL
/// does not need a browser callback page or an HTTPS redirect to complete
/// sign-in on either mobile platform.
final class BilNativeFacebookSignIn {
  const BilNativeFacebookSignIn();

  /// Returns null only when the person dismisses Meta's authorization UI.
  /// Configuration, SDK, and token failures remain actionable auth errors.
  Future<BilFacebookIdentityToken?> authenticate() async {
    final result = await FacebookAuth.instance.login(
      permissions: const <String>['public_profile', 'email'],
      loginBehavior: LoginBehavior.nativeWithFallback,
      loginTracking: LoginTracking.limited,
    );
    if (result.status == LoginStatus.cancelled) return null;
    if (result.status != LoginStatus.success) {
      throw const AuthException('Facebook sign-in could not be completed.');
    }

    final idToken = result.accessToken?.tokenString.trim();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Facebook did not return an identity token.');
    }
    return BilFacebookIdentityToken(idToken);
  }
}
