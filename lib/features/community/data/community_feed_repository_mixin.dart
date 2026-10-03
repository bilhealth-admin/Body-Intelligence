import '../domain/community_circles.dart';
import '../domain/community_feed_modes.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';
import '../domain/community_topics.dart';
import 'community_post_cloud_store.dart';

mixin CommunityFeedRepositoryMixin {
  CommunityPostStoreContract get communityPostStore;

  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds);

  Future<List<CommunitySavedState>> loadSavedStates(List<String> postIds);

  Future<List<CommunityPostAuthorSocial>> loadPostAuthors(List<String> userIds);

  Future<List<CommunityPoll>> loadCommunityPolls(List<String> postIds);

  Future<List<CommunitySavedPostReference>> loadSavedPostReferences({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  Future<List<CommunityTopicPostReference>> loadCommunityTopicPostReferences({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  Future<List<CommunityCirclePostReference>> loadCommunityCirclePostReferences({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  Future<List<CommunityFeedReference>> loadCommunityFeedReferences({
    required CommunityFeedMode mode,
    int? beforePriority,
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

  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    final store = communityPostStore;
    if (store is! CommunityPostProfilePaginationContract) {
      throw StateError('Community profile-post paging is unavailable');
    }
    final page = await (store as CommunityPostProfilePaginationContract)
        .loadProfilePostsPage(
          userId: userId,
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

  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    // Keep injected non-cloud stores used by deterministic widget/unit tests
    // compatible with the established public feed seam. Production always
    // uses the server-ranked RPC below.
    if (communityPostStore is! CommunityPostCloudStore &&
        (mode == CommunityFeedMode.forYou ||
            mode == CommunityFeedMode.explore)) {
      final page = before == null
          ? CommunityFeedBatch(
              posts: await communityPostStore.loadFeed(limit: limit),
              hasMore: false,
            )
          : await loadOlderFeed(
              before: before,
              beforeId: beforeId!,
              limit: limit,
            );
      final refs = page.posts
          .map(
            (post) => CommunityFeedReference(
              postId: post.id,
              createdAt: post.createdAt,
              priority: 0,
              reasons: const [],
            ),
          )
          .toList(growable: false);
      final cursor = refs.isEmpty ? null : refs.last;
      return CommunityFeedModeBatch(
        posts: page.posts,
        references: refs,
        hasMore: page.hasMore,
        nextPriority: cursor?.priority,
        nextBefore: cursor?.createdAt,
        nextBeforeId: cursor?.postId,
      );
    }

    final references = await loadCommunityFeedReferences(
      mode: mode,
      beforePriority: beforePriority,
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    if (references.isEmpty) {
      return const CommunityFeedModeBatch(
        posts: [],
        references: [],
        hasMore: false,
      );
    }
    final store = communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community feed post lookup is unavailable');
    }
    final ids = references.map((value) => value.postId).toList(growable: false);
    final posts = await (store as CommunityPostLookupContract).loadPostsByIds(
      ids,
    );
    final hydrated = await _hydrateSocialPosts(posts);
    final byId = {for (final post in hydrated) post.id: post};
    final ordered = references
        .map((reference) => byId[reference.postId])
        .whereType<CommunityPost>()
        .toList(growable: false);
    final cursor = references.last;
    return CommunityFeedModeBatch(
      posts: List.unmodifiable(ordered),
      references: references,
      hasMore: references.length == limit,
      nextPriority: cursor.priority,
      nextBefore: cursor.createdAt,
      nextBeforeId: cursor.postId,
    );
  }

  Future<CommunityCirclePostBatch> loadCommunityCirclePosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    final references = await loadCommunityCirclePostReferences(
      slug: slug,
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    if (references.isEmpty) {
      return const CommunityCirclePostBatch(posts: [], hasMore: false);
    }
    final store = communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community circle post lookup is unavailable');
    }
    final ids = references.map((value) => value.postId).toList(growable: false);
    final posts = await (store as CommunityPostLookupContract).loadPostsByIds(
      ids,
    );
    final hydrated = await _hydrateSocialPosts(posts);
    final byId = {for (final post in hydrated) post.id: post};
    final ordered = references
        .map((reference) => byId[reference.postId])
        .whereType<CommunityPost>()
        .toList(growable: false);
    final cursor = references.last;
    return CommunityCirclePostBatch(
      posts: List.unmodifiable(ordered),
      hasMore: references.length == limit,
      nextBefore: cursor.createdAt,
      nextBeforeId: cursor.postId,
    );
  }

  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    final references = await loadCommunityTopicPostReferences(
      slug: slug,
      before: before,
      beforeId: beforeId,
      limit: limit,
    );
    if (references.isEmpty) {
      return const CommunityTopicPostBatch(posts: [], hasMore: false);
    }
    final store = communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community topic post lookup is unavailable');
    }
    final ids = references.map((value) => value.postId).toList(growable: false);
    final posts = await (store as CommunityPostLookupContract).loadPostsByIds(
      ids,
    );
    final hydrated = await _hydrateSocialPosts(posts);
    final byId = {for (final post in hydrated) post.id: post};
    final ordered = references
        .map((reference) => byId[reference.postId])
        .whereType<CommunityPost>()
        .toList(growable: false);
    final cursor = references.last;
    return CommunityTopicPostBatch(
      posts: List.unmodifiable(ordered),
      hasMore: references.length == limit,
      nextBefore: cursor.createdAt,
      nextBeforeId: cursor.postId,
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
      loadCommunityPolls(postIds),
    ]);
    final stats = hydratedData[0] as List<CommunityPostStats>;
    final saved = hydratedData[1] as List<CommunitySavedState>;
    final authors = hydratedData[2] as List<CommunityPostAuthorSocial>;
    final polls = hydratedData[3] as List<CommunityPoll>;
    final byPost = {for (final value in stats) value.postId: value};
    final savedByPost = {for (final value in saved) value.postId: value.saved};
    final authorById = {for (final value in authors) value.userId: value};
    final pollByPost = {for (final value in polls) value.postId: value};
    return posts
        .map((post) {
          final postStats = byPost[post.id];
          final withStats = postStats == null
              ? post
              : post.withStats(postStats);
          final social = authorById[post.authorId];
          final withSaved = withStats.withSaved(
            savedByPost[post.id] ?? false,
          );
          final withPoll = withSaved.withPoll(pollByPost[post.id]);
          return social == null
              ? withPoll
              : withPoll.withAuthorSocial(social);
        })
        .toList(growable: false);
  }
}
