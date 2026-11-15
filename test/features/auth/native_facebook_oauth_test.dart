import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/auth/bil_auth_callback_controller.dart';
import 'package:body_intelligence_log/features/auth/native_facebook_oauth.dart';
import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _channel = MethodChannel('bil/facebook_oauth');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    h = _Harness();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, h.native);
  });
  tearDown(() async {
    h.owner.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    await h.client.dispose();
  });

  for (final mode in ['https', 'legacy']) {
    test(
      '$mode uses real GoTrue PKCE and verified shared callback once',
      () async {
        h.mode = mode;
        expect(
          await SupabaseAuthService(
            h.client,
          ).signInWithOAuth(OAuthProvider.facebook),
          isTrue,
        );
        expect(
          h.authorization!.queryParameters['redirect_to'],
          mode == 'https'
              ? BilNativeFacebookOAuth.httpsCallback
              : BilNativeFacebookOAuth.legacyCallback,
        );
        expect(h.requests, hasLength(1));
        final request = h.requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/v1/token');
        expect(request.url.queryParameters['grant_type'], 'pkce');
        final body = jsonDecode(request.body) as Map;
        expect(body['auth_code'], 'synthetic-code');
        final challenge = base64UrlEncode(
          sha256.convert(utf8.encode(body['code_verifier'] as String)).bytes,
        ).replaceAll('=', '');
        expect(h.authorization!.queryParameters['code_challenge'], challenge);
        expect(h.client.auth.currentUser?.id, _ownerId);
        expect(h.routes, ['/auth-callback']);
        expect(h.storage.values, isEmpty);
        final callback = Uri.parse(
          '${BilNativeFacebookOAuth.httpsCallback}?code=synthetic-code',
        );
        expect(await h.controller.handle(callback), isTrue);
        expect(h.requests, hasLength(1));
        expect(
          await h.controller.handle(
            Uri.parse(
              '${BilNativeFacebookOAuth.legacyCallback}?code=synthetic-code',
            ),
          ),
          isFalse,
        );
      },
    );
  }

  test(
    'native completion and app-link delivery join one pending exchange',
    () async {
      final response = Completer<http.Response>();
      h.response = (_) => response.future;
      final signIn = const BilNativeFacebookOAuth().authenticate(h.client);
      await h.exchangeStarted.future;
      final appLink = h.controller.handle(
        Uri.parse(
          '${BilNativeFacebookOAuth.httpsCallback}?code=synthetic-code',
        ),
      );
      expect(h.requests, hasLength(1));
      response.complete(_sessionResponse());
      expect(await signIn, isTrue);
      expect(await appLink, isTrue);
      expect(h.requests, hasLength(1));
    },
  );

  test(
    'cancellation is quiet, does not resolve or exchange, and retry is fresh',
    () async {
      h.nativeResult = (_) => null;
      expect(
        await const BilNativeFacebookOAuth().authenticate(h.client),
        isFalse,
      );
      final previous = h.authorization!.queryParameters['code_challenge'];
      expect(h.requests, isEmpty);
      expect(h.routes, isEmpty);
      h.nativeResult = h.success;
      expect(
        await const BilNativeFacebookOAuth().authenticate(h.client),
        isTrue,
      );
      expect(
        h.authorization!.queryParameters['code_challenge'],
        isNot(previous),
      );
    },
  );

  test('concurrent attempts cannot overwrite the first verifier', () async {
    final native = Completer<Map<String, dynamic>?>();
    h.nativeResult = (_) => native.future;
    final first = const BilNativeFacebookOAuth().authenticate(h.client);
    await h.nativeStarted.future;
    final before = Map<String, String>.from(h.storage.values);
    await expectLater(
      const BilNativeFacebookOAuth().authenticate(h.client),
      throwsA(isA<AuthException>()),
    );
    expect(h.storage.values, before);
    expect(h.calls.where((c) => c.method == 'authenticate'), hasLength(1));
    native.complete(null);
    expect(await first, isFalse);
  });

  test('replaced owner rejects old completion before exchange', () async {
    final native = Completer<Map<String, dynamic>?>();
    Map<String, dynamic>? arguments;
    h.nativeResult = (a) {
      arguments = a;
      return native.future;
    };
    final first = const BilNativeFacebookOAuth().authenticate(h.client);
    await h.nativeStarted.future;
    var newOwnerCalls = 0;
    final nextOwner = BilNativeFacebookOAuth.attachCallbackOwner((_) async {
      newOwnerCalls++;
      return true;
    });
    try {
      native.complete(h.success(arguments!));
      await expectLater(first, throwsA(isA<AuthException>()));
      expect(newOwnerCalls, 0);
      expect(h.requests, isEmpty);
      expect(h.routes, isEmpty);
      expect(h.calls.any((c) => c.method == 'cancel'), isTrue);
    } finally {
      nextOwner.dispose();
    }
  });

  test(
    'no callback owner fails before native launch or verifier creation',
    () async {
      h.owner.dispose();
      await expectLater(
        const BilNativeFacebookOAuth().authenticate(h.client),
        throwsA(isA<AuthException>()),
      );
      expect(h.storage.values, isEmpty);
      expect(h.calls, isEmpty);
    },
  );

  test(
    'native error cannot expose its callback/secret-shaped message',
    () async {
      h.nativeResult = (_) => throw PlatformException(
        code: 'start_failed',
        message: 'synthetic-private-code-and-token',
      );
      try {
        await const BilNativeFacebookOAuth().authenticate(h.client);
        fail('Expected safe failure');
      } on AuthException catch (error) {
        expect(error.toString(), isNot(contains('synthetic-private')));
      }
      expect(h.requests, isEmpty);
    },
  );

  test(
    'native timeout cancels exact attempt and ignores its late callback',
    () async {
      final native = Completer<Map<String, dynamic>?>();
      Map<String, dynamic>? arguments;
      h.nativeResult = (a) {
        arguments = a;
        return native.future;
      };
      await expectLater(
        const BilNativeFacebookOAuth(
          sessionTimeout: Duration(milliseconds: 20),
        ).authenticate(h.client),
        throwsA(isA<AuthException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final cancel = h.calls.singleWhere((c) => c.method == 'cancel');
      expect((cancel.arguments as Map)['attemptId'], arguments!['attemptId']);
      native.complete(h.success(arguments!));
      await Future<void>.delayed(Duration.zero);
      expect(h.requests, isEmpty);
      expect(h.routes, isEmpty);
    },
  );

  for (final bad in [
    'https://evil.example/auth/callback?code=synthetic-code',
    'https://www.bilhealth.com.evil.example/auth/callback?code=synthetic-code',
    'https://www.bilhealth.com/auth/reset-password?code=synthetic-code',
    'https://user@www.bilhealth.com/auth/callback?code=synthetic-code',
    'https://www.bilhealth.com:8443/auth/callback?code=synthetic-code',
    'bil://auth/callback?code=synthetic-code',
    'https://www.bilhealth.com/auth/callback?code=one&code=two',
    'https://www.bilhealth.com/auth/callback?code=',
    'https://www.bilhealth.com/auth/callback',
    'https://www.bilhealth.com/auth/callback#access_token=synthetic-token',
    'https://www.bilhealth.com/auth/callback?code=synthetic-code&refresh_token=synthetic-token',
  ]) {
    test(
      'native HTTPS result rejects invalid origin or payload: $bad',
      () async {
        h.nativeResult = (a) => {
          'attemptId': a['attemptId'],
          'callbackUrl': bad,
        };
        await expectLater(
          const BilNativeFacebookOAuth().authenticate(h.client),
          throwsA(isA<AuthException>()),
        );
        expect(h.requests, isEmpty);
        expect(h.routes, isEmpty);
      },
    );
  }

  test(
    'legacy result cannot accept HTTPS, foreign path or old attempt id',
    () async {
      h.mode = 'legacy';
      for (final bad in [
        BilNativeFacebookOAuth.httpsCallback,
        'bil://evil/callback',
        'bil://auth/reset-password',
      ]) {
        h.nativeResult = (a) => {
          'attemptId': a['attemptId'],
          'callbackUrl': '$bad?code=synthetic-code',
        };
        await expectLater(
          const BilNativeFacebookOAuth().authenticate(h.client),
          throwsA(isA<AuthException>()),
        );
      }
      h.nativeResult = (_) => {
        'attemptId': 'old-attempt',
        'callbackUrl':
            '${BilNativeFacebookOAuth.legacyCallback}?code=synthetic-code',
      };
      await expectLater(
        const BilNativeFacebookOAuth().authenticate(h.client),
        throwsA(isA<AuthException>()),
      );
      expect(h.requests, isEmpty);
    },
  );

  test(
    'provider error follows shared safe failure without token exchange',
    () async {
      h.nativeResult = (a) => {
        'attemptId': a['attemptId'],
        'callbackUrl':
            '${BilNativeFacebookOAuth.httpsCallback}?error=access_denied',
      };
      expect(
        await const BilNativeFacebookOAuth().authenticate(h.client),
        isFalse,
      );
      expect(h.requests, isEmpty);
      expect(h.routes, ['/auth-callback', '/auth-callback?failed=1']);
      expect(h.errors, hasLength(1));
    },
  );

  test(
    'rejected PKCE exchange never reports an existing session as success',
    () async {
      await h.client.auth.recoverSession(_sessionResponse().body);
      expect(h.client.auth.currentSession, isNotNull);
      h.response = (_) async => http.Response(
        '{"error":"invalid_grant"}',
        400,
        headers: {'content-type': 'application/json'},
      );
      expect(
        await const BilNativeFacebookOAuth().authenticate(h.client),
        isFalse,
      );
      expect(h.requests, hasLength(1));
      expect(h.client.auth.currentUser?.id, _ownerId);
      expect(h.errors, hasLength(1));
    },
  );

  test('missing verifier cannot make an auth token request', () async {
    h.nativeResult = (args) {
      h.storage.values.clear();
      return h.success(args);
    };
    expect(
      await const BilNativeFacebookOAuth().authenticate(h.client),
      isFalse,
    );
    expect(h.requests, isEmpty);
    expect(h.client.auth.currentSession, isNull);
    expect(h.errors, hasLength(1));
  });

  test('unknown native mode fails before generating PKCE state', () async {
    h.mode = 'unsupported';
    await expectLater(
      const BilNativeFacebookOAuth().authenticate(h.client),
      throwsA(isA<AuthException>()),
    );
    expect(h.storage.values, isEmpty);
    expect(h.requests, isEmpty);
    expect(h.calls.where((c) => c.method == 'authenticate'), isEmpty);
  });

  test(
    'auth owner A to B to A irreversibly retires the held attempt',
    () async {
      await h.client.auth.recoverSession(_sessionResponse().body);
      final native = Completer<Map<String, dynamic>?>();
      Map<String, dynamic>? args;
      h.nativeResult = (value) {
        args = value;
        return native.future;
      };
      final signIn = const BilNativeFacebookOAuth().authenticate(h.client);
      await h.nativeStarted.future;
      await h.client.auth.recoverSession(
        _sessionResponse(ownerId: _otherOwnerId).body,
      );
      await h.client.auth.recoverSession(_sessionResponse().body);
      native.complete(h.success(args!));
      await expectLater(signIn, throwsA(isA<AuthException>()));
      expect(h.client.auth.currentUser?.id, _ownerId);
      expect(h.requests, isEmpty);
      expect(h.routes, isEmpty);
      expect(h.calls.where((call) => call.method == 'cancel'), isNotEmpty);
    },
  );

  test('logout while native result is held blocks token exchange', () async {
    await h.client.auth.recoverSession(_sessionResponse().body);
    final native = Completer<Map<String, dynamic>?>();
    Map<String, dynamic>? args;
    h.nativeResult = (value) {
      args = value;
      return native.future;
    };
    final signIn = const BilNativeFacebookOAuth().authenticate(h.client);
    await h.nativeStarted.future;
    await h.client.auth.signOut(scope: SignOutScope.local);
    native.complete(h.success(args!));
    await expectLater(signIn, throwsA(isA<AuthException>()));
    expect(h.client.auth.currentUser, isNull);
    expect(
      h.requests.where((request) => request.url.path == '/auth/v1/token'),
      isEmpty,
    );
    expect(h.routes, isEmpty);
  });

  test(
    'same-owner real token refresh preserves the held native attempt',
    () async {
      await h.client.auth.recoverSession(_sessionResponse().body);
      final native = Completer<Map<String, dynamic>?>();
      Map<String, dynamic>? args;
      h.nativeResult = (value) {
        args = value;
        return native.future;
      };
      final signIn = const BilNativeFacebookOAuth().authenticate(h.client);
      await h.nativeStarted.future;
      await h.client.auth.refreshSession();
      native.complete(h.success(args!));
      expect(await signIn, isTrue);
      expect(
        h.requests.where(
          (request) =>
              request.url.queryParameters['grant_type'] == 'refresh_token',
        ),
        hasLength(1),
      );
      expect(
        h.requests.where(
          (request) => request.url.queryParameters['grant_type'] == 'pkce',
        ),
        hasLength(1),
      );
      expect(h.calls.where((call) => call.method == 'cancel'), isEmpty);
    },
  );

  test(
    'last sign-out event before a new attempt is a valid starting state',
    () async {
      await h.client.auth.recoverSession(_sessionResponse().body);
      await h.client.auth.signOut(scope: SignOutScope.local);
      h.requests.clear();
      expect(
        await const BilNativeFacebookOAuth().authenticate(h.client),
        isTrue,
      );
      expect(h.requests, hasLength(1));
      expect(h.client.auth.currentUser?.id, _ownerId);
    },
  );

  test(
    'auth change before mode returns cannot write a PKCE verifier',
    () async {
      final mode = Completer<String>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        if (call.method == 'callbackMode') return mode.future;
        expect(call.method, 'cancel');
        return null;
      });
      final signIn = const BilNativeFacebookOAuth().authenticate(h.client);
      await h.client.auth.recoverSession(
        _sessionResponse(ownerId: _otherOwnerId).body,
      );
      mode.complete('https');
      await expectLater(signIn, throwsA(isA<AuthException>()));
      expect(h.storage.values, isEmpty);
      expect(h.requests, isEmpty);
      expect(h.routes, isEmpty);
      expect(h.client.auth.currentUser?.id, _otherOwnerId);
    },
  );

  test(
    'Facebook transport selection leaves all other providers/platforms alone',
    () {
      for (final platform in TargetPlatform.values) {
        for (final provider in [
          OAuthProvider.facebook,
          OAuthProvider.google,
          OAuthProvider.apple,
        ]) {
          expect(
            SupabaseAuthService.usesNativeFacebookOAuth(
              provider,
              isWeb: false,
              platform: platform,
            ),
            provider == OAuthProvider.facebook &&
                platform == TargetPlatform.iOS,
          );
          expect(
            SupabaseAuthService.usesNativeFacebookOAuth(
              provider,
              isWeb: true,
              platform: platform,
            ),
            isFalse,
          );
        }
      }
    },
  );
}

