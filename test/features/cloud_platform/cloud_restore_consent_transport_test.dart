import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

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
    'refresh_token': 'synthetic-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-12T00:00:00Z',
    },
  };
}

void main() {
  for (final switchAccount in [false, true]) {
    test(
      'scoped consent SDK token refresh ${switchAccount ? 'rejects A B A' : 'retains same owner'}',
      () async {
        final refreshEntered = Completer<void>();
        final releaseRefresh = Completer<void>();
        final returnedA = Completer<void>();
        final writes = <http.Request>[];
        late SupabaseClient client;
        client = SupabaseClient(
          'https://cloud-restore-consent.invalid',
          'synthetic-publishable-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: CommunityOwnerHttpClient(
            MockClient((request) async {
              Object? body;
              if (request.url.path == '/auth/v1/token') {
                refreshEntered.complete();
                await releaseRefresh.future;
                body = _session(_ownerA);
              } else if (request.url.path ==
                  '/rest/v1/rpc/bil_cloud_restore_capabilities_v2') {
                body = {
                  'protocol_version': 2,
                  'scopes': ['nutrition', 'goals'],
                  'consent_policy_version': '1',
                };
              } else if (request.url.path == '/rest/v1/bil_consent_receipts') {
                // Expire the public SDK session immediately before the write, so
                // its token resolution must cross a real asynchronous refresh.
                await client.auth.setInitialSession(
                  jsonEncode(_session(_ownerA, expired: true)),
                );
                body = [
                  {
                    'granted': true,
                    'policy_version': '1',
                    'recorded_at': '2026-10-12T12:00:00Z',
                  },
                ];
              } else if (request.url.path ==
                  '/rest/v1/rpc/bil_record_cloud_restore_consent_v2') {
                writes.add(request);
                expect(jsonDecode(request.body), {
                  'p_scope': 'nutrition',
                  'p_granted': true,
                  'p_policy_version': '1',
                });
                body = {
                  'scope': 'nutrition',
                  'granted': true,
                  'policy_version': '1',
                  'recorded_at': '2026-10-12T12:00:00Z',
                };
              } else {
                throw StateError('Unexpected fixture path ${request.url.path}');
              }
              return http.Response(
                jsonEncode(body),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );
        addTearDown(client.dispose);
        addTearDown(() {
          if (!releaseRefresh.isCompleted) releaseRefresh.complete();
        });
        await client.auth.recoverSession(jsonEncode(_session(_ownerA)));
        var deliveredB = false;
        final observer = client.auth.onAuthStateChange.listen((event) {
          if (event.session?.user.id == _ownerB) deliveredB = true;
          if (event.session?.user.id == _ownerA &&
              deliveredB &&
              !returnedA.isCompleted) {
            returnedA.complete();
          }
        });
        addTearDown(observer.cancel);
        final repository = CloudRestoreConsentRepository(client: client);
        addTearDown(repository.dispose);
        final result = expectLater(
          repository.setGranted(CloudRestoreScope.nutrition, true),
          switchAccount
              ? throwsA(anyOf(isA<StateError>(), isA<AuthException>()))
              : completes,
        );
        await refreshEntered.future.timeout(const Duration(seconds: 10));
        expect(writes, isEmpty);
        if (switchAccount) {
          await Future.wait([
            client.auth.recoverSession(jsonEncode(_session(_ownerB))),
            client.auth.recoverSession(jsonEncode(_session(_ownerA))),
          ]);
          await returnedA.future.timeout(const Duration(seconds: 10));
        } else {
          await client.auth.recoverSession(jsonEncode(_session(_ownerA)));
        }
        releaseRefresh.complete();
        await result;
        expect(writes, hasLength(switchAccount ? 0 : 1));
      },
    );
  }
}
