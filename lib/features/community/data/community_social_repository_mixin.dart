import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';

/// Typed Flutter boundary for the deployed Community Social v2 RPC surface.
///
/// This stays as a mixin so tests can override individual repository methods
/// without opening network connections, while the main repository remains
/// below the reviewed architecture size ceiling.
mixin CommunitySocialRepositoryMixin {
  SupabaseClient get communitySocialClient;

  Future<T> runCommunitySocialMutation<T>(Future<T> Function() mutation);

  Future<void> requireAcceptedCommunityPolicy();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _unsafeText = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  User get _socialUser {
    final user = communitySocialClient.auth.currentUser;
    if (user == null) throw const AuthException('Sign-in required');
    return user;
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final text = CommunitySocialIdentity.normalize(query);
    if (!CommunitySocialIdentity.handlePattern.hasMatch(text)) return const [];
    final response = await communitySocialClient.rpc(
      'bil_social_search_handles_v2',
      params: {'p_query': text, 'p_limit': 20},
    );
    if (response is! List) {
      throw const FormatException('Invalid community profile search result');
    }
    final rows = response.whereType<Map>().map(Map<String, dynamic>.from);
    return rows
        .where((row) {
          final id = row['user_id'];
          final name = row['display_name'];
          final avatar = row['avatar_url'];
          final handle = row['handle'];
          return id is String &&
              _uuid.hasMatch(id) &&
              handle is String &&
              CommunitySocialIdentity.handlePattern.hasMatch(handle) &&
              name is String &&
              name.trim().length >= 2 &&
              name.trim().length <= 60 &&
              !_unsafeText.hasMatch(name) &&
              (avatar == null || avatar is String) &&
              row.keys.every(
                const {
                  'user_id',
                  'handle',
                  'display_name',
                  'avatar_url',
                }.contains,
              );
        })
        .toList(growable: false);
  }

  Future<CommunitySocialIdentity> loadSocialIdentity() async {
    final response = await communitySocialClient.rpc('bil_social_identity_v2');
    if (response is! Map) {
      throw const FormatException('Invalid Community identity result');
    }
    return CommunitySocialIdentity.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CommunitySocialIdentity> claimSocialHandle(String value) async {
    final handle = CommunitySocialIdentity.normalize(value);
    if (!CommunitySocialIdentity.isValidCandidate(handle)) {
      throw const FormatException('Invalid Community username');
    }
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_claim_handle_v2',
        params: {'p_handle': handle},
      ),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community identity result');
    }
    return CommunitySocialIdentity.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<CommunityPostAuthorSocial>> loadPostAuthors(
    List<String> userIds,
  ) async {
    if (userIds.length > 100 || userIds.any((id) => !_uuid.hasMatch(id))) {
      throw ArgumentError.value(userIds, 'userIds');
    }
    if (userIds.isEmpty) return const [];
    final response = await communitySocialClient.rpc(
      'bil_social_post_authors_v2',
      params: {'p_user_ids': userIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community post authors');
    }
    final requested = userIds.toSet();
    final seen = <String>{};
    final result = <CommunityPostAuthorSocial>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('Invalid Community post author');
      }
      final json = Map<String, dynamic>.from(item);
      final rawUserId = json['user_id'];
      if (json['handle'] == null) {
        // Handles are provisioned lazily by Social v2. A legacy author can
        // therefore be visible before opening the identity surface once. Keep
        // the post usable without exposing or inventing an identity.
        if (rawUserId is! String ||
            !_uuid.hasMatch(rawUserId) ||
            !requested.contains(rawUserId) ||
            !seen.add(rawUserId)) {
          throw const FormatException('Invalid Community post authors');
        }
        continue;
      }
      final author = CommunityPostAuthorSocial.fromJson(json);
      if (!requested.contains(author.userId) || !seen.add(author.userId)) {
        throw const FormatException('Invalid Community post authors');
      }
      result.add(author);
    }
    return List.unmodifiable(result);
  }

  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds) async {
    if (postIds.length > 100 || postIds.any((id) => !_uuid.hasMatch(id))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    if (postIds.isEmpty) return const [];
    final response = await communitySocialClient.rpc(
      'bil_social_stats_v2',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community statistics result');
    }
    final requested = postIds.toSet();
    final seen = <String>{};
    final result = <CommunityPostStats>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('Invalid Community statistics result');
      }
      final stats = CommunityPostStats.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (!requested.contains(stats.postId) || !seen.add(stats.postId)) {
        throw const FormatException('Invalid Community statistics result');
      }
      result.add(stats);
    }
    return List.unmodifiable(result);
  }

  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_like_v2',
        params: {'p_post_id': postId, 'p_liked': liked},
      ),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community statistics result');
    }
    final stats = CommunityPostStats.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (stats.postId != postId) {
      throw const FormatException('Community statistics did not match post');
    }
    return stats;
  }

  Future<List<CommunitySavedState>> loadSavedStates(
    List<String> postIds,
  ) async {
    if (postIds.length > 100 || postIds.any((id) => !_uuid.hasMatch(id))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    if (postIds.isEmpty) return const [];
    final response = await communitySocialClient.rpc(
      'bil_social_saved_state_v2',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community saved states');
    }
    final requested = postIds.toSet();
    final seen = <String>{};
    final result = <CommunitySavedState>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('Invalid Community saved state');
      }
      final state = CommunitySavedState.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (!requested.contains(state.postId) || !seen.add(state.postId)) {
        throw const FormatException('Invalid Community saved states');
      }
      result.add(state);
    }
    return List.unmodifiable(result);
  }

  Future<CommunitySavedState> setPostSaved(
    String postId, {
    required bool saved,
  }) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_save_v2',
        params: {'p_post_id': postId, 'p_saved': saved},
      ),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community saved state');
    }
    final state = CommunitySavedState.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (state.postId != postId) {
      throw const FormatException('Community saved state did not match post');
    }
    return state;
  }

  Future<List<CommunitySavedPostReference>> loadSavedPostReferences({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    if ((before == null) != (beforeId == null) ||
        (beforeId != null && !_uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 100) {
      throw ArgumentError('Invalid Community saved-post cursor');
    }
    final response = await communitySocialClient.rpc(
      'bil_social_saved_posts_v2',
      params: {
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community saved posts');
    }
    final seen = <String>{};
    final result = <CommunitySavedPostReference>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('Invalid Community saved post');
      }
      final reference = CommunitySavedPostReference.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (!seen.add(reference.postId)) {
        throw const FormatException('Duplicate Community saved post');
      }
      result.add(reference);
    }
    return List.unmodifiable(result);
  }

  Future<CommunityPublicCode> loadPublicCode() async {
    final response = await communitySocialClient.rpc(
      'bil_social_public_code_v2',
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community public code');
    }
    return CommunityPublicCode.fromJson(Map<String, dynamic>.from(response));
  }

  Future<CommunityPublicCode> rotatePublicCode() async {
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc('bil_social_rotate_public_code_v2'),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community public code');
    }
    return CommunityPublicCode.fromJson(Map<String, dynamic>.from(response));
  }

  Future<CommunityResolvedMember?> resolvePublicCode(String value) async {
    final code = value.trim().toLowerCase();
    if (!CommunityPublicCode.codePattern.hasMatch(code)) return null;
    final response = await communitySocialClient.rpc(
      'bil_social_resolve_public_code_v2',
      params: {'p_code': code},
    );
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid Community public member');
    }
    return CommunityResolvedMember.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<CommunityComment>> loadPostComments(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async {
    if (!_uuid.hasMatch(postId) ||
        (after == null) != (afterId == null) ||
        (afterId != null && !_uuid.hasMatch(afterId)) ||
        limit < 1 ||
        limit > 100) {
      throw ArgumentError('Invalid Community comment cursor');
    }
    final response = await communitySocialClient.rpc(
      'bil_social_comments_v2',
      params: {
        'p_post_id': postId,
        'p_after': after?.toUtc().toIso8601String(),
        'p_after_id': afterId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community comments result');
    }
    final comments = response
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid Community comment');
          }
          return CommunityComment.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    if (comments.any(
      (comment) => comment.parentId != null && comment.parentId == comment.id,
    )) {
      throw const FormatException('Invalid Community reply relation');
    }
    return List.unmodifiable(comments);
  }

  Future<CommunityComment> addPostComment({
    required String postId,
    required String body,
    required String clientId,
    String? parentId,
  }) async {
    if (!_uuid.hasMatch(postId) ||
        !_uuid.hasMatch(clientId) ||
        (parentId != null && !_uuid.hasMatch(parentId))) {
      throw ArgumentError('Invalid Community comment identity');
    }
    final text = body.trim();
    if (text.isEmpty || text.length > 1200 || _unsafeText.hasMatch(text)) {
      throw ArgumentError.value(body, 'body');
    }
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.comment);
    await requireAcceptedCommunityPolicy();
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_add_comment_v2',
        params: {
          'p_post_id': postId,
          'p_body': text,
          'p_parent_id': parentId,
          'p_client_id': clientId,
        },
      ),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community comment result');
    }
    final comment = CommunityComment.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (comment.id != clientId ||
        (parentId == null && comment.parentId != null)) {
      throw const FormatException('Community comment result did not match');
    }
    return comment;
  }

  Future<CommunityComment> setCommentLiked(
    CommunityComment comment, {
    required bool liked,
  }) async {
    if (!_uuid.hasMatch(comment.id)) {
      throw ArgumentError.value(comment.id, 'comment');
    }
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_like_comment_v2',
        params: {'p_comment_id': comment.id, 'p_liked': liked},
      ),
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community comment like result');
    }
    final map = Map<String, dynamic>.from(response);
    final likeCount = map['like_count'];
    final serverLiked = map['liked'];
    if (likeCount is! num ||
        likeCount < 0 ||
        likeCount % 1 != 0 ||
        serverLiked is! bool) {
      throw const FormatException('Invalid Community comment like result');
    }
    return comment.copyWith(likeCount: likeCount.toInt(), liked: serverLiked);
  }

  Future<void> deleteComment(String commentId) async {
    if (!_uuid.hasMatch(commentId)) {
      throw ArgumentError.value(commentId, 'commentId');
    }
    await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_delete_comment_v2',
        params: {'p_comment_id': commentId},
      ),
    );
  }

  Future<void> reportComment(String commentId, {required String reason}) async {
    final text = reason.trim();
    if (!_uuid.hasMatch(commentId) || text.length < 3 || text.length > 500) {
      throw ArgumentError('Invalid Community comment report');
    }
    await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_report_comment_v2',
        params: {'p_comment_id': commentId, 'p_reason': text},
      ),
    );
  }

  Future<CommunityFriendRequestStatus> requestFriend(String addresseeId) async {
    if (!_uuid.hasMatch(addresseeId) || addresseeId == _socialUser.id) {
      throw ArgumentError.value(addresseeId, 'addresseeId');
    }
    final response = await runCommunitySocialMutation(
      () => communitySocialClient.rpc(
        'bil_social_request_friend_v2',
        params: {'p_user_id': addresseeId},
      ),
    );
    if (response is! String ||
        !const {
          'pending',
          'incoming',
          'accepted',
          'declined',
        }.contains(response)) {
      throw const FormatException('Invalid Community friendship result');
    }
    return CommunityFriendRequestStatus.values.byName(response);
  }
}
