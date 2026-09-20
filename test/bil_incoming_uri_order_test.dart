import 'dart:async';

import 'package:body_intelligence_log/app/analytics/bil_incoming_link_controller.dart';
import 'package:body_intelligence_log/app/analytics/bil_launch_event.dart';
import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'distinct callback URIs are handled strictly in arrival order',
    () async {
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final started = <String>[];
      final completed = <String>[];
      final dispatcher = BilSerialUriDispatcher(
        handle: (uri) async {
          final code = uri.queryParameters['code']!;
          started.add(code);
          await (code == 'first' ? firstGate.future : secondGate.future);
          completed.add(code);
        },
        onError: (error, stackTrace) => fail('unexpected error: $error'),
      );

      dispatcher.add(
        Uri.parse('https://www.bilhealth.com/auth/callback?code=first'),
      );
      dispatcher.add(
        Uri.parse('https://www.bilhealth.com/auth/callback?code=second'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(started, ['first']);

      firstGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(started, ['first', 'second']);
      expect(completed, ['first']);

      secondGate.complete();
      await dispatcher.drained;
      expect(completed, ['first', 'second']);
    },
  );

  test(
    'auth callback completes before a later generic link navigates',
    () async {
      final authGate = Completer<void>();
      final routes = <String>[];
      final auth = BilAuthCallbackController(
        resolve: (_) => authGate.future,
        navigate: routes.add,
        onError: (error, stackTrace) => fail('unexpected auth error: $error'),
      );
      final generic = BilIncomingLinkController(
        analytics: _Sink(),
        navigate: routes.add,
        clock: () => DateTime.utc(2026, 9, 5),
      );
      final dispatcher = BilSerialUriDispatcher(
        handle: (uri) async {
          if (await auth.handle(uri)) return;
          await generic.handle(uri);
        },
        onError: (error, stackTrace) => fail('unexpected link error: $error'),
      );

      dispatcher.add(
        Uri.parse('https://www.bilhealth.com/auth/callback?code=one-time'),
      );
      dispatcher.add(Uri.parse('bil://plans'));
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/auth-callback']);

      authGate.complete();
      await dispatcher.drained;
      expect(routes, ['/auth-callback', '/plans']);
    },
  );

  test('a failed URI is reported and does not poison the queue', () async {
    final handled = <String>[];
    final errors = <Object>[];
    final dispatcher = BilSerialUriDispatcher(
      handle: (uri) async {
        if (uri.host == 'first') throw StateError('expected failure');
        handled.add(uri.host);
      },
      onError: (error, stackTrace) => errors.add(error),
    );

    dispatcher.add(Uri.parse('bil://first'));
    dispatcher.add(Uri.parse('bil://second'));
    await dispatcher.drained;

    expect(errors.single, isA<StateError>());
    expect(handled, ['second']);
  });
}

final class _Sink implements BilLaunchAnalyticsSink {
  @override
  Future<void> record(BilLaunchEvent event) async {}
}
