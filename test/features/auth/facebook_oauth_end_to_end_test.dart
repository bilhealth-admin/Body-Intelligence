import 'dart:convert';

import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform Facebook OAuth returns through PKCE into a Supabase session',
      () async {
        const launcherChannel = MethodChannel(
          'plugins.flutter.io/url_launcher',
        );
        Uri? launchedUri;
        final requests = <http.Request>[];
        const expectedOwnerId = 'a1b2c3d4-1234-4abc-8def-0123456789ab';
        final transport = MockClient((request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.origin, 'https://bil-test.supabase.co');
          expect(request.url.path, '/auth/v1/token');
          expect(request.url.queryParameters['grant_type'], 'pkce');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['auth_code'], 'synthetic-facebook-code');
          final verifier = body['code_verifier'] as String;
          final challenge = base64Url
              .encode(sha256.convert(utf8.encode(verifier)).bytes)
              .replaceAll('=', '');
          expect(launchedUri!.queryParameters['code_challenge'], challenge);

          return http.Response(
            jsonEncode({
              'access_token': _testJwt(),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'synthetic-refresh-token',
              'user': {
                'id': expectedOwnerId,
                'app_metadata': {
                  'provider': 'facebook',
                  'providers': ['facebook'],
                },
                'user_metadata': {'full_name': 'Synthetic Facebook User'},
                'aud': 'authenticated',
                'email': 'facebook-test@example.invalid',
                'created_at': '2026-01-01T00:00:00.000Z',
                'identities': [],
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });

        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcherChannel,
          (call) async {
            expect(call.method, 'launch');
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args['useWebView'], isFalse);
            launchedUri = Uri.parse(args['url'] as String);
            return true;
          },
        );

        final storage = _MemoryAuthStorage();
        final client = SupabaseClient(
          'https://bil-test.supabase.co',
          'synthetic-anon-key',
          httpClient: transport,
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            pkceAsyncStorage: storage,
          ),
        );
        final service = SupabaseAuthService(client);
        final oldPlatform = debugDefaultTargetPlatformOverride;
        final routes = <String>[];
        final errors = <Object>[];
        try {
          debugDefaultTargetPlatformOverride = platform;
          expect(client.auth.currentSession, isNull);

          // User taps Facebook: the production service generates PKCE state and
          // opens the operating-system browser via the mocked platform channel.
          expect(await service.signInWithOAuth(OAuthProvider.facebook), isTrue);
          expect(launchedUri, isNotNull);
          expect(launchedUri!.path, '/auth/v1/authorize');
          expect(launchedUri!.queryParameters['provider'], 'facebook');
          expect(
            launchedUri!.queryParameters['redirect_to'],
            SupabaseAuthService.oauthRedirectUri,
          );
          expect(launchedUri!.queryParameters['code_challenge_method'], 's256');
          expect(
            storage.values['supabase.auth.token-code-verifier'],
            isNotNull,
          );
          expect(client.auth.currentSession, isNull);

          // The verified app link returns from the browser. The real callback
          // controller invokes the real GoTrue PKCE exchange through local HTTP.
          final callback = Uri.parse(
            'https://www.bilhealth.com/auth/callback?code=synthetic-facebook-code',
          );
          final controller = BilAuthCallbackController(
            resolve: (uri) async => client.auth.getSessionFromUrl(uri),
            navigate: routes.add,
            onError: (error, _) => errors.add(error),
          );
          expect(await controller.handle(callback), isTrue);

          expect(errors, isEmpty);
          expect(routes, ['/auth-callback']);
          expect(requests, hasLength(1));
          expect(
            storage.values,
            isNot(contains('supabase.auth.token-code-verifier')),
          );
          expect(client.auth.currentSession?.user.id, expectedOwnerId);
          expect(
            client.auth.currentUser?.email,
            'facebook-test@example.invalid',
          );

          // Native app-link duplicate delivery is idempotent: it must not spend
          // the one-time authorization code a second time.
          expect(await controller.handle(callback), isTrue);
          expect(requests, hasLength(1));
          expect(client.auth.currentSession?.user.id, expectedOwnerId);
        } finally {
          debugDefaultTargetPlatformOverride = oldPlatform;
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            launcherChannel,
            null,
          );
          await client.dispose();
          transport.close();
        }
      },
    );
  }
}

String _testJwt() {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'a1b2c3d4-1234-4abc-8def-0123456789ab',
            'role': 'authenticated',
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.$payload.synthetic-signature';
}

class _MemoryAuthStorage extends GotrueAsyncStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
