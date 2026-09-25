import 'package:body_intelligence_log/features/auth/native_facebook_sign_in.dart';
import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _jwt = 'header.payload.signature';
const _nonce = 'facebook-test-nonce';

ClassicToken _classic({String? authenticationToken, String? opaqueToken}) =>
    ClassicToken(
      declinedPermissions: const <String>[],
      grantedPermissions: const <String>['email', 'public_profile', 'openid'],
      userId: 'meta-user',
      expires: DateTime.utc(2030),
      tokenString: opaqueToken ?? 'opaque-facebook-access-token',
      applicationId: '1384055070498598',
      authenticationToken: authenticationToken,
    );

LimitedToken _limited(String token) => LimitedToken(
  userId: 'meta-user',
  userName: 'Meta User',
  userEmail: 'meta@example.test',
  nonce: _nonce,
  tokenString: token,
);

User _user([String id = 'supabase-user']) => User(
  id: id,
  appMetadata: const <String, dynamic>{'provider': 'facebook'},
  userMetadata: const <String, dynamic>{},
  aud: 'authenticated',
  createdAt: '2026-09-25T00:00:00.000Z',
);

Session _session([String id = 'supabase-user']) => Session(
  accessToken: 'supabase-session-token',
  refreshToken: 'supabase-refresh-token',
  tokenType: 'bearer',
  user: _user(id),
);

final class _FakeFacebookLoginClient implements BilFacebookLoginClient {
  _FakeFacebookLoginClient(this.result);

  final LoginResult result;
  int calls = 0;
  List<String>? permissions;
  String? nonce;

  @override
  Future<LoginResult> login({
    required List<String> permissions,
    required LoginBehavior loginBehavior,
    required LoginTracking loginTracking,
    required String nonce,
  }) async {
    calls += 1;
    this.permissions = permissions;
    this.nonce = nonce;
    return result;
  }
}

final class _FakeFacebookSessionAuthority
    implements BilFacebookSessionAuthority {
  _FakeFacebookSessionAuthority({
    this.session,
    this.response,
    this.exchangeError,
  });

  final Session? session;
  final AuthResponse? response;
  final Object? exchangeError;
  int exchangeCalls = 0;
  String? exchangedIdToken;
  String? exchangedNonce;

  @override
  Session? get currentSession => session;

  @override
  String generateRawNonce() => _nonce;

  @override
  Future<AuthResponse> exchange({
    required String idToken,
    required String nonce,
  }) async {
    exchangeCalls += 1;
    exchangedIdToken = idToken;
    exchangedNonce = nonce;
    if (exchangeError case final error?) throw error;
    return response ?? AuthResponse(session: _session());
  }
}

SupabaseAuthService _service(
  _FakeFacebookSessionAuthority authority,
  _FakeFacebookLoginClient login,
) => SupabaseAuthService(
  SupabaseClient('https://example.supabase.co', 'test-publishable-key'),
  nativeFacebookSignIn: BilNativeFacebookSignIn(client: login),
  facebookSessionAuthority: authority,
);

