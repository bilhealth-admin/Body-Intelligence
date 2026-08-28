import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary login is email OTP with no password or registration CTA', () {
    final login = File(
      'lib/features/auth/premium_login_page.dart',
    ).readAsStringSync();
    final auth = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();

    expect(login, contains("Key('login-email')"));
    expect(login, contains('AuthEntryCopyKey.verify'));
    expect(login, contains("context.push('/verify-email', extra: normalized)"));
    expect(login, isNot(contains("Key('login-password')")));
    expect(login, isNot(contains("Key('forgot-password')")));
    expect(login, isNot(contains("Key('open-register')")));
    expect(login, isNot(contains('Welcome back')));
    expect(login, isNot(contains('We will never post anything')));
    expect(login, isNot(contains('Continue privately on this device')));
    expect(login, isNot(contains('AuthLanguageSelector')));

    expect(auth, contains('signInWithOtp'));
    expect(auth, contains('shouldCreateUser: true'));
    expect(auth, contains('OtpType.email'));
  });

  test('verification UI has six boxes and a blue 60 second countdown', () {
    final verify = File(
      'lib/features/auth/verify_email_page.dart',
    ).readAsStringSync();

    expect(verify, contains('int resendSeconds = 59;'));
    expect(verify, contains('const Duration(seconds: 60)'));
    expect(verify, contains('List.generate(6'));
    expect(verify, contains("Key('resend-email-code')"));
    expect(verify, contains("padLeft(2, '0')"));
    expect(verify, contains('authEntryResendCountdown(context, _clock)'));
    expect(verify, contains('sendEmailOtp(widget.email)'));
    expect(verify, contains('Color(0xFF0877F9)'));
    expect(verify, isNot(contains('AuthLanguageSelector')));
  });

  test(
    'gateway starts with progress, not food, and retains local continuation',
    () {
      final gateway = File(
        'lib/features/auth/premium_account_gateway_page.dart',
      ).readAsStringSync();

      expect(gateway, contains('AuthEntryCopyKey.signIn'));
      expect(gateway, contains('AuthEntryCopyKey.continueWithoutAccount'));
      final progress = gateway.indexOf('bil_body_intelligence_journey_v1.png');
      final meal = gateway.indexOf('bil_meal_discovery_v2.png');
      expect(progress, greaterThanOrEqualTo(0));
      expect(meal, greaterThan(progress));
    },
  );
}
