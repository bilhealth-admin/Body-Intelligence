import 'package:supabase_flutter/supabase_flutter.dart';

enum BilAuthOutcome { signedIn, confirmationRequired }

class SupabaseAuthService {
  const SupabaseAuthService(this.client);

  final SupabaseClient client;

  static const oauthRedirectUri = 'bil://auth-callback';

  Future<bool> signInWithOAuth(OAuthProvider provider) =>
      client.auth.signInWithOAuth(provider, redirectTo: oauthRedirectUri);

  Future<BilAuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
    return BilAuthOutcome.signedIn;
  }

  Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'bil://auth-callback/reset-password',
      );

  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) => client.auth.verifyOTP(email: email, token: code, type: OtpType.signup);

  Future<void> resendSignupCode(String email) =>
      client.auth.resend(type: OtpType.signup, email: email);

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
      data: <String, dynamic>{'full_name': fullName, 'phone': phone},
    );
    return response.session == null
        ? BilAuthOutcome.confirmationRequired
        : BilAuthOutcome.signedIn;
  }
}
