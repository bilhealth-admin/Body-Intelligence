import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _PagedPostStore
    implements
        CommunityPostStoreContract,
        CommunityPostPaginationContract,
        CommunityPostLookupContract {
  static const firstId = '11111111-1111-4111-8111-111111111111';
  static const olderId = '22222222-2222-4222-8222-222222222222';
  static const authorId = '33333333-3333-4333-8333-333333333333';
  DateTime? receivedBefore;
  String? receivedBeforeId;

  CommunityPost post(String id, DateTime createdAt) => CommunityPost(
    id: id,
    authorId: authorId,
    authorName: 'Training Partner',
    body: 'Post $id',
    createdAt: createdAt,
  );

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    post(firstId, DateTime.utc(2026, 9, 8, 12)),
  ];

  @override
  Future<CommunityFeedBatch> loadFeedPage({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async {
    receivedBefore = before;
    receivedBeforeId = beforeId;
    final older = post(olderId, DateTime.utc(2026, 9, 8, 11));
    return CommunityFeedBatch(
      posts: [older],
      hasMore: false,
      nextBefore: older.createdAt,
      nextBeforeId: older.id,
    );
  }

  @override
  Future<List<CommunityPost>> loadPostsByIds(List<String> postIds) async =>
      postIds
          .map((id) => post(id, DateTime.utc(2026, 9, 8, 10)))
          .toList(growable: false);

  @override
  Future<List<CommunityPost>> loadModerationQueue({int limit = 100}) async =>
      const [];

  @override
  Future<void> publishText(String body) async {}

  @override
  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {}

  @override
  Future<void> delete(String postId) async {}
}

final class _PagedRepository extends CommunityRepository {
  _PagedRepository(this.store)
    : super(
        SupabaseClient(
          'https://feed-page.invalid',
          'feed-page-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        postStore: store,
      );

  final _PagedPostStore store;

  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds) async =>
      postIds
          .map(
            (id) => CommunityPostStats(
              postId: id,
              likeCount: 4,
              liked: true,
              commentCount: 3,
            ),
          )
          .toList(growable: false);

  @override
  Future<List<CommunitySavedState>> loadSavedStates(
    List<String> postIds,
  ) async => postIds
      .map((id) => CommunitySavedState(postId: id, saved: true))
      .toList(growable: false);

  @override
  Future<List<CommunityPostAuthorSocial>> loadPostAuthors(
    List<String> userIds,
  ) async => userIds
      .map(
        (id) => CommunityPostAuthorSocial(
          userId: id,
          handle: 'training_partner',
          relationship: CommunityRelationshipStatus.none,
          canRequest: true,
        ),
      )
      .toList(growable: false);

  @override
  Future<List<CommunitySavedPostReference>> loadSavedPostReferences({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => [
    CommunitySavedPostReference(
      postId: _PagedPostStore.olderId,
      savedAt: DateTime.utc(2026, 9, 8, 13),
    ),
  ];
}

void main() {
  test(
    'feed and saved pages hydrate stats, save, handle, and relationship',
    () async {
      final store = _PagedPostStore();
      final repository = _PagedRepository(store);
      final feed = await repository.loadFeed();

      expect(feed, hasLength(1));
      expect(feed.single.likeCount, 4);
      expect(feed.single.commentCount, 3);
      expect(feed.single.liked, isTrue);
      expect(feed.single.saved, isTrue);
      expect(feed.single.authorHandle, 'training_partner');
      expect(feed.single.authorCanRequest, isTrue);

      final saved = await repository.loadSavedPosts();
      expect(saved.posts.single.id, _PagedPostStore.olderId);
      expect(saved.posts.single.saved, isTrue);
      expect(saved.posts.single.authorHandle, 'training_partner');
    },
  );

  test('older feed uses a stable timestamp and UUID cursor', () async {
    final store = _PagedPostStore();
    final repository = _PagedRepository(store);
    final before = DateTime.utc(2026, 9, 8, 12);
    final page = await repository.loadOlderFeed(
      before: before,
      beforeId: _PagedPostStore.firstId,
    );

    expect(store.receivedBefore, before);
    expect(store.receivedBeforeId, _PagedPostStore.firstId);
    expect(page.posts.single.id, _PagedPostStore.olderId);
    expect(page.hasMore, isFalse);
    expect(page.posts.single.authorHandle, 'training_partner');
  });
}
