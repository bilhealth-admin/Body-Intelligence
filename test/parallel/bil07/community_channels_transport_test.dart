import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/channels/data/supabase_community_channels_repository.dart';
import 'package:body_intelligence_log/features/community/channels/domain/community_channel_models.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Real Supabase/AuthHttpClient/owner-fence code; synthetic HTTP responses only.
// Plain test() keeps session events and request continuations out of fake time.
const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _channel = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _messageA = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _messageB = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _clientMessageId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _messageText = '  Synthetic channel message 🌱\n';
const _now = '2026-10-07T12:00:00Z';

Map<String, Object?> _session(String owner, {bool expired = false}) {
  final expiry = expired ? 1600000000 : 4102444800;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-bil07-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-01T00:00:00Z',
    },
  };
}

Map<String, Object?> _envelope({bool channel = false}) => {
  'contract_version': 1,
  'owner_id': _ownerA,
  'server_time': _now,
  if (channel) 'channel_id': _channel,
};

Map<String, Object?> _policy({bool accepted = true}) => {
  'server_now': _now,
  'status': accepted ? 'accepted' : 'acceptance_required',
  'version': 'bil07-synthetic-policy-v1',
  'document_url': 'https://policy.invalid/bil07-synthetic',
  'locale_code': 'en',
  'effective_at': '2026-01-01T00:00:00Z',
  'accepted': accepted,
  'accepted_at': accepted ? '2026-01-02T00:00:00Z' : null,
};

Map<String, Object?> _sendReceipt({bool replay = false}) => {
  ..._envelope(channel: true),
  'idempotent_replay': replay,
  'message': {
    'id': _messageA,
    'channel_id': _channel,
    'sequence': 7,
    'author_id': _ownerA,
    'author_display_name': 'Synthetic A',
    'text': _messageText,
    'client_message_id': _clientMessageId,
    'created_at': _now,
    'is_read': true,
  },
};

Map<String, Object?> _presenceReceipt() => {
  ..._envelope(channel: true),
  'ttl_seconds': 90,
  'online_count': 3,
  'valid_until': '2026-10-07T12:00:30Z',
  'expires_at': '2026-10-07T12:01:30Z',
};

const _attempt = CommunityChannelSendAttempt(
  ownerId: _ownerA,
  channelId: _channel,
  clientMessageId: _clientMessageId,
  text: _messageText,
  draftRevision: 4,
);

Map<String, dynamic> _body(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

String _requestOwner(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  final claims =
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;
  return claims['sub'] as String;
}

http.Response _json(http.Request request, Object? value, {int status = 200}) =>
    http.Response(
      jsonEncode(value),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(http.Request request, String code) => _json(request, {
  'code': code,
  'message': 'Synthetic unavailable channel contract',
  'details': null,
  'hint': null,
}, status: 404);

final class _HttpFixture {
  _HttpFixture(FutureOr<http.Response> Function(http.Request request) respond) {
    client = SupabaseClient(
      'https://bil07-channels.invalid',
      'synthetic-bil07-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          expect(request.url.host, 'bil07-channels.invalid');
          requests.add(request);
          return respond(request);
        }),
      ),
    );
    repository = SupabaseCommunityChannelsRepository(
      CommunityRepository(client),
    );
    addTearDown(client.dispose);
  }

  late final SupabaseClient client;
  late final SupabaseCommunityChannelsRepository repository;
  final requests = <http.Request>[];

  List<http.Request> get rpcRequests => requests
      .where((request) => request.url.path.startsWith('/rest/v1/rpc/'))
      .toList();

  List<String> get rpcNames =>
      rpcRequests.map((request) => request.url.path.split('/').last).toList();

  Future<void> signIn() async {
    await client.auth.recoverSession(jsonEncode(_session(_ownerA)));
  }

  ChannelRequestScope scope({bool Function()? isCurrent}) =>
      ChannelRequestScope(
        ownerId: _ownerA,
        visitGeneration: 7,
        // Keep this predicate true in the ABA test to independently exercise
        // the real owner-operation subscription below the repository.
        isCurrentVisit: isCurrent ?? () => true,
      );
}

enum _RefreshTransition { sameOwner, roundTrip, retiredVisit }

