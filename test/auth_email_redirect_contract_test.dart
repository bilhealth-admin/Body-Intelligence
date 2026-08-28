import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OAuth keeps BIL callback while email OTP auto-creates safely', () {
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();

    expect(
      service,
      contains("static const oauthRedirectUri = 'bil://auth-callback';"),
    );
    expect(
      service,
      contains('static const emailRedirectUri = oauthRedirectUri;'),
    );
    expect(service, contains('client.auth.signInWithOtp'));
    expect(service, contains('emailRedirectTo: emailRedirectUri'));
    expect(service, contains('shouldCreateUser: true'));
    expect(service, contains('type: OtpType.email'));
    expect(
      service,
      contains("'https://www.bilhealth.com/auth/reset-password'"),
    );
  });

  test('successful email OTP verification returns through startup policy', () {
    final verify = File(
      'lib/features/auth/verify_email_page.dart',
    ).readAsStringSync();
    final login = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();

    expect(login, contains("context.push('/verify-email', extra: normalized)"));
    expect(verify, contains('verifyEmailOtp('));
    expect(verify, contains("context.go('/startup')"));
  });
}
