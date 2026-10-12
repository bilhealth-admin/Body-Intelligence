import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/community_rewards_rpc_fixture.dart';

void main() {
  const postId = '33333333-3333-4333-8333-333333333333';
  final revision = 'a' * 64;
  final changedRevision = 'b' * 64;
  final queued = CommunityPost(
    id: postId,
    authorId: rewardsOwnerB,
    body: 'Earlier queue text',
    createdAt: DateTime.utc(2026, 10, 1),
  );
  late SupabaseClient client;
  late CommunityRepository repository;
  late List<({String method, Map<String, dynamic> body})> sent;
  var snapshots = 0, missing = false, changed = false, forged = false;
  Completer<void>? release, entered;
  Map<String, dynamic> row() => {
    'post': {
      'id': postId,
      'author_id': rewardsOwnerB,
      'body': 'Actual reviewed text',
      'created_at': '2026-10-01T00:00:00Z',
      'moderation_status': 'pending',
      'moderation_visibility': 'visible',
    },
    'revision': changed && snapshots > 1 ? changedRevision : revision,
    'can_publish_only': false,
  };
  setUp(() async {
    sent = [];
    snapshots = 0;
    missing = changed = forged = false;
    release = entered = null;
    client = SupabaseClient(
      'https://community-review.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          final method = request.url.pathSegments.last;
          final decoded = jsonDecode(request.body);
          final body = decoded == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(decoded);
          sent.add((method: method, body: body));
          Object data;
          switch (method) {
            case 'bil_community_review_snapshots_v2':
              if (missing) {
                return http.Response(
                  jsonEncode({
                    'code': 'PGRST202',
                    'message': 'Function unavailable',
                  }),
                  404,
                  request: request,
                );
              }
              snapshots++;
              data = [row()];
            case 'bil_community_post_media_v1':
              entered?.complete();
              await release?.future;
              data = [];
            case 'bil_community_moderation_polls_v1':
              data = [];
            case 'bil_moderate_community_post_v2':
              data = {
                'post_id': postId,
                'owner_id': forged ? rewardsOwnerA : rewardsOwnerB,
                'contract_version': 2,
                'reviewed_revision': revision,
                'decision': body['p_decision'],
                'duplicate': false,
                'tokens_granted': 5,
              };
            case 'bil_request_community_post_reward_v2':
              data = {
                'post_id': postId,
                'owner_id': rewardsOwnerB,
                'status': 'requested',
                'tokens_granted': forged ? 5 : 0,
              };
            case 'bil_get_my_post_review_v2':
              entered?.complete();
              await release?.future;
              data = {
                'contract_version': 2,
                'post_id': postId,
                'owner_id': forged ? rewardsOwnerB : rewardsOwnerA,
                'decision': 'rejected',
                'reason': 'Please clarify your source',
                'reviewed_revision': revision,
                'decided_at': '2026-10-11T00:00:00Z',
                'post_body': changed
                    ? 'Changed content'
                    : 'Owned rejected text',
                'post_created_at': '2026-10-01T00:00:00Z',
              };
            default:
              throw StateError('Unexpected local RPC $method');
          }
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    repository = CommunityRepository(client);
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
  });
  tearDown(() async {
    if (release != null && !release!.isCompleted) release!.complete();
    await client.dispose();
  });
  test(
    'displayed text and revision come from the snapshot with a second hydration check',
    () async {
      final result = await repository.loadReviewedPosts([queued]);
      expect(result.single.post.body, 'Actual reviewed text');
      expect(result.single.revision, revision);
      expect(snapshots, 2);
      expect(
        sent.map((x) => x.method),
        contains('bil_community_post_media_v1'),
      );
    },
  );
  test(
    'content changed during media loading discards the reviewed result',
    () async {
      changed = true;
      await expectLater(
        repository.loadReviewedPosts([queued]),
        throwsA(isA<StateErrorReviewChanged>()),
      );
    },
  );
  test(
    'missing V2 is an explicit unavailable error with no old moderation fallback',
    () async {
      missing = true;
      await expectLater(
        repository.loadReviewedPosts([queued]),
        throwsA(isA<PostgrestException>()),
      );
      expect(sent.map((r) => r.method), ['bil_community_review_snapshots_v2']);
    },
  );
  test(
    'review decision binds post owner revision and stable idempotency without client amount',
    () async {
      final snapshot = (await repository.loadReviewedPosts([queued])).single;
      const key = '44444444-4444-4444-8444-444444444444';
      await repository.moderateReviewedPost(
        snapshot: snapshot,
        decision: CommunityPostModerationDecision.approved,
        operationId: key,
      );
      final body = sent.last.body;
      expect(body, {
        'p_post_id': postId,
        'p_expected_revision': revision,
        'p_decision': 'approved',
        'p_operation_id': key,
        'p_reason': '',
        'p_reward_mode': 'eligible',
      });
      forged = true;
      await expectLater(
        repository.moderateReviewedPost(
          snapshot: snapshot,
          decision: CommunityPostModerationDecision.approved,
          operationId: key,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'request is not a grant and an unconfirmed amount cannot be presented as credit',
    () async {
      final snapshot = (await repository.loadReviewedPosts([queued])).single;
      expect(await repository.requestReviewedReward(snapshot), 'requested');
      forged = true;
      await expectLater(
        repository.requestReviewedReward(snapshot),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.moderateReviewedPost(
          snapshot: snapshot,
          decision: CommunityPostModerationDecision.approved,
          operationId: '44444444-4444-4444-8444-444444444444',
          publishOnly: true,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
  test(
    'ABA during hydration retires the operation before a second data request',
    () async {
      entered = Completer<void>();
      release = Completer<void>();
      final pending = repository.loadReviewedPosts([queued]);
      final assertion = expectLater(
        pending,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      await entered!.future;
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
      );
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
      );
      release!.complete();
      await assertion;
      expect(snapshots, 1);
    },
  );
  final ownRejected = CommunityPost(
    id: postId,
    authorId: rewardsOwnerA,
    body: 'Owned rejected text',
    createdAt: DateTime.utc(2026, 10, 1),
    moderationStatus: CommunityPostModerationStatus.rejected,
  );
  test('author-only reason validates identity and displayed content', () async {
    expect(
      await repository.loadMyPostReviewReason(ownRejected),
      'Please clarify your source',
    );
    forged = true;
    await expectLater(
      repository.loadMyPostReviewReason(ownRejected),
      throwsA(isA<FormatException>()),
    );
    forged = false;
    changed = true;
    expect(await repository.loadMyPostReviewReason(ownRejected), isNull);
  });
  test(
    'author reason response is retired after ABA and never reveals a late explanation',
    () async {
      entered = Completer<void>();
      release = Completer<void>();
      final result = repository.loadMyPostReviewReason(ownRejected);
      final assertion = expectLater(
        result,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      await entered!.future;
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
      );
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
      );
      release!.complete();
      await assertion;
      expect(sent.single.method, 'bil_get_my_post_review_v2');
    },
  );
}
