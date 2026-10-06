import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:body_intelligence_log/features/community/data/community_social_repository_mixin.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_text_limits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _postId = '22222222-2222-4222-8222-222222222222';
const _commentId = '33333333-3333-4333-8333-333333333333';

String _repeat(String value, int times) => List.filled(times, value).join();

final _boundaryBodies = <String, String>{
  'ASCII': _repeat('a', 1200),
  'astral emoji': _repeat('😀', 1200),
  'joined emoji': '${_repeat('a', 1197)}👩‍💻',
  'combining accent': '${_repeat('a', 1198)}e\u0301',
  'family emoji': '${_repeat('a', 1193)}👨‍👩‍👧‍👦',
  'Arabic combining mark': '${_repeat('ب', 1198)}ب\u064E',
};

Map<String, dynamic> _commentRow(String body) => {
  'id': _commentId,
  'author_id': _owner,
  'parent_id': null,
  'body': body,
  'created_at': '2026-10-06T00:00:00Z',
  'like_count': 0,
  'liked': false,
};

final class _CommentRepository with CommunitySocialRepositoryMixin {
  _CommentRepository(this.communitySocialClient);

  @override
  final SupabaseClient communitySocialClient;

  int policyChecks = 0;

  @override
  bool get useServerThreadedCommunityComments => false;

  @override
  Future<void> requireAcceptedCommunityPolicy() async {
    policyChecks++;
  }

  @override
  Future<T> runCommunitySocialMutation<T>(Future<T> Function() mutation) =>
      mutation();
}

final class _BoundaryFixture {
  _BoundaryFixture() {
    client = SupabaseClient(
      'https://unicode-community.invalid',
      'unicode-boundary-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(_respond),
    );
    store = CommunityPostCloudStore(
      client,
      User(
        id: _owner,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-06T00:00:00Z',
      ),
    );
    comments = _CommentRepository(client);
  }

  late final SupabaseClient client;
  late final CommunityPostCloudStore store;
  late final _CommentRepository comments;
  final requests = <http.Request>[];
  final posts = <Map<String, dynamic>>[];
  final commentWrites = <Map<String, dynamic>>[];
  String? authoritativeCommentBody;

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    Object? response;
    var status = 200;
    switch ((request.method, request.url.path)) {
      case ('POST', '/rest/v1/bil_community_posts'):
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        posts.add({...payload, 'created_at': '2026-10-06T00:00:00Z'});
        response = null;
        status = 201;
      case ('GET', '/rest/v1/bil_community_posts'):
        response = posts;
      case ('GET', '/rest/v1/bil_public_profiles'):
      case ('POST', '/rest/v1/rpc/bil_community_post_media_v1'):
        response = <Object>[];
      case ('POST', '/rest/v1/rpc/bil_social_add_comment_v2'):
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        commentWrites.add(payload);
        response = _commentRow(
          authoritativeCommentBody ?? payload['p_body'] as String,
        );
      default:
        throw StateError('Unexpected boundary request: ${request.url}');
    }
    return http.Response(
      jsonEncode(response),
      status,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  for (final boundary in _boundaryBodies.entries) {
    test('${boundary.key} uses the server 1200 code point boundary', () {
      final body = boundary.value;
      final overflow = '${body}a';
      expect(CommunityTextLimits.count(body), 1200);
      expect(CommunityTextLimits.exceedsBodyLimit(body), isFalse);
      expect(CommunityTextLimits.count(overflow), 1201);
      expect(CommunityTextLimits.exceedsBodyLimit(overflow), isTrue);
      expect(overflow, startsWith(body));
    });

    test(
      '${boundary.key} post write and owner readback keep every code point',
      () async {
        final fixture = _BoundaryFixture();
        addTearDown(fixture.client.dispose);

        final postId = await fixture.store.publishTextWithReceipt(
          boundary.value,
        );
        expect(postId, isNotNull);
        expect(fixture.posts, hasLength(1));
        expect(fixture.posts.single['body'], boundary.value);
        expect(fixture.posts.single['moderation_status'], 'pending');
        final readback = await fixture.store.loadMyPostsPage();
        expect(readback.posts, hasLength(1));
        expect(readback.posts.single.id, postId);
        expect(readback.posts.single.body, boundary.value);

        final requestCount = fixture.requests.length;
        await expectLater(
          fixture.store.publishTextWithReceipt('${boundary.value}a'),
          throwsFormatException,
        );
        expect(fixture.requests, hasLength(requestCount));
        expect(fixture.posts.single['body'], boundary.value);
      },
    );

    test(
      '${boundary.key} comment RPC and typed receipt use the same boundary',
      () async {
        final fixture = _BoundaryFixture();
        addTearDown(fixture.client.dispose);

        final receipt = await fixture.comments.addPostComment(
          postId: _postId,
          body: boundary.value,
          clientId: _commentId,
        );
        expect(fixture.commentWrites, hasLength(1));
        expect(fixture.commentWrites.single['p_body'], boundary.value);
        expect(fixture.commentWrites.single['p_client_id'], _commentId);
        expect(receipt.body, boundary.value);
        expect(fixture.comments.policyChecks, 1);

        await expectLater(
          fixture.comments.addPostComment(
            postId: _postId,
            body: '${boundary.value}a',
            clientId: _commentId,
          ),
          throwsArgumentError,
        );
        expect(fixture.commentWrites, hasLength(1));
        expect(fixture.comments.policyChecks, 1);
        expect(
          () => CommunityComment.fromJson(_commentRow('${boundary.value}a')),
          throwsFormatException,
        );
      },
    );
  }

  test('count does not normalize composed accents or trim saved text', () {
    expect(CommunityTextLimits.count('é'), 1);
    expect(CommunityTextLimits.count('e\u0301'), 2);
    expect(CommunityTextLimits.count(' 👩‍💻 '), 5);
    expect(CommunityTextLimits.count('😀'), 1);
    expect('😀'.length, 2, reason: 'Flutter selection offsets remain UTF-16.');
  });

  test(
    'oversized server rows are rejected rather than silently shortened',
    () async {
      final fixture = _BoundaryFixture();
      addTearDown(fixture.client.dispose);
      final valid = _boundaryBodies['joined emoji']!;
      fixture.posts.addAll([
        {
          'id': _postId,
          'author_id': _owner,
          'body': valid,
          'created_at': '2026-10-06T00:00:00Z',
          'moderation_status': 'approved',
        },
        {
          'id': _commentId,
          'author_id': _owner,
          'body': '${valid}a',
          'created_at': '2026-10-06T00:00:00Z',
          'moderation_status': 'approved',
        },
      ]);

      final feed = await fixture.store.loadFeed();
      expect(feed, hasLength(1));
      expect(feed.single.id, _postId);
      expect(feed.single.body, valid);
      expect(fixture.posts.last['body'], '${valid}a');
    },
  );

  test(
    'comment receipt comes from server readback instead of input echo',
    () async {
      final fixture = _BoundaryFixture();
      addTearDown(fixture.client.dispose);
      fixture.authoritativeCommentBody = 'Authoritative saved comment 🌱';

      final receipt = await fixture.comments.addPostComment(
        postId: _postId,
        body: 'Submitted comment 😀',
        clientId: _commentId,
      );

      expect(fixture.commentWrites.single['p_body'], 'Submitted comment 😀');
      expect(receipt.body, 'Authoritative saved comment 🌱');
    },
  );
}
