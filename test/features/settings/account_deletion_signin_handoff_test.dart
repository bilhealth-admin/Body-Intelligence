import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:body_intelligence_log/features/settings/account_deletion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '00000000-0000-4000-8000-000000000001';
const _ownerB = '00000000-0000-4000-8000-000000000002';
const _request = '00000000-0000-4000-8000-000000000003';

void main() {
  for (final worker in ['completed', 'pending', 'unavailable']) {
    testWidgets('accepted $worker receipt Close replaces Help with Sign in', (
      tester,
    ) async {
      final h = await _Harness.open(tester);

      h.workerStatus = worker;
      try {
        await h.submit(tester);

        await _flush(tester);
        expect(h.rpcCalls, 1);
        expect(h.workerCalls, 1);
        expect(find.text('Deletion request received'), findsOneWidget);
        expect(Supabase.instance.client.auth.currentUser, isNull);
        expect(h.signedOutEvents, 1);

        expect(h.path, '/help/delete-account');
        expect(find.text(_request), findsOneWidget);
        expect(
          find.text(
            worker == 'completed' ? 'Status: Completed' : 'Status: Pending',
          ),
          findsOneWidget,
        );
        if (worker != 'completed') {
          expect(
            find.textContaining('not been confirmed deleted yet'),
            findsOneWidget,
          );
        }
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await _flush(tester);
        await tester.pumpAndSettle();
        expect(h.path, '/login');
        expect(find.text('Synthetic sign-in screen'), findsOneWidget);
        expect(find.byType(AccountDeletionPage), findsNothing);
        expect(
          h.router.canPop(),
          isFalse,
          reason: 'go replaces the public Help history.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    });
  }

  for (final failure in ['request', 'invalid receipt']) {
    testWidgets('$failure does not sign out, acknowledge, or leave deletion', (
      tester,
    ) async {
      final h = await _Harness.open(tester);

      h.requestFails = failure == 'request';
      h.invalidReceipt = failure == 'invalid receipt';
      try {
        await h.submit(tester);

        await _flush(tester);
        expect(h.rpcCalls, 1);
        expect(h.workerCalls, 0);
        expect(h.signedOutEvents, 0);
        expect(Supabase.instance.client.auth.currentUser?.id, _ownerA);
        expect(find.text('Deletion request received'), findsNothing);
        expect(find.textContaining('Nothing was deleted'), findsOneWidget);

        expect(h.path, '/help/delete-account');
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    });
  }

  testWidgets(
    'a replacement owner during held worker is never signed out or routed',
    (tester) async {
      final held = Completer<void>();
      final h = await _Harness.open(tester);
      h.workerHold = held;
      try {
        await h.submit(tester);
        await _flush(tester);
        expect(h.workerCalls, 1);
        expect(held.isCompleted, isFalse);
        await tester.runAsync(() => h.signIn(_ownerB));
        held.complete();
        await _flush(tester);
        expect(find.text('Deletion request received'), findsOneWidget);
        expect(Supabase.instance.client.auth.currentUser?.id, _ownerB);
        expect(h.signedOutEvents, 0);
        expect(h.logoutCalls, 0);
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await _flush(tester);

        expect(h.path, '/help/delete-account');
        expect(Supabase.instance.client.auth.currentUser?.id, _ownerB);
        expect(h.signedOutEvents, 0);
        expect(h.logoutCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        if (!held.isCompleted) held.complete();
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'a replacement owner after receipt display keeps its navigation',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await h.submit(tester);
        await _flush(tester);
        expect(Supabase.instance.client.auth.currentUser, isNull);
        expect(h.signedOutEvents, 1);
        await tester.runAsync(() => h.signIn(_ownerB));
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await _flush(tester);

        expect(h.path, '/help/delete-account');
        expect(Supabase.instance.client.auth.currentUser?.id, _ownerB);
        expect(h.signedOutEvents, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets('two queued confirmation taps create only one deletion request', (
    tester,
  ) async {
    final held = Completer<void>();
    final h = await _Harness.open(tester);
    h.requestHold = held;
    try {
      await h.prepare(tester);
      final button = _submitButton;
      await tester.tap(button);
      // No rebuild between the actual taps: the old button callback is queued.
      await tester.tap(button);
      await _flush(tester);
      expect(held.isCompleted, isFalse);
      expect(h.rpcCalls, 1);
      expect(h.workerCalls, 0);
      held.complete();
      await _flush(tester);
      expect(find.text('Deletion request received'), findsOneWidget);
      expect(h.workerCalls, 1);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await _flush(tester);
      expect(h.path, '/login');
      expect(h.rpcCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      if (!held.isCompleted) held.complete();
      await h.close(tester);
    }
  });
}

Finder get _submitButton =>
    find.byWidgetPredicate((widget) => widget is FilledButton);

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    // Mock HTTP JSON decoding uses the SDK isolate; allow its real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

class _Harness {
  var workerStatus = 'completed';
  bool requestFails = false, invalidReceipt = false;
  int rpcCalls = 0, workerCalls = 0, logoutCalls = 0, signedOutEvents = 0;
  Completer<void>? requestHold, workerHold;
  StreamSubscription<AuthState>? subscription;
  late GoRouter router;

  String get path =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  static Future<_Harness> open(WidgetTester tester) async {
    expect(AppEnvironment.cloudConfigured, isTrue);
    final h = _Harness();
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await GlobalNativeIntegrationHost.instance.close();
      await GlobalNativeIntegrationHost.instance.initialize(
        database: sqlite3.openInMemory(),
      );
      await Supabase.initialize(
        url: 'https://account-delete-handoff.invalid',
        publishableKey: 'synthetic-public-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: MockClient(h.handle),
      );
      await h.signIn(_ownerA);
    });
    h.subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      if (event.event == AuthChangeEvent.signedOut) h.signedOutEvents++;
    });
    h.router = GoRouter(
      initialLocation: '/help',
      routes: [
        GoRoute(
          path: '/help',
          builder: (_, _) =>
              const Scaffold(body: Text('Synthetic public Help')),
        ),
        GoRoute(
          path: '/help/delete-account',
          builder: (_, _) => const AccountDeletionPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) =>
              const Scaffold(body: Text('Synthetic sign-in screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: h.router,
      ),
    );
    await _flush(tester);

    unawaited(h.router.push<void>('/help/delete-account'));
    await _flush(tester);

    expect(h.path, '/help/delete-account');
    expect(h.router.canPop(), isTrue);
    return h;
  }

  Future<void> signIn(String owner) => Supabase.instance.client.auth
      .setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-token-$owner',
          'refresh_token': 'synthetic-refresh-$owner',
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'app_metadata': {'provider': 'email'},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      )
      .then((_) {});

  Future<http.Response> handle(http.Request request) async {
    Object? body;
    var status = 200;
    if (request.url.path.endsWith('/bil_request_account_deletion')) {
      rpcCalls++;
      await requestHold?.future;
      status = requestFails ? 500 : 200;
      body = requestFails
          ? {'code': 'XX000', 'message': 'synthetic request unavailable'}
          : {
              'request_id': _request,
              'status': invalidReceipt ? false : 'pending',
            };
    } else if (request.url.path.endsWith('/account-data-deletion')) {
      workerCalls++;
      await workerHold?.future;
      status = workerStatus == 'unavailable' ? 503 : 200;
      body = {'request_id': _request, 'status': workerStatus};
    } else if (request.url.path.endsWith('/logout')) {
      logoutCalls++;
      status = 204;
    } else {
      throw StateError(
        'Unexpected synthetic deletion route ${request.url.path}',
      );
    }
    return http.Response(
      status == 204 ? '' : jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> prepare(WidgetTester tester) async {
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'DELETE');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(_submitButton);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await prepare(tester);
    await tester.tap(_submitButton);
  }

  Future<void> close(WidgetTester tester) async {
    if (requestHold != null && !requestHold!.isCompleted) {
      requestHold!.complete();
    }
    if (workerHold != null && !workerHold!.isCompleted) workerHold!.complete();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    await tester.runAsync(() async {
      await subscription?.cancel();
      await Supabase.instance.dispose();
      await GlobalNativeIntegrationHost.instance.close();
    });
  }
}
