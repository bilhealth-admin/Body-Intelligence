import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _draftId = '33333333-3333-4333-8333-333333333333';
const _body = 'Private text entered in the original A session';

Map<String, dynamic> _session(String owner, {bool expired = false}) {
  final expiry = expired ? 1600000000 : 4102444800;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))
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
      'created_at': '2026-10-06T00:00:00Z',
    },
  };
}

String _requestOwner(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  final payload =
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;
  return payload['sub'] as String;
}

enum _Transition {
  switchToB,
  roundTrip,
  sameOwnerRefresh,
  closeEditor,
  closeEditorDuringRefreshRetry,
}

void main() {
  test(
    'production Supabase initialization installs the owner transport fence',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final initializations = RegExp(
        r'Supabase\.initialize\(',
      ).allMatches(main);
      expect(initializations, hasLength(1));
      final start = initializations.single.start;
      final initialization = main.substring(
        start,
        main.indexOf(');', start) + 2,
      );
      expect(
        initialization,
        matches(
          r'httpClient\s*:\s*CommunityOwnerHttpClient\(\s*http\.Client\(\)\s*\)',
        ),
      );
    },
  );

  test(
    'unscoped HTTP requests retain the ordinary application transport',
    () async {
      final requests = <http.Request>[];
      final client = CommunityOwnerHttpClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response('Unchanged', 200, request: request);
        }),
      );
      addTearDown(client.close);
      final response = await client.get(
        Uri.parse('https://unscoped.invalid/rest/v1/ordinary-data'),
      );
      expect(response.body, 'Unchanged');
      expect(requests, hasLength(1));
    },
  );

  for (final transition in _Transition.values) {
    test(
      'pending SDK refresh fences data transport for ${transition.name}',
      () async {
        final refreshEntered = Completer<void>();
        final releaseRefresh = Completer<void>();
        final deliveredB = Completer<void>();
        final returnedA = Completer<void>();
        final delivered = <({String? eventOwner, String? currentOwner})>[];
        final writes = <({String owner, String body})>[];
        final rpcNames = <String>[];
        var refreshCalls = 0;
        var editorCurrent = true;
        final allowed = transition == _Transition.sameOwnerRefresh;
        late final SupabaseClient client;
        client = SupabaseClient(
          'https://owner-refresh.invalid',
          'synthetic-refresh-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: CommunityOwnerHttpClient(
            MockClient((request) async {
              final path = request.url.path;
              Object? response;
              var status = 200;
              if (path == '/auth/v1/token') {
                expect(
                  request.url.queryParameters['grant_type'],
                  'refresh_token',
                );
                expect(
                  jsonDecode(request.body)['refresh_token'],
                  'synthetic-refresh-$_ownerA',
                );
                refreshCalls++;
                if (refreshCalls == 1) {
                  refreshEntered.complete();
                  await releaseRefresh.future;
                }
                if (transition == _Transition.closeEditorDuringRefreshRetry &&
                    refreshCalls == 1) {
                  status = 503;
                  response = {'message': 'Synthetic retryable refresh failure'};
                } else {
                  response = _session(_ownerA);
                }
              } else if (path.startsWith('/rest/v1/rpc/')) {
                final rpc = path.split('/').last;
                rpcNames.add(rpc);
                switch (rpc) {
                  case 'bil_assert_community_publish_ready':
                    expect(_requestOwner(request), _ownerA);
                    // Model expiry after readiness using public cached-session
                    // restoration. No SDK mutation or wall-clock sleep is needed.
                    await client.auth.setInitialSession(
                      jsonEncode(_session(_ownerA, expired: true)),
                    );
                    response = null;
                  case 'bil_upsert_my_community_post_draft_v1':
                    final payload =
                        jsonDecode(request.body) as Map<String, dynamic>;
                    writes.add((
                      owner: _requestOwner(request),
                      body: payload['p_body'] as String,
                    ));
                    response = payload['p_draft_id'];
                  case 'bil_set_my_community_post_draft_media_v1':
                    expect(_requestOwner(request), _ownerA);
                    response = <String>[];
                  default:
                    throw StateError('Unexpected RPC after owner switch: $rpc');
                }
              } else {
                throw StateError('Unexpected refresh fixture request: $path');
              }
              return http.Response(
                jsonEncode(response),
                status,
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
        final observer = client.auth.onAuthStateChange.listen((state) {
          final owner = state.session?.user.id;
          delivered.add((
            eventOwner: owner,
            currentOwner: client.auth.currentUser?.id,
          ));
          if (owner == _ownerB && !deliveredB.isCompleted) {
            deliveredB.complete();
          } else if (owner == _ownerA &&
              deliveredB.isCompleted &&
              !returnedA.isCompleted) {
            returnedA.complete();
          }
        });
        addTearDown(observer.cancel);
        final repository = CommunityRepository(client);
        final outcome = expectLater(
          repository.runForCommunityOwner(
            () => repository.saveMyCommunityDraft(
              input: const CommunityDraftSaveInput(
                draftId: _draftId,
                body: _body,
              ),
              images: const [],
            ),
            ownerId: _ownerA,
            isCurrentOwner: () => editorCurrent,
          ),
          allowed
              ? completion(_draftId)
              : throwsA(isA<CommunityOwnerOperationCancelled>()),
        );

        await refreshEntered.future.timeout(const Duration(seconds: 10));
        expect(rpcNames, ['bil_assert_community_publish_ready']);
        expect(writes, isEmpty);
        switch (transition) {
          case _Transition.switchToB:
            await client.auth.recoverSession(jsonEncode(_session(_ownerB)));
            await deliveredB.future.timeout(const Duration(seconds: 10));
          case _Transition.roundTrip:
            final second = client.auth.recoverSession(
              jsonEncode(_session(_ownerB)),
            );
            final first = client.auth.recoverSession(
              jsonEncode(_session(_ownerA)),
            );
            await Future.wait([second, first]);
            await returnedA.future.timeout(const Duration(seconds: 10));
            expect(
              delivered,
              contains((eventOwner: _ownerB, currentOwner: _ownerA)),
            );
          case _Transition.sameOwnerRefresh:
            await client.auth.recoverSession(jsonEncode(_session(_ownerA)));
          case _Transition.closeEditor:
          case _Transition.closeEditorDuringRefreshRetry:
            editorCurrent = false;
        }
        releaseRefresh.complete();
        await outcome;

        expect(
          client.auth.currentUser?.id,
          transition == _Transition.switchToB ? _ownerB : _ownerA,
        );
        expect(client.auth.currentSession!.isExpired, isFalse);
        expect(
          delivered.any((event) => event.eventOwner == null),
          isFalse,
          reason: 'Ending a Community operation must not sign the member out.',
        );
        expect(
          refreshCalls,
          transition == _Transition.closeEditorDuringRefreshRetry ? 2 : 1,
        );
        if (allowed) {
          expect(writes, [(owner: _ownerA, body: _body)]);
          expect(rpcNames, [
            'bil_assert_community_publish_ready',
            'bil_upsert_my_community_post_draft_v1',
            'bil_set_my_community_post_draft_media_v1',
          ]);
        } else {
          expect(
            writes,
            isEmpty,
            reason: 'Canceled work must stop before a body-bearing HTTP send.',
          );
          expect(rpcNames, ['bil_assert_community_publish_ready']);
        }
      },
    );
  }
}
