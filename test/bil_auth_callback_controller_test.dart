import 'dart:async';

import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exchanges an exact verified HTTPS OAuth callback once', () async {
    final resolved = <Uri>[];
    final routes = <String>[];
    final controller = BilAuthCallbackController(
      resolve: (uri) async => resolved.add(uri),
      navigate: routes.add,
      onError: (_, _) {},
    );
    final callback = Uri.parse(
      'https://www.bilhealth.com/auth/callback?code=single-use-code',
    );

    expect(await controller.handle(callback), isTrue);
    expect(await controller.handle(callback), isTrue);

    expect(resolved, <Uri>[callback]);
    expect(routes, <String>['/auth-callback']);
  });

  test('accepts HTTPS and the exact Android Google callback scheme', () async {
    final resolved = <Uri>[];
    final controller = BilAuthCallbackController(
      resolve: (uri) async => resolved.add(uri),
      navigate: (_) {},
      onError: (_, _) {},
    );

    expect(
      await controller.handle(
        Uri.parse(
          'https://www.bilhealth.com/auth/callback#access_token=test-token',
        ),
      ),
      isTrue,
    );
    expect(
      await controller.handle(
        Uri.parse('bil://auth-callback?code=android-google-code'),
      ),
      isTrue,
    );
    expect(
      await controller.handle(Uri.parse('bil://plans?code=not-auth')),
      isFalse,
    );
    expect(resolved, hasLength(2));
  });

  test('rejects unverified OAuth callback lookalikes', () async {
    final controller = BilAuthCallbackController(
      resolve: (_) async {},
      navigate: (_) {},
      onError: (_, _) {},
    );

    for (final raw in <String>[
      'http://www.bilhealth.com/auth/callback?code=x',
      'https://bilhealth.com/auth/callback?code=x',
      'https://www.bilhealth.com.evil.example/auth/callback?code=x',
      'https://www.bilhealth.com:444/auth/callback?code=x',
      'https://attacker@www.bilhealth.com/auth/callback?code=x',
      'https://www.bilhealth.com/auth/callback/extra?code=x',
      'https://www.bilhealth.com/auth/other?code=x',
      'bil://auth-callback/other?code=x',
    ]) {
      expect(await controller.handle(Uri.parse(raw)), isFalse, reason: raw);
    }
  });

  test('routes callback errors to the immediate failure state', () async {
    final routes = <String>[];
    final errors = <Object>[];
    final controller = BilAuthCallbackController(
      resolve: (_) async => throw StateError('exchange failed'),
      navigate: routes.add,
      onError: (error, _) => errors.add(error),
    );

    expect(
      await controller.handle(
        Uri.parse(
          'https://www.bilhealth.com/auth/callback?error=access_denied',
        ),
      ),
      isTrue,
    );
    expect(routes, <String>['/auth-callback', '/auth-callback?failed=1']);
    expect(errors.single, isA<StateError>());
  });

  test(
    'failed OAuth callback retries explicitly then deduplicates after success',
    () async {
      final routes = <String>[];
      final errors = <Object>[];
      var resolveCalls = 0;
      final controller = BilAuthCallbackController(
        resolve: (_) async {
          resolveCalls += 1;
          if (resolveCalls == 1) throw StateError('temporary exchange failure');
        },
        navigate: routes.add,
        onError: (error, _) => errors.add(error),
      );
      final callback = Uri.parse(
        'https://www.bilhealth.com/auth/callback?code=retryable-single-use-code',
      );

      expect(await controller.handle(callback), isTrue);
      // A duplicate OS delivery must not silently retry a failed exchange.
      expect(await controller.handle(callback), isTrue);
      expect(resolveCalls, 1);

      expect(await controller.retryLastFailed(), isTrue);
      expect(await controller.handle(callback), isTrue);

      expect(resolveCalls, 2);
      expect(errors, hasLength(1));
      expect(routes, <String>[
        '/auth-callback',
        '/auth-callback?failed=1',
        '/auth-callback',
      ]);
    },
  );

  test(
    'retry rejoins a slow in-flight callback without exchanging twice',
    () async {
      final exchange = Completer<void>();
      var resolveCalls = 0;
      final routes = <String>[];
      final controller = BilAuthCallbackController(
        resolve: (_) {
          resolveCalls += 1;
          return exchange.future;
        },
        navigate: routes.add,
        onError: (_, _) {},
      );
      final callback = Uri.parse(
        'https://www.bilhealth.com/auth/callback?code=slow-code',
      );

      final first = controller.handle(callback);
      final retry = controller.retryLastFailed();
      exchange.complete();

      expect(await first, isTrue);
      expect(await retry, isTrue);
      expect(resolveCalls, 1);
      expect(routes, <String>['/auth-callback']);
    },
  );

  test('keeps the password-recovery callback on its dedicated route', () async {
    final routes = <String>[];
    final controller = BilAuthCallbackController(
      resolve: (_) async {},
      navigate: routes.add,
      onError: (_, _) {},
    );

    expect(
      await controller.handle(
        Uri.parse(
          'https://www.bilhealth.com/auth/reset-password?code=recovery-code',
        ),
      ),
      isTrue,
    );
    expect(routes, <String>['/reset-password', '/reset-password?verified=1']);
  });

  test(
    'password recovery failure is terminal and explicitly retryable',
    () async {
      final routes = <String>[];
      var resolveCalls = 0;
      final controller = BilAuthCallbackController(
        resolve: (_) async {
          resolveCalls += 1;
          if (resolveCalls == 1) throw StateError('temporary recovery failure');
        },
        navigate: routes.add,
        onError: (_, _) {},
      );
      final callback = Uri.parse(
        'https://www.bilhealth.com/auth/reset-password?code=recovery-code',
      );

      expect(await controller.handle(callback), isTrue);
      expect(routes, <String>['/reset-password', '/reset-password?failed=1']);

      expect(await controller.retryLastFailed(), isTrue);
      expect(resolveCalls, 2);
      expect(routes.last, '/reset-password?verified=1');
      expect(await controller.retryLastFailed(), isFalse);
    },
  );
}
