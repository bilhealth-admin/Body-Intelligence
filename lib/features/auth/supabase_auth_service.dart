import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apple_credential_lifecycle.dart';
import 'native_facebook_sign_in.dart';
import 'native_google_sign_in.dart';

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
    this.nativeFacebookSignIn = const BilNativeFacebookSignIn(),
    this.nativeGoogleSignIn = const BilNativeGoogleSignIn(),
  });

  final SupabaseClient client;
  final AppleCredentialIdentifierStore? appleCredentialIdentifierStore;
  final AppleAuthorizationCodeRegistrar? appleAuthorizationCodeRegistrar;
  final BilNativeFacebookSignIn nativeFacebookSignIn;
  final BilNativeGoogleSignIn nativeGoogleSignIn;

  static const oauthRedirectUri = 'https://www.bilhealth.com/auth/callback';
  static const emailRedirectUri = oauthRedirectUri;
  static const passwordResetRedirectUri =
      'https://www.bilhealth.com/auth/reset-password';

  /// Browser OAuth remains external-only for providers that need a browser
  /// (for example, Apple on Android). Google and Facebook take their native
  /// mobile SDK routes before this setting is consulted.
  static LaunchMode oauthLaunchModeFor(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return LaunchMode.externalApplication;
  }

  static bool usesNativeGoogleSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      provider == OAuthProvider.google &&
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  static bool usesNativeFacebookSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      provider == OAuthProvider.facebook &&
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  static bool usesNativeIosGoogleSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      usesNativeGoogleSignIn(provider, isWeb: isWeb, platform: platform) &&
      platform == TargetPlatform.iOS;

  static bool usesNativeIosFacebookSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      usesNativeFacebookSignIn(provider, isWeb: isWeb, platform: platform) &&
      platform == TargetPlatform.iOS;

  static bool usesNativeAndroidGoogleSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      usesNativeGoogleSignIn(provider, isWeb: isWeb, platform: platform) &&
      platform == TargetPlatform.android;

  static bool usesNativeAndroidFacebookSignIn(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      usesNativeFacebookSignIn(provider, isWeb: isWeb, platform: platform) &&
      platform == TargetPlatform.android;

  /// Native Google and Facebook never use this URL. Other OAuth providers
  /// retain the verified HTTPS return route.
  static String oauthRedirectUriFor(
    OAuthProvider provider, {
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return oauthRedirectUri;
  }

  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (usesNativeFacebookSignIn(
      provider,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    )) {
      return (await signInWithFacebookNative()) != null;
    }
    if (usesNativeGoogleSignIn(
      provider,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    )) {
      return (await signInWithGoogleNative()) != null;
    }
    return client.auth.signInWithOAuth(
      provider,
      redirectTo: oauthRedirectUriFor(
        provider,
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      ),
      authScreenLaunchMode: oauthLaunchModeFor(
        provider,
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      ),
    );
  }

  /// Signs in through Google's native mobile SDK, then swaps the short-lived Google
  /// identity proof for the same Supabase session used by every BIL surface.
  ///
  /// A null result means the person dismissed Google's system-owned sheet and
  /// is not a sign-in failure.
  Future<AuthResponse?> signInWithGoogleNative() async {
    final tokens = await nativeGoogleSignIn.authenticate();
    if (tokens == null) return null;
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
  }

  /// Signs in through Meta's native mobile SDK, then exchanges its short-lived
  /// identity proof for BIL's normal Supabase session.
  ///
  /// A null result means the person dismissed Meta's authorization UI.
  Future<AuthResponse?> signInWithFacebookNative() async {
    final token = await nativeFacebookSignIn.authenticate();
    if (token == null) return null;
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.facebook,
      idToken: token.idToken,
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
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final appleDisplayName = <String>[
      credential.givenName?.trim() ?? '',
      credential.familyName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ').trim();
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

    // Authentication Services only returns name fields on the first
    // authorization. Persist the value Apple already supplied when available;
    // never require the person to type it again if Apple omits it later.
    if (appleDisplayName.isNotEmpty) {
      try {
        await client.auth.updateUser(
          UserAttributes(data: <String, dynamic>{'full_name': appleDisplayName}),
        );
      } on Object {
        // Name enrichment is optional and must never invalidate a successfully
        // secured Apple session.
      }
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
