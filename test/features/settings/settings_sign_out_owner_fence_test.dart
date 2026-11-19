import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_auto_sync_coordinator.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final aba in [false, true]) {
    test(
      'cloud flush owner ${aba ? 'ABA' : 'switch'} never signs out replacement',
      () async {
        final h = await _AuthFixture.open();
        final entered = Completer<void>();
        final held = Completer<void>();
        CloudBeforeSignOutSync.install(() {
          entered.complete();
          return held.future;
        });
        Object? failure;
        final exit = signOutSettingsSession(h.client.auth, _a).catchError((
          Object error,
        ) {
          failure = error;
        });
        await entered.future;
        await h.signIn(_b);
        if (aba) await h.signIn(_a);
        held.complete();
        await exit;
        expect(h.logoutCalls, 0);
        expect(h.client.auth.currentUser?.id, aba ? _a : _b);
        expect(failure, isA<StateError>());
        await h.close();
      },
    );
  }

  test(
    'same-owner token event still allows exactly one local sign-out',
    () async {
      final h = await _AuthFixture.open();
      CloudBeforeSignOutSync.install(() => h.signIn(_a));
      await signOutSettingsSession(h.client.auth, _a);
      expect(h.logoutCalls, 1);
      expect(h.logoutScopes, ['local']);
      expect(h.client.auth.currentUser, isNull);
      await h.close();
    },
  );

  test(
    'replacement while logout HTTP is held is never signed out again',
    () async {
      final h = await _AuthFixture.open();
      final held = Completer<void>();
      h.logoutHold = held;
      Object? failure;
      final exit = signOutSettingsSession(h.client.auth, _a).catchError((
        Object error,
      ) {
        failure = error;
      });
      await h.logoutEntered.future;
      expect(h.client.auth.currentUser, isNull);
      await h.signIn(_b);
      held.complete();
      await exit;
      expect(h.logoutCalls, 1);
      expect(h.client.auth.currentUser?.id, _b);
      expect(failure, isA<StateError>());
      await h.close();
    },
  );

  test(
    'logout transport failure keeps an already cleared device session guest',
    () async {
      final h = await _AuthFixture.open();
      h.logoutStatus = 503;
      await signOutSettingsSession(h.client.auth, _a);
      expect(h.client.auth.currentUser, isNull);
      expect(h.logoutCalls, 1);
      await h.close();
    },
  );
}

class _AuthFixture {
  late SupabaseClient client;
  int logoutCalls = 0, logoutStatus = 204;
  final logoutScopes = <String?>[];
  final logoutEntered = Completer<void>();
  Completer<void>? logoutHold;

  static Future<_AuthFixture> open() async {
    final h = _AuthFixture();
    CloudBeforeSignOutSync.uninstall();
    h.client = SupabaseClient(
      'https://local-sign-out.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (!request.url.path.endsWith('/logout')) {
          throw StateError('Unexpected fixture HTTP ${request.url.path}');
        }
        h.logoutCalls++;
        h.logoutScopes.add(request.url.queryParameters['scope']);
        if (!h.logoutEntered.isCompleted) h.logoutEntered.complete();
        await h.logoutHold?.future;
        return http.Response(
          h.logoutStatus == 204 ? '' : '{"message":"synthetic offline"}',
          h.logoutStatus,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await h.signIn(_a);
    addTearDown(h.close);
    return h;
  }

  Future<void> signIn(String owner) => client.auth
      .setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-token-$owner',
          'refresh_token': 'synthetic-refresh-$owner',
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'app_metadata': {'provider': 'email'},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      )
      .then((_) {});

  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (logoutHold != null && !logoutHold!.isCompleted) logoutHold!.complete();
    CloudBeforeSignOutSync.uninstall();
    await client.dispose();
  }
}
