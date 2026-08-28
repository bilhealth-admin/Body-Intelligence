import 'package:supabase_flutter/supabase_flutter.dart';

enum BilAuthOutcome { signedIn, confirmationRequired }

class SupabaseAuthService {
  const SupabaseAuthService(this.client);

  final SupabaseClient client;

  static const oauthRedirectUri = 'bil://auth-callback';
  static const emailRedirectUri = oauthRedirectUri;
  static const passwordResetRedirectUri =
      'https://www.bilhealth.com/auth/reset-password';

  Future<bool> signInWithOAuth(OAuthProvider provider) =>
      client.auth.signInWithOAuth(provider, redirectTo: oauthRedirectUri);

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