const _ownerId = 'a1b2c3d4-1234-4abc-8def-0123456789ab';
const _otherOwnerId = 'bbbbbbbb-1234-4abc-8def-0123456789ab';

http.Response _sessionResponse({String ownerId = _ownerId}) {
  final payload = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'sub': ownerId,
        'role': 'authenticated',
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    ),
  ).replaceAll('=', '');
  return http.Response(
    jsonEncode({
      'access_token': 'eyJhbGciOiJub25lIn0.$payload.synthetic',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'synthetic-refresh',
      'user': {
        'id': ownerId,
        'app_metadata': {'provider': 'facebook'},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'identities': [],
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

class _Harness {
  _Harness() {
    client = SupabaseClient(
      'https://tgmanzhqulksykhslrzb.supabase.co',
      'synthetic-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/logout') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (!exchangeStarted.isCompleted) exchangeStarted.complete();
        return response?.call(request) ?? _sessionResponse();
      }),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: storage,
      ),
    );
    controller = BilAuthCallbackController(
      resolve: (uri) async {
        await client.auth.getSessionFromUrl(uri);
      },
      navigate: routes.add,
      onError: (e, _) => errors.add(e),
    );
    owner = BilNativeFacebookOAuth.attachCallbackOwner(
      controller.completeNativeCallback,
    );
    nativeResult = success;
  }
  String mode = 'https';
  final storage = _MemoryStorage();
  late SupabaseClient client;
  late BilAuthCallbackController controller;
  late BilFacebookOAuthCallbackOwner owner;
  final calls = <MethodCall>[];
  final requests = <http.Request>[];
  final routes = <String>[];
  final errors = <Object>[];
  final nativeStarted = Completer<void>();
  final exchangeStarted = Completer<void>();
  Uri? authorization;
  late FutureOr<Map<String, dynamic>?> Function(Map<String, dynamic>)
  nativeResult;
  Future<http.Response> Function(http.Request)? response;
  Map<String, dynamic> success(Map<String, dynamic> a) => {
    'attemptId': a['attemptId'],
    'callbackUrl':
        '${mode == 'https' ? BilNativeFacebookOAuth.httpsCallback : BilNativeFacebookOAuth.legacyCallback}?code=synthetic-code',
  };
  Future<dynamic> native(MethodCall call) async {
    calls.add(call);
    if (call.method == 'callbackMode') return mode;
    if (call.method == 'cancel') return null;
    expect(call.method, 'authenticate');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    authorization = Uri.parse(args['url'] as String);
    if (!nativeStarted.isCompleted) nativeStarted.complete();
    return nativeResult(args);
  }
}

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
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
