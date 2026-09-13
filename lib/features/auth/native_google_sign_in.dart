import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The short-lived identity proof returned by Google's native sign-in SDK.
///
/// It is deliberately passed straight to Supabase and never persisted locally.
final class BilGoogleIdentityTokens {
  const BilGoogleIdentityTokens({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;
}

/// Uses Google's native sign-in surface on Android and iOS instead of opening
/// the Supabase OAuth URL.
///
/// On Android, `google_sign_in_android` 7.2 uses Android Credential Manager,
/// which supplies Google's system-owned account sheet. On iOS, Google owns the
/// sign-in sheet. In both cases the returned proof is exchanged directly with
/// Supabase, so there is no browser callback page or Supabase-domain screen.
final class BilNativeGoogleSignIn {
  const BilNativeGoogleSignIn();

  // This is the public web OAuth client registered as the token audience.
  // Android Credential Manager requires it when the project does not ship a
  // google-services.json file. It is deliberately not an OAuth secret.
  static const _serverClientId =
      '1041595138122-hpe2ke9c5rpphijvmk2ssvsbggvbp14j.apps.googleusercontent.com';
  static const _identityScopes = <String>['openid', 'email', 'profile'];
  static Future<void>? _initialization;

  /// Returns null only when the person dismisses or interrupts the Google UI.
  /// Configuration and token failures remain errors so the sign-in page can
  /// show an actionable, localized failure instead of a false success.
  Future<BilGoogleIdentityTokens?> authenticate() async {
    try {
      await _ensureInitialized();
      final signIn = GoogleSignIn.instance;
      if (!signIn.supportsAuthenticate()) {
        throw const AuthException(
          'Native Google sign-in is unavailable on this device.',
        );
      }

      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google did not return an identity token.');
      }

      // Supabase validates Google's optional at_hash claim with this access
      // token. These basic OpenID scopes were granted by the sign-in itself;
      // requesting them here does not ask for health, Drive, or other data.
      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _identityScopes,
          ) ??
          await account.authorizationClient.authorizeScopes(_identityScopes);
      final accessToken = authorization.accessToken.trim();
      if (accessToken.isEmpty) {
        throw const AuthException('Google did not return an access token.');
      }

      return BilGoogleIdentityTokens(
        idToken: idToken,
        accessToken: accessToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw const AuthException('Google sign-in could not be completed.');
    }
  }

  static Future<void> _ensureInitialized() async {
    final initialized = _initialization;
    if (initialized != null) return initialized;

    final initialization = GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      // A transient setup error should not permanently lock out a retry.
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }
}