void main() {
  test(
    'A ClassicToken exchanges only its valid OIDC authentication token',
    () async {
      final login = _FakeFacebookLoginClient(
        LoginResult(
          status: LoginStatus.success,
          accessToken: _classic(authenticationToken: _jwt),
        ),
      );
      final authority = _FakeFacebookSessionAuthority();

      final response = await _service(
        authority,
        login,
      ).signInWithFacebookNative();

      expect(response?.session, isNotNull);
      expect(authority.exchangedIdToken, _jwt);
      expect(authority.exchangedNonce, _nonce);
      expect(
        login.permissions,
        containsAll(['openid', 'email', 'public_profile']),
      );
      expect(login.nonce, _nonce);
    },
  );

  test('B opaque ClassicToken without OIDC token fails closed', () async {
    final login = _FakeFacebookLoginClient(
      LoginResult(status: LoginStatus.success, accessToken: _classic()),
    );
    final authority = _FakeFacebookSessionAuthority();

    await expectLater(
      _service(authority, login).signInWithFacebookNative(),
      throwsA(isA<AuthException>()),
    );
    expect(authority.exchangeCalls, 0);
  });

  test('C LimitedToken exchanges its valid identity JWT', () async {
    final login = _FakeFacebookLoginClient(
      LoginResult(status: LoginStatus.success, accessToken: _limited(_jwt)),
    );
    final authority = _FakeFacebookSessionAuthority();

    await _service(authority, login).signInWithFacebookNative();

    expect(authority.exchangedIdToken, _jwt);
    expect(authority.exchangedNonce, _nonce);
  });

  test('D malformed identity tokens are rejected before Supabase', () async {
    for (final malformed in ['', 'opaque', 'two.parts', 'a..c', 'a.b.c.d']) {
      final login = _FakeFacebookLoginClient(
        LoginResult(
          status: LoginStatus.success,
          accessToken: _classic(authenticationToken: malformed),
        ),
      );
      final authority = _FakeFacebookSessionAuthority();
      await expectLater(
        _service(authority, login).signInWithFacebookNative(),
        throwsA(isA<AuthException>()),
      );
      expect(authority.exchangeCalls, 0, reason: malformed);
    }
  });

  test('E Meta cancellation is clean and never mutates Supabase', () async {
    final login = _FakeFacebookLoginClient(
      LoginResult(status: LoginStatus.cancelled),
    );
    final authority = _FakeFacebookSessionAuthority();

    expect(await _service(authority, login).signInWithFacebookNative(), isNull);
    expect(authority.exchangeCalls, 0);
  });

  test('F Meta SDK failure is actionable and never falls back', () async {
    final login = _FakeFacebookLoginClient(
      LoginResult(status: LoginStatus.failed, message: 'sdk failed'),
    );
    final authority = _FakeFacebookSessionAuthority();

    await expectLater(
      _service(authority, login).signInWithFacebookNative(),
      throwsA(isA<AuthException>()),
    );
    expect(authority.exchangeCalls, 0);
  });

  test(
    'G Supabase exchange failure cannot produce an authenticated result',
    () async {
      final login = _FakeFacebookLoginClient(
        LoginResult(
          status: LoginStatus.success,
          accessToken: _classic(authenticationToken: _jwt),
        ),
      );
      final authority = _FakeFacebookSessionAuthority(
        exchangeError: const AuthException('verification failed'),
      );

      await expectLater(
        _service(authority, login).signInWithFacebookNative(),
        throwsA(isA<AuthException>()),
      );
      expect(authority.exchangeCalls, 1);
    },
  );

  test('H SDK success without a Supabase session fails closed', () async {
    final login = _FakeFacebookLoginClient(
      LoginResult(
        status: LoginStatus.success,
        accessToken: _classic(authenticationToken: _jwt),
      ),
    );
    final authority = _FakeFacebookSessionAuthority(
      response: AuthResponse(user: _user()),
    );

    await expectLater(
      _service(authority, login).signInWithFacebookNative(),
      throwsA(isA<AuthException>()),
    );
  });

  test(
    'I an existing Supabase session is handed off without another login',
    () async {
      final login = _FakeFacebookLoginClient(
        LoginResult(status: LoginStatus.failed),
      );
      final existing = _session('existing-user');
      final authority = _FakeFacebookSessionAuthority(session: existing);

      final response = await _service(
        authority,
        login,
      ).signInWithFacebookNative();

      expect(response?.session, same(existing));
      expect(login.calls, 0);
      expect(authority.exchangeCalls, 0);
    },
  );

  test(
    'J/K Android Facebook dispatches native without browser callback',
    () async {
      final login = _FakeFacebookLoginClient(
        LoginResult(
          status: LoginStatus.success,
          accessToken: _classic(authenticationToken: _jwt),
        ),
      );
      final authority = _FakeFacebookSessionAuthority();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(
          await _service(
            authority,
            login,
          ).signInWithOAuth(OAuthProvider.facebook),
          isTrue,
        );
        expect(login.calls, 1);
        expect(authority.exchangeCalls, 1);
        expect(authority.exchangedIdToken, _jwt);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
