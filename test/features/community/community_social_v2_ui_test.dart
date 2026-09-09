import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _policy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

final class _SocialV2Repository extends CommunityRepository {
  _SocialV2Repository()
    : super(
        SupabaseClient(
          'https://social-v2.invalid',
          'social-v2-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const currentId = '11111111-1111-4111-8111-111111111111';
  static const authorId = '22222222-2222-4222-8222-222222222222';
  static const postId = '33333333-3333-4333-8333-333333333333';
  static const rootId = '44444444-4444-4444-8444-444444444444';
  static const replyId = '55555555-5555-4555-8555-555555555555';

  bool saved = false;
  bool postLiked = false;
  int postLikeCount = 2;
  int commentCount = 2;
  int addFailuresRemaining = 0;
  int savedMutations = 0;
  int postLikeMutations = 0;
  int commentLikeMutations = 0;
  int commentReports = 0;
  int blocks = 0;
  int friendRequests = 0;
  final List<String> submittedClientIds = [];
  final List<String?> submittedParentIds = [];
  final List<CommunityComment> added = [];

  CommunityPost get post => CommunityPost(
    id: postId,
    authorId: authorId,
    authorName: 'BIL Training Partner',
    body: 'A real Community Social v2 post',
    createdAt: DateTime.utc(2026, 9, 8, 9),
    likeCount: postLikeCount,
    liked: postLiked,
    commentCount: commentCount,
    saved: saved,
    authorHandle: 'training_partner',
    authorRelationship: CommunityRelationshipStatus.none,
    authorCanRequest: true,
  );

  CommunityPostStats get stats => CommunityPostStats(
    postId: postId,
    likeCount: postLikeCount,
    liked: postLiked,
    commentCount: commentCount,
  );

  List<CommunityComment> get comments => [
    CommunityComment(
      id: rootId,
      authorId: authorId,
      body: 'Root comment can be selected',
      createdAt: DateTime.utc(2026, 9, 8, 10),
      likeCount: 1,
      liked: false,
      authorName: 'BIL Training Partner',
      authorHandle: 'training_partner',
    ),
    CommunityComment(
      id: replyId,
      authorId: currentId,
      parentId: rootId,
      body: 'One-level reply',
      createdAt: DateTime.utc(2026, 9, 8, 10, 1),
      likeCount: 0,
      liked: false,
      authorName: 'BIL Tester',
      authorHandle: 'bil_tester',
    ),
    ...added,
  ];

  @override
  String get currentUserId => currentId;

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async =>
      CommunityPolicyState.accepted(_policy, acceptedVersion: _policy.version);

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [post];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => [];

  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds) async =>
      [stats];

  @override
  Future<CommunityPostStats> setPostLiked(
    String targetPostId, {
    required bool liked,
  }) async {
    expect(targetPostId, postId);
    postLikeMutations++;
    postLiked = liked;
    postLikeCount += liked ? 1 : -1;
    return stats;
  }

  @override
  Future<CommunitySavedState> setPostSaved(
    String targetPostId, {
    required bool saved,
  }) async {
    expect(targetPostId, postId);
    savedMutations++;
    this.saved = saved;
    return CommunitySavedState(postId: postId, saved: saved);
  }

  @override
  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => CommunitySavedPostBatch(
    posts: saved ? [post.withSaved(true)] : const [],
    hasMore: false,
  );

  @override
  Future<List<CommunityComment>> loadPostComments(
    String targetPostId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async {
    expect(targetPostId, postId);
    return after == null ? comments : const [];
  }

  @override
  Future<CommunityComment> addPostComment({
    required String postId,
    required String body,
    required String clientId,
    String? parentId,
  }) async {
    submittedClientIds.add(clientId);
    submittedParentIds.add(parentId);
    if (addFailuresRemaining > 0) {
      addFailuresRemaining--;
      throw StateError('injected retryable failure');
    }
    final comment = CommunityComment(
      id: clientId,
      authorId: currentId,
      parentId: parentId,
      body: body,
      createdAt: DateTime.utc(2026, 9, 8, 11, added.length),
      likeCount: 0,
      liked: false,
      authorName: 'BIL Tester',
      authorHandle: 'bil_tester',
    );
    added.add(comment);
    commentCount++;
    return comment;
  }

  @override
  Future<CommunityComment> setCommentLiked(
    CommunityComment comment, {
    required bool liked,
  }) async {
    commentLikeMutations++;
    return comment.copyWith(
      liked: liked,
      likeCount: comment.likeCount + (liked ? 1 : -1),
    );
  }

  @override
  Future<void> reportComment(String commentId, {required String reason}) async {
    commentReports++;
  }

  @override
  Future<void> blockMember(String userId) async {
    expect(userId, authorId);
    blocks++;
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String addresseeId) async {
    expect(addresseeId, authorId);
    friendRequests++;
    return CommunityFriendRequestStatus.pending;
  }
}

Widget _app(CommunityRepository repository) => MaterialApp(
  locale: const Locale('en'),
  home: CommunityHubPage(repository: repository),
);

void main() {
  testWidgets('save action is authoritative and saved collection is private', (
    tester,
  ) async {
    final repository = _SocialV2Repository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('@training_partner'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('community-post-add-friend-${_SocialV2Repository.postId}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.friendRequests, 1);
    expect(find.text('Request pending'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('community-post-save-${_SocialV2Repository.postId}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.saved, isTrue);
    expect(repository.savedMutations, 1);
    expect(find.byTooltip('Remove from saved'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-saved-posts')));
    await tester.pumpAndSettle();
    expect(find.text('Saved posts'), findsOneWidget);
    expect(find.text('A real Community Social v2 post'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('community-post-save-${_SocialV2Repository.postId}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.saved, isFalse);
    expect(repository.savedMutations, 2);
    expect(
      find.text('Posts you save are private and appear here.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'post detail supports likes, one-level replies, reports, and retry-safe comments',
    (tester) async {
      final repository = _SocialV2Repository()..addFailuresRemaining = 1;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('community-post-comments-${_SocialV2Repository.postId}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Root comment can be selected'), findsOneWidget);
      expect(find.text('One-level reply'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-post-detail-like')));
      await tester.pumpAndSettle();
      expect(repository.postLikeMutations, 1);

      await tester.tap(
        find.byKey(
          const Key('community-comment-like-${_SocialV2Repository.rootId}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.commentLikeMutations, 1);

      await tester.enterText(
        find.byKey(const Key('community-comment-composer')),
        'Retry-safe comment',
      );
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Retry-safe comment'), findsOneWidget);
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      expect(repository.submittedClientIds, hasLength(2));
      expect(
        repository.submittedClientIds.first,
        repository.submittedClientIds.last,
      );
      expect(repository.submittedParentIds, everyElement(isNull));

      await tester.tap(
        find.byKey(
          const Key('community-comment-actions-${_SocialV2Repository.rootId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('community-comment-composer')),
        'Bounded reply',
      );
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      expect(repository.submittedParentIds.last, _SocialV2Repository.rootId);

      await tester.tap(
        find.byKey(
          const Key('community-comment-actions-${_SocialV2Repository.rootId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(repository.commentReports, 1);

      await tester.tap(
        find.byKey(
          const Key('community-comment-actions-${_SocialV2Repository.rootId}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block member'));
      await tester.pumpAndSettle();
      expect(repository.blocks, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
