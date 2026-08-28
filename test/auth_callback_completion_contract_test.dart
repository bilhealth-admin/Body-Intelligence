import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native OAuth callback waits for a Supabase session then uses startup',
    () {
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      final page = File(
        'lib/features/auth/auth_callback_page.dart',
      ).readAsStringSync();

      expect(
        router,
        contains(
          "return isPasswordRecovery ? '/reset-password' : '/auth-callback';",
        ),
      );
      expect(router, contains("path: '/auth-callback'"));
      expect(router, contains('AuthCallbackPage('));
      expect(router, contains("state.uri.queryParameters['failed'] == '1'"));
      expect(page, contains('auth.currentSession != null'));
      expect(page, contains('auth.onAuthStateChange.listen'));
      expect(page, contains('await Future<void>.delayed(Duration.zero)'));
      expect(page, contains('void didUpdateWidget'));
      expect(page, contains('widget.initiallyFailed'));
      expect(page, contains("context.go('/startup')"));
      expect(page, isNot(contains("context.go('/dashboard')")));

      final bootstrap = File('lib/main.dart').readAsStringSync();
      expect(bootstrap, contains('auth.getSessionFromUrl(uri)'));
      expect(bootstrap, contains('BilAuthCallbackController'));
    },
  );
}