void main() {
  for (final code in ['PGRST202', '42883', '42P01']) {
    test(
      'missing channel RPC $code fails closed through actual HTTP',
      () async {
        final fixture = _HttpFixture((request) {
          expect(
            request.url.path,
            '/rest/v1/rpc/bil07_channel_capabilities_v1',
          );
          expect(request.method, 'POST');
          expect(_requestOwner(request), _ownerA);
          return _error(request, code);
        });
        await fixture.signIn();
        await expectLater(
          fixture.repository.loadCapabilities(fixture.scope()),
          throwsA(
            isA<ChannelFailure>().having(
              (error) => error.kind,
              'kind',
              ChannelFailureKind.unavailable,
            ),
          ),
        );
        expect(fixture.rpcNames, ['bil07_channel_capabilities_v1']);
      },
    );
  }

  test('write response cannot replace separate partial readback', () async {
    final fixture = _HttpFixture((request) {
      expect(_requestOwner(request), _ownerA);
      expect(_body(request), {
        'p_channel_id': _channel,
        'p_message_ids': [_messageA, _messageB],
      });
      switch (request.url.path.split('/').last) {
        case 'bil07_channel_read_v1':
          // A successful write even claiming all IDs is not read evidence.
          return _json(request, {
            ..._envelope(channel: true),
            'acknowledged_message_ids': [_messageA, _messageB],
            'unread_count': 0,
          });
        case 'bil07_channel_readback_v1':
          return _json(request, {
            ..._envelope(channel: true),
            'acknowledged_message_ids': [_messageA],
            'unread_count': 1,
          });
        default:
          throw StateError('Unexpected synthetic read RPC');
      }
    });
    await fixture.signIn();
    final readback = await fixture.repository.acknowledgeVisible(
      fixture.scope(),
      _channel,
      [_messageA, _messageB, _messageA],
    );
    expect(readback.confirmedIds, {_messageA});
    expect(readback.unreadCount, 1);
    expect(fixture.rpcNames, [
      'bil07_channel_read_v1',
      'bil07_channel_readback_v1',
    ]);
    expect(fixture.rpcNames.any((name) => name.contains('private')), isFalse);
  });

  test(
    'failed readback after a committed write cannot return success',
    () async {
      final fixture = _HttpFixture((request) {
        switch (request.url.path.split('/').last) {
          case 'bil07_channel_read_v1':
            return _json(request, 1);
          case 'bil07_channel_readback_v1':
            return _error(request, 'PGRST202');
          default:
            throw StateError('Unexpected synthetic read RPC');
        }
      });
      await fixture.signIn();
      await expectLater(
        fixture.repository.acknowledgeVisible(fixture.scope(), _channel, [
          _messageA,
        ]),
        throwsA(
          isA<ChannelFailure>().having(
            (error) => error.kind,
            'kind',
            ChannelFailureKind.unavailable,
          ),
        ),
      );
      expect(fixture.rpcNames, [
        'bil07_channel_read_v1',
        'bil07_channel_readback_v1',
      ]);
    },
  );

  test(
    'policy requiring acceptance cannot dispatch or autoaccept a send',
    () async {
      final fixture = _HttpFixture((request) {
        expect(
          request.url.path,
          '/rest/v1/rpc/bil_current_community_policy_status',
        );
        return _json(request, _policy(accepted: false));
      });
      await fixture.signIn();
      await expectLater(
        fixture.repository.send(fixture.scope(), _attempt),
        throwsA(
          isA<ChannelFailure>().having(
            (error) => error.kind,
            'kind',
            ChannelFailureKind.policyRequired,
          ),
        ),
      );
      expect(fixture.rpcNames, ['bil_current_community_policy_status']);
      expect(fixture.requests, hasLength(1));
    },
  );

  for (final transition in _RefreshTransition.values) {
    test(
      'pending SDK token refresh fences channel send for ${transition.name}',
      () async {
        final enteredRefresh = Completer<void>();
        final releaseRefresh = Completer<void>();
        final deliveredB = Completer<void>();
        final returnedA = Completer<void>();
        final events = <({String? eventOwner, String? currentOwner})>[];
        var currentVisit = true;
        var refreshCalls = 0;
        late final _HttpFixture fixture;
        fixture = _HttpFixture((request) async {
          final path = request.url.path;
          if (path == '/auth/v1/token') {
            expect(request.url.queryParameters['grant_type'], 'refresh_token');
            expect(
              _body(request)['refresh_token'],
              'synthetic-bil07-refresh-$_ownerA',
            );
            refreshCalls++;
            if (!enteredRefresh.isCompleted) enteredRefresh.complete();
            await releaseRefresh.future;
            return _json(request, _session(_ownerA));
          }
          expect(_requestOwner(request), _ownerA);
          switch (path.split('/').last) {
            case 'bil_current_community_policy_status':
              // Expire the SDK's cached session after the policy preflight, so
              // the subsequent body-bearing RPC must await token resolution.
              await fixture.client.auth.setInitialSession(
                jsonEncode(_session(_ownerA, expired: true)),
              );
              return _json(request, _policy());
            case 'bil07_channel_send_v1':
              expect(_body(request), {
                'p_channel_id': _channel,
                'p_client_message_id': _clientMessageId,
                'p_text': _messageText,
              });
              return _json(request, _sendReceipt());
            default:
              throw StateError('Unexpected synthetic send RPC: $path');
          }
        });
        addTearDown(() {
          if (!releaseRefresh.isCompleted) releaseRefresh.complete();
        });
        await fixture.signIn();
        final observer = fixture.client.auth.onAuthStateChange.listen((state) {
          final owner = state.session?.user.id;
          events.add((
            eventOwner: owner,
            currentOwner: fixture.client.auth.currentUser?.id,
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
        final outcome = expectLater(
          fixture.repository.send(
            fixture.scope(isCurrent: () => currentVisit),
            _attempt,
          ),
          transition == _RefreshTransition.sameOwner
              ? completion(
                  isA<CommunityChannelMessage>()
                      .having((message) => message.id, 'id', _messageA)
                      .having(
                        (message) => message.text,
                        'exact text',
                        _messageText,
                      )
                      .having(
                        (message) => message.clientMessageId,
                        'retry key',
                        _clientMessageId,
                      ),
                )
              : throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await enteredRefresh.future.timeout(const Duration(seconds: 10));
        expect(fixture.rpcNames, ['bil_current_community_policy_status']);
        switch (transition) {
          case _RefreshTransition.sameOwner:
            await fixture.client.auth.recoverSession(
              jsonEncode(_session(_ownerA)),
            );
          case _RefreshTransition.roundTrip:
            final second = fixture.client.auth.recoverSession(
              jsonEncode(_session(_ownerB)),
            );
            final first = fixture.client.auth.recoverSession(
              jsonEncode(_session(_ownerA)),
            );
            await Future.wait([second, first]);
            await returnedA.future.timeout(const Duration(seconds: 10));
            expect(
              events,
              contains((eventOwner: _ownerB, currentOwner: _ownerA)),
            );
            expect(currentVisit, isTrue);
          case _RefreshTransition.retiredVisit:
            currentVisit = false;
        }
        releaseRefresh.complete();
        await outcome;
        expect(refreshCalls, 1);
        expect(fixture.client.auth.currentUser?.id, _ownerA);
        expect(fixture.client.auth.currentSession!.isExpired, isFalse);
        expect(events.any((event) => event.eventOwner == null), isFalse);
        expect(fixture.rpcNames, [
          'bil_current_community_policy_status',
          if (transition == _RefreshTransition.sameOwner)
            'bil07_channel_send_v1',
        ]);
      },
    );
  }

  for (final backgroundDuringRefresh in [false, true]) {
    test(
      'presence HTTP refresh preserves foreground fence: background=$backgroundDuringRefresh',
      () async {
        final enteredRefresh = Completer<void>();
        final releaseRefresh = Completer<void>();
        var foreground = true;
        var refreshCalls = 0;
        final fixture = _HttpFixture((request) async {
          if (request.url.path == '/auth/v1/token') {
            refreshCalls++;
            if (!enteredRefresh.isCompleted) enteredRefresh.complete();
            await releaseRefresh.future;
            return _json(request, _session(_ownerA));
          }
          expect(request.url.path, '/rest/v1/rpc/bil07_channel_presence_v1');
          expect(_requestOwner(request), _ownerA);
          expect(_body(request), {
            'p_channel_id': _channel,
            'p_heartbeat': true,
          });
          return _json(request, _presenceReceipt());
        });
        addTearDown(() {
          if (!releaseRefresh.isCompleted) releaseRefresh.complete();
        });
        await fixture.signIn();
        await fixture.client.auth.setInitialSession(
          jsonEncode(_session(_ownerA, expired: true)),
        );
        final outcome = expectLater(
          fixture.repository.loadPresence(
            fixture.scope(),
            _channel,
            heartbeat: true,
            isForeground: () => foreground,
          ),
          backgroundDuringRefresh
              ? throwsA(isA<CommunityOwnerOperationCancelled>())
              : completion(
                  isA<CommunityChannelPresence>().having(
                    (value) => value.onlineCount,
                    'online count',
                    3,
                  ),
                ),
        );
        await enteredRefresh.future.timeout(const Duration(seconds: 10));
        expect(fixture.rpcNames, isEmpty);
        if (backgroundDuringRefresh) foreground = false;
        releaseRefresh.complete();
        await outcome;
        expect(refreshCalls, 1);
        expect(fixture.client.auth.currentUser?.id, _ownerA);
        expect(fixture.client.auth.currentSession!.isExpired, isFalse);
        expect(
          fixture.rpcNames,
          backgroundDuringRefresh ? isEmpty : ['bil07_channel_presence_v1'],
        );
      },
    );
  }
}
