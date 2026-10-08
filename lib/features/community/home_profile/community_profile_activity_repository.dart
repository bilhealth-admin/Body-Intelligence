import '../data/community_post_cloud_store.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';

final RegExp _communityProfileActivityUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class CommunityProfileReplyItem {
  const CommunityProfileReplyItem({required this.comment, required this.post});

  final CommunityComment comment;
  final CommunityPost post;
}

class CommunityProfileReplyPage {
  const CommunityProfileReplyPage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<CommunityProfileReplyItem> items;
  final bool hasMore;
  final DateTime? nextBefore;
  final String? nextBeforeId;
}

class CommunityProfileLikedPost {
  const CommunityProfileLikedPost({required this.post, required this.likedAt});

  final CommunityPost post;
  final DateTime likedAt;
}

class CommunityProfileLikePage {
  const CommunityProfileLikePage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<CommunityProfileLikedPost> items;
  final bool hasMore;
  final DateTime? nextBefore;
  final String? nextBeforeId;
}

abstract interface class CommunityProfileActivityDataSource {
  Future<CommunityProfileReplyPage> loadReplies({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  });

  Future<CommunityProfileLikePage> loadLikes({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  });
}

/// Reads profile-wide Community activity from server-authorized RPCs.
///
/// The SQL contract intentionally keeps Likes self-only. Replies may be shown
/// to another viewer only when that viewer can see the target profile, the
/// target allows post visibility, and each source post is visible to the
/// viewer. Deleted/removed comments and unavailable posts are never projected.
final class CommunityProfileActivityRepository
    implements CommunityProfileActivityDataSource {
  CommunityProfileActivityRepository(this.repository);

  final CommunityRepository repository;

  @override
  Future<CommunityProfileReplyPage> loadReplies({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    _validateCursor(userId, before, beforeId, limit);
    final boundedLimit = limit.clamp(1, 60);
    final response = await repository.communitySocialClient.rpc(
      'bil_community_profile_replies_v1',
      params: {
        'p_user_id': userId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': boundedLimit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile replies');
    }
    final rows = response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    if (rows.length != response.length) {
      throw const FormatException('Invalid Community profile reply row');
    }
    if (rows.isEmpty) {
      return const CommunityProfileReplyPage(items: [], hasMore: false);
    }

    final seenComments = <String>{};
    final postIds = <String>[];
    final parsed = <({CommunityComment comment, String postId})>[];
    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String ||
          !_communityProfileActivityUuid.hasMatch(postId)) {
        throw const FormatException('Invalid Community reply post');
      }
      final comment = CommunityComment.fromJson(row);
      if (!seenComments.add(comment.id)) {
        throw const FormatException('Duplicate Community profile reply');
      }
      parsed.add((comment: comment, postId: postId));
      if (!postIds.contains(postId)) postIds.add(postId);
    }

    final posts = await _loadHydratedPosts(postIds);
    final byId = {for (final post in posts) post.id: post};
    final items = parsed
        .map((entry) {
          final post = byId[entry.postId];
          return post == null
              ? null
              : CommunityProfileReplyItem(comment: entry.comment, post: post);
        })
        .whereType<CommunityProfileReplyItem>()
        .toList(growable: false);
    final last = rows.last;
    final nextBefore = DateTime.tryParse(last['created_at']?.toString() ?? '');
    final nextBeforeId = last['id'];
    if (nextBefore == null ||
        nextBeforeId is! String ||
        !_communityProfileActivityUuid.hasMatch(nextBeforeId)) {
      throw const FormatException('Invalid Community reply cursor');
    }
    return CommunityProfileReplyPage(
      items: List.unmodifiable(items),
      hasMore: rows.length == boundedLimit,
      nextBefore: nextBefore,
      nextBeforeId: nextBeforeId,
    );
  }

  @override
  Future<CommunityProfileLikePage> loadLikes({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    _validateCursor(userId, before, beforeId, limit);
    // The client mirrors the server's fail-closed contract so a profile visit
    // never probes another member's Likes endpoint.
    if (userId != repository.currentUserId) {
      throw const CommunityProfileLikesPrivateException();
    }
    final boundedLimit = limit.clamp(1, 60);
    final response = await repository.communitySocialClient.rpc(
      'bil_community_profile_likes_v1',
      params: {
        'p_user_id': userId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': boundedLimit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile likes');
    }
    final rows = response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    if (rows.length != response.length) {
      throw const FormatException('Invalid Community profile like row');
    }
    if (rows.isEmpty) {
      return const CommunityProfileLikePage(items: [], hasMore: false);
    }

    final refs = <({String postId, DateTime likedAt})>[];
    final seen = <String>{};
    for (final row in rows) {
      final postId = row['post_id'];
      final likedAt = DateTime.tryParse(row['liked_at']?.toString() ?? '');
      if (postId is! String ||
          !_communityProfileActivityUuid.hasMatch(postId) ||
          likedAt == null ||
          !seen.add(postId)) {
        throw const FormatException('Invalid Community profile like');
      }
      refs.add((postId: postId, likedAt: likedAt));
    }

    final posts = await _loadHydratedPosts(
      refs.map((entry) => entry.postId).toList(growable: false),
    );
    final byId = {for (final post in posts) post.id: post};
    final items = refs
        .map((entry) {
          final post = byId[entry.postId];
          return post == null
              ? null
              : CommunityProfileLikedPost(post: post, likedAt: entry.likedAt);
        })
        .whereType<CommunityProfileLikedPost>()
        .toList(growable: false);
    final last = refs.last;
    return CommunityProfileLikePage(
      items: List.unmodifiable(items),
      hasMore: rows.length == boundedLimit,
      nextBefore: last.likedAt,
      nextBeforeId: last.postId,
    );
  }

  Future<List<CommunityPost>> _loadHydratedPosts(List<String> postIds) async {
    if (postIds.isEmpty) return const [];
    final store = repository.communityPostStore;
    if (store is! CommunityPostLookupContract) {
      throw StateError('Community profile post lookup is unavailable');
    }
    final lookup = store as CommunityPostLookupContract;
    final basePosts = await lookup.loadPostsByIds(postIds);
    if (basePosts.isEmpty) return const [];
    final visibleIds = basePosts.map((post) => post.id).toList(growable: false);
    final authorIds = basePosts
        .map((post) => post.authorId)
        .toSet()
        .toList(growable: false);
    final pollFuture = store is CommunityPostCloudStore
        ? repository.loadCommunityPolls(visibleIds)
        : Future<List<CommunityPoll>>.value(const <CommunityPoll>[]);
    final extras = await Future.wait<Object>([
      repository.loadPostStats(visibleIds),
      repository.loadSavedStates(visibleIds),
      repository.loadPostAuthors(authorIds),
      pollFuture,
    ]);
    final stats = extras[0] as List<CommunityPostStats>;
    final saved = extras[1] as List<CommunitySavedState>;
    final authors = extras[2] as List<CommunityPostAuthorSocial>;
    final polls = extras[3] as List<CommunityPoll>;
    final statsById = {for (final item in stats) item.postId: item};
    final savedById = {for (final item in saved) item.postId: item.saved};
    final authorById = {for (final item in authors) item.userId: item};
    final pollById = {for (final item in polls) item.postId: item};
    final baseById = {for (final post in basePosts) post.id: post};

    return postIds
        .map((id) {
          final base = baseById[id];
          if (base == null) return null;
          final postStats = statsById[id];
          final withStats = postStats == null
              ? base
              : base.withStats(postStats);
          final withSaved = withStats.withSaved(savedById[id] ?? false);
          final withPoll = withSaved.withPoll(pollById[id]);
          final author = authorById[withPoll.authorId];
          return author == null ? withPoll : withPoll.withAuthorSocial(author);
        })
        .whereType<CommunityPost>()
        .toList(growable: false);
  }

  void _validateCursor(
    String userId,
    DateTime? before,
    String? beforeId,
    int limit,
  ) {
    if (!_communityProfileActivityUuid.hasMatch(userId) ||
        (before == null) != (beforeId == null) ||
        (beforeId != null &&
            !_communityProfileActivityUuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community profile activity cursor');
    }
  }
}

class CommunityProfileLikesPrivateException implements Exception {
  const CommunityProfileLikesPrivateException();

  @override
  String toString() => 'Community profile Likes are private';
}
