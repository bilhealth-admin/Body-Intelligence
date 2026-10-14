import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/remote_ai_consent_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Negative owner-boundary fixture. Actual Auth SDK with synthetic HTTP only.
const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

Map<String, Object?> _session(String owner, {bool expired = false}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': owner, 'exp': expired ? 1600000000 : 4102444800}),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-consent-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-13T00:00:00Z',
    },
  };
}

class _ConsentSdkBoundary {
  _ConsentSdkBoundary() {
    client = SupabaseClient(
      'https://consent-owner.invalid',
      'synthetic-consent-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_request)),
    );
  }
  late final SupabaseClient client;
  late final RemoteAiConsentCoordinator consent;
  StreamSubscription<AuthState>? observer;
  final events = <({String? delivered, String? current})>[];
  final reads = <String>[];
  final writes = <({String owner, bool granted})>[];
  final allowed = <String, bool>{_a: false, _b: false};
  final readEntered = Completer<void>();
  final refreshEntered = Completer<void>();
  final returnedA = Completer<void>();
  Completer<void>? readGate, refreshGate;
  int refreshes = 0;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    await client.auth.recoverSession(jsonEncode(_session(_a)));
    observer = client.auth.onAuthStateChange.listen((state) {
      final delivered = state.session?.user.id;
      events.add((delivered: delivered, current: client.auth.currentUser?.id));
      if (delivered == _a &&
          events.any((e) => e.delivered == _b) &&
          !returnedA.isCompleted) {
        returnedA.complete();
      }
    });
    consent = sharedRemoteAiConsentCoordinator(client);
  }

  Future<void> roundTrip() async {
    final toB = client.auth.recoverSession(jsonEncode(_session(_b)));
    final toA = client.auth.recoverSession(jsonEncode(_session(_a)));
    await Future.wait([toB, toA]);
    await returnedA.future.timeout(const Duration(seconds: 10));
    expect(events, contains((delivered: _b, current: _a)));
  }

  Future<void> switchOwner() async {
    await client.auth.recoverSession(jsonEncode(_session(_b)));
    await Future<void>.delayed(Duration.zero);
    expect(client.auth.currentUser?.id, _b);
  }

  String _requestOwner(http.Request request) {
    final token = request.headers['authorization']!.split(' ').last;
    final claim =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map;
    return claim['sub'] as String;
  }

  Future<http.Response> _request(http.Request request) async {
    Object? result;
    final path = request.url.path;
    if (path == '/auth/v1/token') {
      expect(request.url.queryParameters['grant_type'], 'refresh_token');
      refreshes++;
      if (!refreshEntered.isCompleted) refreshEntered.complete();
      await refreshGate?.future;
      result = _session(_a);
    } else if (path == '/rest/v1/rpc/bil_get_remote_ai_consent') {
      final owner = _requestOwner(request);
      final snapshot = allowed[owner] ?? false;
      reads.add(owner);
      if (!readEntered.isCompleted) readEntered.complete();
      await readGate?.future;
      result = {'granted': snapshot, 'policy_version': '3'};
    } else if (path == '/rest/v1/rpc/bil_record_consent') {
      final owner = _requestOwner(request);
      final params = jsonDecode(request.body) as Map;
      expect(params['p_purpose'], 'remote_ai');
      expect(params['p_policy_version'], '3');
      final granted = params['p_granted'] as bool;
      writes.add((owner: owner, granted: granted));
      allowed[owner] = granted;
      result = null;
    } else {
      throw StateError(
        'Unexpected synthetic consent path: ${request.method} $path',
      );
    }
    return http.Response(
      jsonEncode(result),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> dispose() async {
    for (final gate in [readGate, refreshGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await observer?.cancel();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'shared consent actual SDK cached positive A B A requires fresh authority',
    () async {
      final sdk = _ConsentSdkBoundary();
      try {
        await sdk.initialize();
        sdk.allowed[_a] = true;
        expect(await sdk.consent.isGranted(), isTrue);
        expect(sdk.reads, [_a]);
        await sdk.roundTrip();
        sdk.allowed[_a] = false;
        expect(await sdk.consent.isGranted(), isFalse);
        expect(sdk.reads, [_a, _a]);
        expect(sdk.writes, isEmpty);
      } finally {
        await sdk.dispose();
      }
    },
  );
  test(
    'shared consent actual SDK pending positive read A B A cannot restore cache',
    () async {
      final sdk = _ConsentSdkBoundary();
      try {
        await sdk.initialize();
        sdk.allowed[_a] = true;
        sdk.readGate = Completer<void>();
        final pending = sdk.consent.isGranted();
        await sdk.readEntered.future.timeout(const Duration(seconds: 10));
        await sdk.roundTrip();
        sdk.readGate!.complete();
        // Capture an explicit cancellation separately; do not label an SDK error
        // or fixture crash a privacy regression.
        final outcome = await pending.then<Object?>(
          (value) => value,
          onError: (Object error) => error,
        );
        expect(
          outcome,
          anyOf(isFalse, isA<CommunityOwnerOperationCancelled>()),
        );
        expect(sdk.writes, isEmpty);
        sdk.allowed[_a] = false;
        expect(await sdk.consent.isGranted(forceServerRead: true), isFalse);
      } finally {
        await sdk.dispose();
      }
    },
  );
  for (final action in ['read', 'grant', 'revoke']) {
    for (final aba in [false, true]) {
      test(
        'shared consent actual SDK $action refresh ${aba ? 'A B A' : 'A B'} retires before data send',
        () async {
          final sdk = _ConsentSdkBoundary();
          try {
            await sdk.initialize();
            sdk.refreshGate = Completer<void>();
            await sdk.client.auth.setInitialSession(
              jsonEncode(_session(_a, expired: true)),
            );
            final pending = switch (action) {
              'read' => sdk.consent.isGranted(forceServerRead: true),
              'grant' => sdk.consent.grantAndVerify(),
              _ => sdk.consent.revokeAndVerify(),
            };
            final settled = pending.then<Object?>(
              (value) => value,
              onError: (Object error) => error,
            );
            await sdk.refreshEntered.future.timeout(
              const Duration(seconds: 10),
            );
            if (aba) {
              await sdk.roundTrip();
            } else {
              await sdk.switchOwner();
            }
            sdk.refreshGate!.complete();
            final result = await settled;
            expect(
              result,
              anyOf(isFalse, isA<CommunityOwnerOperationCancelled>()),
            );
            expect(
              sdk.reads,
              isEmpty,
              reason:
                  'No data read may enter HTTP after the captured visit retired.',
            );
            expect(
              sdk.writes,
              isEmpty,
              reason:
                  'Neither Allow nor withdrawal may mutate another retired session.',
            );
            expect(sdk.refreshes, 1);
          } finally {
            await sdk.dispose();
          }
        },
      );
    }
  }
}
