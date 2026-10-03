part of 'community_repository.dart';

mixin _CommunityDiscoveryRepositoryMixin {
  SupabaseClient get _client;

  Future<T> _runCommunityMutation<T>(Future<T> Function() mutation);

  void _validateTopicSlugs(List<String> slugs);

  Future<CommunityInviteCreateResult> createCommunityInvite() async {
    final response = await _client.rpc('bil_create_community_invite_v1');
    if (response is! Map) {
      throw const FormatException('Invalid Community invite creation');
    }
    return CommunityInviteCreateResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CommunityInvitePreview> previewCommunityInvite(String token) async {
    if (!CommunityInviteCreateResult.tokenPattern.hasMatch(token)) {
      throw ArgumentError.value(token, 'token');
    }
    final response = await _client.rpc(
      'bil_preview_community_invite_v1',
      params: {'p_token': token},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community invite preview');
    }
    return CommunityInvitePreview.fromJson(Map<String, dynamic>.from(response));
  }

  Future<CommunityInviteAcceptance> acceptCommunityInvite(String token) async {
    if (!CommunityInviteCreateResult.tokenPattern.hasMatch(token)) {
      throw ArgumentError.value(token, 'token');
    }
    final response = await _client.rpc(
      'bil_accept_community_invite_v1',
      params: {'p_token': token},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community invite acceptance');
    }
    return CommunityInviteAcceptance.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<CommunityReferralAttribution?> loadMyReferralAttribution() async {
    final response = await _client.rpc('bil_my_community_referral_v1');
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid Community referral attribution');
    }
    return CommunityReferralAttribution.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<List<CommunityFeedReference>> loadCommunityFeedReferences({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    if ((beforePriority == null) != (before == null) ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community feed cursor');
    }
    final response = await _client.rpc(
      'bil_community_feed_refs_v1',
      params: {
        'p_mode': mode.wireValue,
        'p_before_priority': beforePriority,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community feed references');
    }
    return List<CommunityFeedReference>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community feed reference');
        }
        return CommunityFeedReference.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  Future<List<CommunityCircle>> loadCommunityCircles() async {
    final response = await _client.rpc('bil_list_community_circles_v1');
    if (response is! List) {
      throw const FormatException('Invalid Community circle list');
    }
    return List<CommunityCircle>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community circle row');
        }
        return CommunityCircle.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  Future<CommunityCircleMembershipStatus> joinCommunityCircle(
    String slug,
  ) async {
    if (!CommunityCircle.slugPattern.hasMatch(slug) || slug.length > 48) {
      throw ArgumentError.value(slug, 'slug');
    }
    final response = await _client.rpc(
      'bil_join_community_circle_v1',
      params: {'p_slug': slug},
    );
    if (response is! String ||
        !CommunityCircleMembershipStatus.values.any(
          (status) => status.name == response,
        )) {
      throw const FormatException('Invalid Community circle join result');
    }
    return CommunityCircleMembershipStatus.values.byName(response);
  }

  Future<bool> leaveCommunityCircle(String slug) async {
    if (!CommunityCircle.slugPattern.hasMatch(slug) || slug.length > 48) {
      throw ArgumentError.value(slug, 'slug');
    }
    final response = await _client.rpc(
      'bil_leave_community_circle_v1',
      params: {'p_slug': slug},
    );
    if (response is! bool) {
      throw const FormatException('Invalid Community circle leave result');
    }
    return response;
  }

  Future<void> setMyCommunityPostCircle({
    required String postId,
    String? slug,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId) ||
        (slug != null &&
            (slug.length > 48 ||
                !CommunityCircle.slugPattern.hasMatch(slug)))) {
      throw ArgumentError('Invalid Community post circle');
    }
    final response = await _client.rpc(
      'bil_set_my_community_post_circle_v1',
      params: {'p_post_id': postId, 'p_slug': slug},
    );
    if (slug == null) {
      if (response != null) {
        throw const FormatException('Invalid Community post circle result');
      }
      return;
    }
    if (response != slug) {
      throw const FormatException('Invalid Community post circle result');
    }
  }

  @override
  Future<List<CommunityCirclePostReference>> loadCommunityCirclePostReferences({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    if (!CommunityCircle.slugPattern.hasMatch(slug) ||
        slug.length > 48 ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community circle feed request');
    }
    final response = await _client.rpc(
      'bil_community_circle_post_refs_v1',
      params: {
        'p_slug': slug,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community circle feed');
    }
    return List<CommunityCirclePostReference>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community circle reference');
        }
        return CommunityCirclePostReference.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<void> createCommunityPoll({
    required String postId,
    required CommunityPollDraft draft,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final normalized = draft.normalized();
    final response = await _runCommunityMutation(
      () => _client.rpc(
        'bil_create_my_community_poll_v1',
        params: {
          'p_post_id': postId,
          'p_question': normalized.question,
          'p_options': normalized.options,
          'p_allow_multiple': normalized.allowMultiple,
          'p_closes_at': normalized.closesAt?.toIso8601String(),
        },
      ),
    );
    if (response != postId) {
      throw const FormatException('Invalid Community poll creation result');
    }
  }

  Future<CommunityPoll?> loadCommunityPoll(String postId) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final response = await _client.rpc(
      'bil_community_poll_v1',
      params: {'p_post_id': postId},
    );
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid Community poll');
    }
    final poll = CommunityPoll.fromJson(Map<String, dynamic>.from(response));
    if (poll.postId != postId) {
      throw const FormatException('Community poll did not match post');
    }
    return poll;
  }

  @override
  Future<List<CommunityPoll>> loadCommunityPolls(List<String> postIds) async {
    if (postIds.isEmpty) return const <CommunityPoll>[];
    if (postIds.length > 100 ||
        postIds.toSet().length != postIds.length ||
        postIds.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    final response = await _client.rpc(
      'bil_community_polls_v1',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community poll batch');
    }
    final requested = postIds.toSet();
    final seen = <String>{};
    final polls = <CommunityPoll>[];
    for (final row in response) {
      if (row is! Map) {
        throw const FormatException('Invalid Community poll batch row');
      }
      final json = Map<String, dynamic>.from(row);
      final rawPoll = json['poll'];
      final rowPostId = json['post_id'];
      if (rowPostId is! String || rawPoll is! Map) {
        throw const FormatException('Invalid Community poll batch row');
      }
      final poll = CommunityPoll.fromJson(Map<String, dynamic>.from(rawPoll));
      if (poll.postId != rowPostId ||
          !requested.contains(poll.postId) ||
          !seen.add(poll.postId)) {
        throw const FormatException('Invalid Community poll batch');
      }
      polls.add(poll);
    }
    return List.unmodifiable(polls);
  }

  Future<CommunityPoll> voteCommunityPoll({
    required String postId,
    required List<String> optionIds,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId) ||
        optionIds.isEmpty ||
        optionIds.length > 6 ||
        optionIds.toSet().length != optionIds.length ||
        optionIds.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError('Invalid Community poll vote');
    }
    final response = await _runCommunityMutation(
      () => _client.rpc(
        'bil_vote_community_poll_v1',
        params: {'p_post_id': postId, 'p_option_ids': optionIds},
      ),
    );
    if (response is! num || response.toInt() != optionIds.length) {
      throw const FormatException('Invalid Community poll vote result');
    }
    final poll = await loadCommunityPoll(postId);
    if (poll == null) {
      throw const FormatException('Community poll disappeared after vote');
    }
    return poll;
  }

  Future<List<CommunityMentionCandidate>> searchCommunityMentions(
    String query, {
    int limit = 12,
  }) async {
    final normalized = query.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.isEmpty ||
        normalized.length > 30 ||
        !RegExp(r'^[a-z][a-z0-9_]{0,29}$').hasMatch(normalized) ||
        limit < 1 ||
        limit > 20) {
      return const <CommunityMentionCandidate>[];
    }

    final response = await _client.rpc(
      'bil_search_community_mentions_v1',
      params: {'p_query': normalized, 'p_limit': limit},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community mention search');
    }
    return List<CommunityMentionCandidate>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community mention row');
        }
        return CommunityMentionCandidate.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<void> setMyCommunityPostContext({
    required String postId,
    String? locationLabel,
    List<CommunityMentionCandidate> mentions =
        const <CommunityMentionCandidate>[],
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final normalized = CommunityPostContextDraft(
      locationLabel: locationLabel,
      mentions: mentions,
    ).normalized();

    final response = await _client.rpc(
      'bil_set_my_community_post_context_v1',
      params: {
        'p_post_id': postId,
        'p_location_label': normalized.locationLabel,
        'p_mentioned_user_ids': normalized.mentionedUserIds,
      },
    );
    if (response is! Map ||
        response['post_id'] != postId ||
        response['mention_count'] != normalized.mentions.length ||
        response['location_label'] != normalized.locationLabel) {
      throw const FormatException('Invalid Community post context result');
    }
  }

  Future<List<CommunityTopic>> loadCommunityTopics() async {
    final response = await _client.rpc('bil_list_community_topics_v1');
    if (response is! List) {
      throw const FormatException('Invalid Community topic list');
    }
    return List<CommunityTopic>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community topic row');
        }
        return CommunityTopic.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  Future<bool> followCommunityTopic({
    required String slug,
    required bool follow,
  }) async {
    if (!CommunityTopic.slugPattern.hasMatch(slug) || slug.length > 48) {
      throw ArgumentError.value(slug, 'slug');
    }
    final response = await _client.rpc(
      'bil_follow_community_topic_v1',
      params: {'p_slug': slug, 'p_follow': follow},
    );
    if (response is! bool) {
      throw const FormatException('Invalid Community topic follow result');
    }
    return response;
  }

  Future<void> setMyCommunityPostTopics({
    required String postId,
    required List<String> slugs,
  }) async {
    _validateTopicSlugs(slugs);
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final response = await _client.rpc(
      'bil_set_my_community_post_topics_v1',
      params: {'p_post_id': postId, 'p_slugs': slugs},
    );
    if (response is! num || response.toInt() != slugs.length) {
      throw const FormatException('Invalid Community post topic result');
    }
  }

  @override
  Future<List<CommunityTopicPostReference>> loadCommunityTopicPostReferences({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    if (!CommunityTopic.slugPattern.hasMatch(slug) ||
        slug.length > 48 ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community topic feed request');
    }
    final response = await _client.rpc(
      'bil_community_topic_post_refs_v1',
      params: {
        'p_slug': slug,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community topic feed');
    }
    return List<CommunityTopicPostReference>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community topic reference');
        }
        return CommunityTopicPostReference.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<CommunityGoldBalance> loadGoldBalance() async {
    final response = await _client.rpc('bil_gold_balance_v1');
    if (response is! Map) {
      throw const FormatException('Invalid BIL Gold balance');
    }
    return CommunityGoldBalance.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async {
    if ((beforeCreatedAt == null) != (beforeId == null) ||
        (beforeId != null && beforeId < 1) ||
        limit < 1 ||
        limit > 100) {
      throw ArgumentError('Invalid BIL Gold history cursor');
    }
    final response = await _client.rpc(
      'bil_gold_history_v1',
      params: {
        'p_before_created_at': beforeCreatedAt?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid BIL Gold history');
    }
    return List<CommunityGoldLedgerEntry>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid BIL Gold history row');
        }
        return CommunityGoldLedgerEntry.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<List<CommunityQuest>> loadCommunityQuests() async {
    final response = await _client.rpc('bil_list_community_quests_v1');
    if (response is! List) {
      throw const FormatException('Invalid Community quest list');
    }
    return List<CommunityQuest>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community quest row');
        }
        return CommunityQuest.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  Future<CommunityQuestClaimResult> claimCommunityQuest({
    required String questKey,
    required String periodKey,
  }) async {
    if (!CommunityQuest.questKeyPattern.hasMatch(questKey) ||
        periodKey.length < 4 ||
        periodKey.length > 16) {
      throw ArgumentError('Invalid Community quest claim');
    }
    final response = await _client.rpc(
      'bil_claim_community_quest_v1',
      params: {'p_quest_key': questKey, 'p_period_key': periodKey},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community quest claim result');
    }
    return CommunityQuestClaimResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

}
