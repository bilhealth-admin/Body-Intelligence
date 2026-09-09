import '../domain/community_models.dart';
import 'community_post_cloud_store.dart';

mixin CommunityFeedRepositoryMixin {
  CommunityPostStoreContract get communityPostStore;

  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds);

  Future<List<CommunitySavedState>> loadSavedStates(List<String> postIds);

  Future<List<CommunityPostAuthorSocial>> loadPostAuthors(List<String> userIds);

  Future<List<CommunitySavedPostReference>> loadSavedPostReferences({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    final posts = await communityPostStore.loadFeed(limit: limit);
    return _hydrateSocialPosts(posts);
  }

  Future<CommunityFeedBatch> loadOlderFeed({
    required DateTime before,
    required String beforeId,
    int limit = 40,
  }) async {
    final store = communityPostStore;
    if (store is! CommunityPostPaginationContract) {
      throw StateError('Community feed pagination is unavailable');
    }
    final page = await (store as CommunityPostPaginationContract).loadFeedPage(
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    return CommunityFeedBatch(
      posts: await _hydrateSocialPosts(page.posts),
      hasMore: page.hasMore,
      nextBefore: page.nextBefore,
      nextBeforeId: page.nextBeforeId,
    );
  }

  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async {
    final store = communityPostStore;
    if (store is! CommunityPostAuthorPaginationContract) {
      throw StateError('Community authored-post paging is unavailable');
    }
    final page = await (store as CommunityPostAuthorPaginationContract)
        .loadMyPostsPage(before: before, beforeId: beforeId, limit: limit);
    return CommunityFeedBatch(
      posts: await _hydrateSocialPosts(page.posts),
      hasMore: page.hasMore,
      nextBefore: page.nextBefore,
      nextBeforeId: page.nextBeforeId,
    );
  }

  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    final references = await loadSavedPostReferences(
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    if (references.isEmpty) {
      return const CommunitySavedPostBatch(posts: [], hasMore: false);
    }
    final store = communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community saved-post lookup is unavailable');
    }
    final ids = references.map((value) => value.postId).toList(growable: false);
    final posts = await (store as CommunityPostLookupContract).loadPostsByIds(
      ids,
    );
    final hydrated = await _hydrateSocialPosts(posts);
    final cursor = references.last;
    return CommunitySavedPostBatch(
      posts: hydrated
          .map((post) => post.withSaved(true))
          .toList(growable: false),
      hasMore: references.length == limit,
      nextBefore: cursor.savedAt,
      nextBeforeId: cursor.postId,
    );
  }

  Future<List<CommunityPost>> _hydrateSocialPosts(
    List<CommunityPost> posts,
  ) async {
    if (posts.isEmpty) return posts;
    final postIds = posts.map((post) => post.id).toList(growable: false);
    final authorIds = posts.map((post) => post.authorId).toSet().toList();
    final hydratedData = await Future.wait<Object>([
      loadPostStats(postIds),
      loadSavedStates(postIds),
      loadPostAuthors(authorIds),
    ]);
    final stats = hydratedData[0] as List<CommunityPostStats>;
    final saved = hydratedData[1] as List<CommunitySavedState>;
    final authors = hydratedData[2] as List<CommunityPostAuthorSocial>;
    final byPost = {for (final value in stats) value.postId: value};
    final savedByPost = {for (final value in saved) value.postId: value.saved};
    final authorById = {for (final value in authors) value.userId: value};
    return posts
        .map((post) {
          final postStats = byPost[post.id];
          final withStats = postStats == null
              ? post
              : post.withStats(postStats);
          final social = authorById[post.authorId];
          final hydrated = withStats.withSaved(savedByPost[post.id] ?? false);
          return social == null ? hydrated : hydrated.withAuthorSocial(social);
        })
        .toList(growable: false);
  }
}
