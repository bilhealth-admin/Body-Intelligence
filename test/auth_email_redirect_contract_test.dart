import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email signup and resend use the allow-listed BIL auth callback', () {
    final service = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();

    expect(service, contains("static const oauthRedirectUri = 'bil://auth-callback';"));
    expect(service, contains('static const emailRedirectUri = oauthRedirectUri;'));
    expect(service, contains('emailRedirectTo: emailRedirectUri'));
    expect(
      RegExp(r'client\.auth\.resend\([\s\S]*emailRedirectTo: emailRedirectUri').hasMatch(service),
      isTrue,
    );
  });

  test('all successful email auth paths return through startup policy', () {
    final register = File(
      'lib/features/auth/register_page.dart',
    ).readAsStringSync();
    final verify = File(
      'lib/features/auth/verify_email_page.dart',
    ).readAsStringSync();
    final login = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();

    expect(register, contains("context.go('/startup')"));
    expect(verify, contains("context.go('/startup')"));
    expect(login, contains("context.go('/startup')"));
  });

  test('verification copy does not promise an email for repeated signup', () {
    final verify = File(
      'lib/features/auth/verify_email_page.dart',
    ).readAsStringSync();

    expect(verify, contains('If this is a new account'));
    expect(verify, contains('If this email is awaiting verification'));
    expect(verify, isNot(contains("status = tr('A new code was sent.'")));
  });
}
