part of 'community_repository.dart';

mixin _CommunityReviewV2RepositoryMixin {
  SupabaseClient get _client;
  Future<String?> loadMyPostReviewReason(CommunityPost post) =>
      _reviewOwned(() async {
        final owner = _client.auth.currentUser?.id;
        if (post.authorId != owner ||
            post.moderationStatus != CommunityPostModerationStatus.rejected) {
          throw StateError('Not an owned rejected post');
        }
        final raw = await _client.rpc(
          'bil_get_my_post_review_v2',
          params: {'p_post_id': post.id},
        );
        if (raw == null) return null;
        if (raw is! Map ||
            raw['contract_version'] != 2 ||
            raw['post_id'] != post.id ||
            raw['owner_id'] != owner ||
            raw['decision'] != 'rejected' ||
            raw['reason'] is! String ||
            !CommunityReviewSnapshot.revisionPattern.hasMatch(
              '${raw['reviewed_revision']}',
            ) ||
            DateTime.tryParse('${raw['decided_at']}') == null) {
          throw const FormatException('Invalid owned post review');
        }
        final reason = (raw['reason'] as String).trim();
        if (reason.isEmpty || reason.runes.length > 160) {
          throw const FormatException('Invalid review reason');
        }
        if (raw['post_body'] != post.body ||
            DateTime.tryParse('${raw['post_created_at']}')?.toUtc() !=
                post.createdAt.toUtc()) {
          return null;
        }
        return reason;
      });
  Future<List<CommunityPost>> hydrateModerationReviewContents(
    List<CommunityPost> posts,
  );

  Future<List<CommunityReviewSnapshot>> loadReviewedPosts(
    List<CommunityPost> posts,
  ) => _reviewOwned(() async {
    if (posts.isEmpty) return const [];
    if (posts.length > 100) throw ArgumentError('Review batch exceeds 100');
    final ids = posts.map((p) => p.id).toList();
    final original = {for (final post in posts) post.id: post};
    final before = await _reviewSnapshots(ids, original: original);
    final hydrated = await hydrateModerationReviewContents([
      for (final p in posts)
        if (before[p.id] case final snapshot?) snapshot.post,
    ]);
    final after = await _reviewSnapshots(ids, original: original);
    for (final entry in before.entries) {
      if (after[entry.key]?.revision != entry.value.revision) {
        throw const StateErrorReviewChanged();
      }
    }
    return [for (final post in hydrated) before[post.id]!.withPost(post)];
  });

  Future<T> _reviewOwned<T>(Future<T> Function() action) {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign-in required');
    return CommunityOwnerOperation.run(
      client: _client,
      ownerId: owner,
      action: (operation) async {
        operation.check();
        final result = await action();
        operation.check();
        return result;
      },
    );
  }

  Future<Map<String, CommunityReviewSnapshot>> _reviewSnapshots(
    List<String> ids, {
    Map<String, CommunityPost> original = const {},
  }) async {
    final raw = await _client
        .rpc('bil_community_review_snapshots_v2', params: {'p_post_ids': ids})
        .timeout(const Duration(seconds: 15));
    if (raw is! List) throw const FormatException('Invalid review snapshots');
    final result = <String, CommunityReviewSnapshot>{};
    for (final item in raw) {
      if (item is Map && item['post'] is Map) {
        final row = Map<String, dynamic>.from(item['post'] as Map);
        final previous = original[row['id']];
        if (previous?.authorId == row['author_id']) {
          row['author_name'] = previous?.authorName;
          row['author_avatar_url'] = previous?.authorAvatarUrl;
          item['post'] = row;
        }
      }
      final snapshot = _parseReviewSnapshot(item);
      if (!ids.contains(snapshot.post.id) ||
          result.containsKey(snapshot.post.id)) {
        throw const FormatException('Unexpected review snapshot');
      }
      result[snapshot.post.id] = snapshot;
    }
    return result;
  }

  CommunityReviewSnapshot _parseReviewSnapshot(Object? item) {
    if (item is! Map ||
        item['post'] is! Map ||
        item['revision'] is! String ||
        item['can_publish_only'] is! bool ||
        !CommunityReviewSnapshot.revisionPattern.hasMatch(
          item['revision'] as String,
        )) {
      throw const FormatException('Invalid review snapshot');
    }
    return CommunityReviewSnapshot(
      post: CommunityPost.fromJson(
        Map<String, dynamic>.from(item['post'] as Map),
      ),
      revision: item['revision'] as String,
      canPublishOnly: item['can_publish_only'] as bool,
    );
  }

  Future<CommunityPostModerationResult> moderateReviewedPost({
    required CommunityReviewSnapshot snapshot,
    required CommunityPostModerationDecision decision,
    required String operationId,
    String reason = '',
    bool publishOnly = false,
  }) => _reviewOwned(() async {
    if (publishOnly && !snapshot.canPublishOnly) {
      throw StateError('community_publish_only_not_authorized');
    }
    final raw = await _client
        .rpc(
          'bil_moderate_community_post_v2',
          params: {
            'p_post_id': snapshot.post.id,
            'p_expected_revision': snapshot.revision,
            'p_decision': decision.name,
            'p_operation_id': operationId,
            'p_reason': reason,
            'p_reward_mode': publishOnly ? 'deferred' : 'eligible',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (raw is! Map ||
        raw['contract_version'] != 2 ||
        raw['reviewed_revision'] != snapshot.revision ||
        raw['owner_id'] != snapshot.post.authorId ||
        raw['post_id'] != snapshot.post.id) {
      throw const FormatException('Invalid reviewed moderation receipt');
    }
    return CommunityPostModerationResult.fromJson(
      Map<String, dynamic>.from(raw),
    );
  });

  Future<List<CommunityRewardReview>> loadRewardReviewQueue() =>
      _reviewOwned(() async {
        final raw = await _client.rpc('bil_community_reward_review_queue_v2');
        if (raw is! List) throw const FormatException('Invalid reward queue');
        final result = <CommunityRewardReview>[];
        final seen = <String>{};
        for (final row in raw) {
          if (row is! Map ||
              row['can_grant'] is! bool ||
              !const {
                'not_requested',
                'requested',
                'executed',
                'rejected',
                'not_eligible',
              }.contains(row['status']) ||
              (row['request_id'] != null && row['request_id'] is! String)) {
            throw const FormatException('Invalid reward queue entry');
          }
          final snapshot = _parseReviewSnapshot(row);
          if (!seen.add(snapshot.post.id)) {
            throw const FormatException('Duplicate reward review');
          }
          result.add(
            CommunityRewardReview(
              snapshot: snapshot,
              requestId: row['request_id'] as String?,
              status: row['status'] as String,
              canGrant: row['can_grant'] as bool,
            ),
          );
        }
        return result;
      });

  Future<String> requestReviewedReward(CommunityReviewSnapshot snapshot) =>
      _reviewOwned(() async {
        final raw = await _client.rpc(
          'bil_request_community_post_reward_v2',
          params: {
            'p_post_id': snapshot.post.id,
            'p_expected_revision': snapshot.revision,
          },
        );
        return _rewardStatus(raw, snapshot.post);
      });

  Future<String> decideReviewedReward(
    CommunityRewardReview review, {
    required bool approve,
    String reason = '',
  }) => _reviewOwned(() async {
    if (!review.canGrant || review.requestId == null) {
      throw StateError('administrator_required');
    }
    final raw = await _client.rpc(
      'bil_decide_community_post_reward_v2',
      params: {
        'p_request_id': review.requestId,
        'p_approve': approve,
        'p_reason': reason,
      },
    );
    return _rewardStatus(raw, review.snapshot.post);
  });

  String _rewardStatus(Object? raw, CommunityPost post) {
    if (raw is! Map ||
        raw['post_id'] != post.id ||
        raw['owner_id'] != post.authorId ||
        !const {
          'requested',
          'executed',
          'rejected',
          'not_eligible',
        }.contains(raw['status']) ||
        !const {0, 5}.contains(raw['tokens_granted']) ||
        (raw['status'] != 'executed' && raw['tokens_granted'] != 0)) {
      throw const FormatException('Invalid reward receipt');
    }
    return raw['status'] as String;
  }
}

class StateErrorReviewChanged implements Exception {
  const StateErrorReviewChanged();
  @override
  String toString() => 'community_review_content_changed';
}
