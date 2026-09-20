import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:body_intelligence_log/features/auth/oauth_browser_return.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    test('browser return on $platform dismisses only iOS', () async {
      var closes = 0;
      await dismissIosOAuthBrowserAfterCallback(
        platform: platform,
        isWeb: false,
        closeBrowser: () async => closes++,
      );
      expect(closes, platform == TargetPlatform.iOS ? 1 : 0);
    });
  }

  test('web never dismisses a browser even when reporting iOS', () async {
    var closes = 0;
    await dismissIosOAuthBrowserAfterCallback(
      platform: TargetPlatform.iOS,
      isWeb: true,
      closeBrowser: () async => closes++,
    );
    expect(closes, 0);
  });

  for (final failExchange in [false, true]) {
    test(
      'trusted callback dismisses browser before exchange, failure=$failExchange',
      () async {
        final events = <String>[];
        final controller = BilAuthCallbackController(
          resolve: (_) async {
            await dismissIosOAuthBrowserAfterCallback(
              platform: TargetPlatform.iOS,
              isWeb: false,
              closeBrowser: () async => events.add('close'),
            );
            events.add('exchange');
            if (failExchange) throw StateError('provider declined');
          },
          navigate: events.add,
          onError: (_, _) => events.add('error'),
        );
        final callback = Uri.parse(
          'https://www.bilhealth.com/auth/callback?${failExchange ? 'error=access_denied' : 'code=one-time'}',
        );
        await controller.handle(callback);
        await controller.handle(callback);
        expect(events, [
          '/auth-callback',
          'close',
          'exchange',
          if (failExchange) ...['error', '/auth-callback?failed=1'],
        ]);
      },
    );
  }

  test(
    'untrusted and ordinary links never trigger browser dismissal',
    () async {
      var closes = 0;
      final controller = BilAuthCallbackController(
        resolve: (_) async => closes++,
        navigate: (_) => fail('untrusted link navigated'),
        onError: (_, _) => fail('untrusted link reached resolver'),
      );
      for (final value in [
        'https://evil.example/auth/callback?code=x',
        'https://attacker@www.bilhealth.com/auth/callback?code=x',
        'https://www.bilhealth.com/legal/privacy',
        'bil://auth-callback?code=x',
      ]) {
        expect(await controller.handle(Uri.parse(value)), isFalse);
      }
      expect(closes, 0);
    },
  );

  test('native close failure does not veto authentication', () async {
    await dismissIosOAuthBrowserAfterCallback(
      platform: TargetPlatform.iOS,
      isWeb: false,
      closeBrowser: () async => throw StateError('already dismissed'),
    );
  });

  testWidgets('unresponsive close is bounded and cannot strand callback', (
    tester,
  ) async {
    var completed = false;
    final stuckClose = Completer<void>();
    final future = dismissIosOAuthBrowserAfterCallback(
      platform: TargetPlatform.iOS,
      isWeb: false,
      closeBrowser: () => stuckClose.future,
    ).then((_) => completed = true);
    await tester.pump(const Duration(milliseconds: 999));
    expect(completed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    await future;
    expect(completed, isTrue);
    stuckClose.complete();
  });

  test('native bootstrap dismisses before the real Supabase exchange', () {
    final source = File('lib/main.dart').readAsStringSync();
    final resolver = source.substring(source.indexOf('resolve: (uri) async {'));
    expect(
      resolver.indexOf('await dismissIosOAuthBrowserAfterCallback();'),
      allOf(
        greaterThanOrEqualTo(0),
        lessThan(resolver.indexOf('auth.getSessionFromUrl(uri)')),
      ),
    );
  });
}
