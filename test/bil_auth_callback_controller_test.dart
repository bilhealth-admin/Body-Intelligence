import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exchanges an exact native OAuth callback once', () async {
    final resolved = <Uri>[];
    final routes = <String>[];
    final controller = BilAuthCallbackController(
      resolve: (uri) async => resolved.add(uri),
      navigate: routes.add,
      onError: (_, _) {},
    );
    final callback = Uri.parse('bil://auth-callback?code=single-use-code');

    expect(await controller.handle(callback), isTrue);
    expect(await controller.handle(callback), isTrue);

    expect(resolved, <Uri>[callback]);
    expect(routes, <String>['/auth-callback']);
  });

  test('accepts fragment tokens but rejects unrelated deep links', () async {
    final resolved = <Uri>[];
    final controller = BilAuthCallbackController(
      resolve: (uri) async => resolved.add(uri),
      navigate: (_) {},
      onError: (_, _) {},
    );

    expect(
      await controller.handle(
        Uri.parse('bil://auth-callback#access_token=test-token'),
      ),
      isTrue,
    );
    expect(
      await controller.handle(Uri.parse('bil://plans?code=not-auth')),
      isFalse,
    );
    expect(resolved, hasLength(1));
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
        Uri.parse('bil://auth-callback?error=access_denied'),
      ),
      isTrue,
    );
    expect(routes, <String>['/auth-callback', '/auth-callback?failed=1']);
    expect(errors.single, isA<StateError>());
  });

  test('keeps the password-recovery callback on its dedicated route', () async {
    final routes = <String>[];
    final controller = BilAuthCallbackController(
      resolve: (_) async {},
      navigate: routes.add,
      onError: (_, _) {},
    );

    expect(
      await controller.handle(
        Uri.parse('bil://auth-callback/reset-password?code=recovery-code'),
      ),
      isTrue,
    );
    expect(routes, <String>['/reset-password']);
  });
}
