import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const rewardsOwnerA = '11111111-1111-4111-8111-111111111111';
const rewardsOwnerB = '22222222-2222-4222-8222-222222222222';
const rewardsBalanceRpc = 'bil_gold_balance_v1';
const rewardsHistoryRpc = 'bil_gold_history_v1';
const rewardsQuestsRpc = 'bil_list_community_quests_v1';
const rewardsClaimRpc = 'bil_claim_community_quest_v1';

/// The real SDK and repository use only this local HTTP transport. No live
/// project, credentials, provider, database or reward policy is involved.
class RewardsRpcFixture {
  final requests =
      <({String method, String owner, Map<String, dynamic> params})>[];
  final balances = <String, int>{rewardsOwnerA: 7001, rewardsOwnerB: 8002};
  final claimed = <String>{};
  String? holdMethod;
  Completer<void>? release;
  final entered = Completer<void>();
  bool historyHasMore = false;
  bool failResponse = false;
  bool goQuest = false;

  late final client = SupabaseClient(
    'https://rewards-owner-fixture.invalid',
    'synthetic-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_respond)),
  );
  late final repository = CommunityRepository(client);

  static Map<String, dynamic> session(String owner) {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
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
        'created_at': '2026-10-07T00:00:00Z',
      },
    };
  }

  Future<void> prepare() async {
    await client.auth.setInitialSession(jsonEncode(session(rewardsOwnerA)));
  }

  Future<void> recover(String owner) async {
    await client.auth.recoverSession(jsonEncode(session(owner)));
  }

  Future<void> roundTrip() async {
    final second = recover(rewardsOwnerB);
    final first = recover(rewardsOwnerA);
    await Future.wait([second, first]);
  }

  int count(String method) =>
      requests.where((row) => row.method == method).length;

  Future<http.Response> _respond(http.Request request) async {
    if (request.url.path == '/auth/v1/logout') {
      return http.Response('{}', 200, request: request);
    }
    if (!request.url.path.startsWith('/rest/v1/rpc/')) {
      throw StateError('Unexpected local request: ${request.url}');
    }
    final token = request.headers['authorization']!.split(' ').last;
    final claims =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map<String, dynamic>;
    final owner = claims['sub'] as String;
    final method = request.url.pathSegments.last;
    final decoded = jsonDecode(request.body);
    final params = decoded == null
        ? <String, dynamic>{}
        : decoded as Map<String, dynamic>;
    requests.add((method: method, owner: owner, params: params));
    final Object response;
    switch (method) {
      case rewardsBalanceRpc:
        response = {'balance': balances[owner]};
      case rewardsQuestsRpc:
        response = [
          {
            'quest_key': 'qa_profile_quest',
            'cadence': 'one_time',
            'title_copy_key': 'quest_complete_profile_title',
            'subtitle_copy_key': 'quest_complete_profile_subtitle',
            'action_kind': goQuest ? 'create_post' : 'complete_profile',
            'target_count': 1,
            'claim_mode': 'manual',
            'gold_reward': 25,
            'xp_reward': 10,
            'period_key': 'once',
            'progress': goQuest ? 0 : 1,
            'state': goQuest
                ? 'go'
                : (claimed.contains(owner) ? 'claimed' : 'ready_to_claim'),
          },
        ];
      case rewardsHistoryRpc:
        final older = params['p_before_id'] != null;
        response = [
          if (historyHasMore)
            for (var i = 0; i < (older ? 1 : 30); i++)
              {
                'id': older ? 1 : 100 - i,
                'delta': 1,
                'balance_after': balances[owner],
                'source_kind': 'quest',
                'copy_key': 'quest_complete_profile_title',
                'created_at': DateTime.utc(2026, 10, 7)
                    .subtract(Duration(minutes: i + (older ? 100 : 0)))
                    .toIso8601String(),
              },
        ];
      case rewardsClaimRpc:
        final duplicate = !claimed.add(owner);
        if (!duplicate) balances[owner] = balances[owner]! + 25;
        response = {
          'status': 'claimed',
          'duplicate': duplicate,
          'gold': 25,
          'xp': 10,
        };
      default:
        throw StateError('Unexpected local RPC: $method');
    }
    if (holdMethod == method) {
      holdMethod = null;
      if (!entered.isCompleted) entered.complete();
      await release!.future;
    }
    return http.Response(
      jsonEncode(
        failResponse ? {'message': 'Synthetic failed readback'} : response,
      ),
      failResponse ? 503 : 200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
