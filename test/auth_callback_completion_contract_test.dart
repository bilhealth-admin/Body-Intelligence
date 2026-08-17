import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native OAuth callback waits for a Supabase session then uses startup', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final page = File(
      'lib/features/auth/auth_callback_page.dart',
    ).readAsStringSync();

    expect(router, contains("return isPasswordRecovery ? '/reset-password' : '/auth-callback';"));
    expect(router, contains("path: '/auth-callback'"));
    expect(router, contains('const AuthCallbackPage()'));
    expect(page, contains('auth.currentSession != null'));
    expect(page, contains('auth.onAuthStateChange.listen'));
    expect(page, contains('await Future<void>.delayed(Duration.zero)'));
    expect(page, contains("context.go('/startup')"));
    expect(page, isNot(contains("context.go('/dashboard')")));
  });
}
