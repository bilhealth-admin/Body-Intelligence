import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apple_credential_lifecycle.dart';
import 'facebook_oauth_launcher.dart';

enum BilAuthOutcome { signedIn, confirmationRequired }

abstract interface class AppleAuthorizationCodeRegistrar {
  Future<void> register({
    required String authorizationCode,
    required String identityToken,
    required String rawNonce,
    required String appleUserIdentifier,
  });
}

final class SupabaseAppleAuthorizationCodeRegistrar
    implements AppleAuthorizationCodeRegistrar {
  const SupabaseAppleAuthorizationCodeRegistrar(this.client);

  final SupabaseClient client;

  @override
  Future<void> register({
    required String authorizationCode,
    required String identityToken,
    required String rawNonce,
    required String appleUserIdentifier,
  }) async {
    final response = await client.functions.invoke(
      'apple-sign-in-token',
      body: <String, String>{
        'authorization_code': authorizationCode,
        'identity_token': identityToken,
        'raw_nonce': rawNonce,
        'apple_user_identifier': appleUserIdentifier,
      },
    );
    final data = response.data;
    if (response.status != 200 || data is! Map || data['registered'] != true) {
      throw const AuthException(
        'Apple authorization could not be secured by the server.',
      );
    }
  }
}

class SupabaseAuthService {
  const SupabaseAuthService(
    this.client, {
    this.appleCredentialIdentifierStore,
    this.appleAuthorizationCodeRegistrar,
    this.facebookOAuthLauncher = const BilFacebookOAuthLauncher(),
  });

  final SupabaseClient client;
  final AppleCredentialIdentifierStore? appleCredentialIdentifierStore;
  final AppleAuthorizationCodeRegistrar? appleAuthorizationCodeRegistrar;
  final BilFacebookOAuthLauncher facebookOAuthLauncher;

  static const oauthRedirectUri = 'https://www.bilhealth.com/auth/callback';
  static const androidGoogleOAuthRedirectUri = 'bil://auth-callback';
  static const emailRedirectUri = oauthRedirectUri;
  static const passwordResetRedirectUri =
      'https://www.bilhealth.com/auth/reset-password';

  /// Facebook stays in a provider-owned browser surface. iOS uses Supabase's
  /// `inAppBrowserView`, which maps to SFSafariViewController. Android obtains
  /// the same Supabase-generated URL but opens it through BIL's strict native
  /// Custom Tabs bridge, which fails closed instead of falling back to WebView.
  /// The verified HTTPS app link returns the completed session to BIL.
  ///
  /// Google remains external because the Android Supabase adapter requires
  /// that mode. Other providers keep the conservative external default until
  /// their signed-device return path is separately verified.
  static LaunchMode oauthLaunchModeFor(OAuthProvider provider) =>
      provider == OAuthProvider.facebook
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;

  static bool usesNativeAndroidFacebookLauncher(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      provider == OAuthProvider.facebook &&
      !isWeb &&
      platform == TargetPlatform.android;

  static String oauthRedirectUriFor(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (!isWeb &&
        platform == TargetPlatform.android &&
        provider == OAuthProvider.google) {
      return androidGoogleOAuthRedirectUri;
    }
    return oauthRedirectUri;
  }

  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (usesNativeAndroidFacebookLauncher(
      provider,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    )) {
      final response = await client.auth.getOAuthSignInUrl(
        provider: provider,
        redirectTo: oauthRedirectUri,
      );
      return facebookOAuthLauncher.open(Uri.parse(response.url));
    }
    return client.auth.signInWithOAuth(
      provider,
      redirectTo: oauthRedirectUriFor(
        provider,
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      ),
      authScreenLaunchMode: oauthLaunchModeFor(provider),
    );
  }

  /// Signs in with Apple's native iOS/macOS authorization sheet.
  ///
  /// The raw nonce is sent to Supabase while the SHA-256 nonce is sent to
  /// Apple. This binds the returned identity token to this login attempt and
  /// avoids opening a browser or relying on an OAuth deep-link callback.
  Future<AuthResponse> signInWithAppleNative() async {
    final rawNonce = client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
      ],
      nonce: hashedNonce,
    );
    final appleUserIdentifier = credential.userIdentifier?.trim();
    if (appleUserIdentifier == null || appleUserIdentifier.isEmpty) {
      throw const AuthException('Apple did not return a user identifier.');
    }
    // Apple authorization codes are single-use and short-lived. BIL forwards
    // this one over the authenticated HTTPS function channel immediately; it
    // is exchanged and encrypted server-side, never logged or stored locally.
    final authorizationCode = credential.authorizationCode.trim();
    if (authorizationCode.isEmpty) {
      throw const AuthException('Apple did not return an authorization code.');
    }
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AuthException('Apple did not return an identity token.');
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: identityToken,
      nonce: rawNonce,
    );
    final ownerId = response.user?.id.trim();
    if (ownerId == null || ownerId.isEmpty) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw const AuthException('Apple sign-in did not return an account.');
    }
    try {
      await (appleAuthorizationCodeRegistrar ??
              SupabaseAppleAuthorizationCodeRegistrar(client))
          .register(
            authorizationCode: authorizationCode,
            identityToken: identityToken,
            rawNonce: rawNonce,
            appleUserIdentifier: appleUserIdentifier,
          );
      await (appleCredentialIdentifierStore ??
              SecureAppleCredentialIdentifierStore())
          .write(ownerId, appleUserIdentifier);
    } catch (_) {
      // Without server-side revocation custody and the Keychain-bound subject,
      // BIL cannot safely complete Apple's lifecycle. Do not leave a partially
      // secured authenticated session behind after either step fails.
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // GoTrue clears its local session before its best-effort server call.
      }
      throw const AuthException('Apple credential could not be secured.');
    }
    return response;
  }

  Future<void> sendEmailOtp(String email) => client.auth.signInWithOtp(
    email: email,
    emailRedirectTo: emailRedirectUri,
    shouldCreateUser: true,
  );

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  Future<BilAuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
    return BilAuthOutcome.signedIn;
  }

  Future<void> sendPasswordReset(String email) => client.auth
      .resetPasswordForEmail(email, redirectTo: passwordResetRedirectUri);

  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.signup,
    );
  }

  Future<void> resendSignupCode(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: emailRedirectUri,
    );
  }

  Future<void> signOutEverywhere() =>
      client.auth.signOut(scope: SignOutScope.global);

  Future<BilAuthOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectUri,
      data: <String, dynamic>{'full_name': fullName, 'phone': phone},
    );
    return response.session == null
        ? BilAuthOutcome.confirmationRequired
        : BilAuthOutcome.signedIn;
  }
}
