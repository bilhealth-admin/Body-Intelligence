import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../domain/community_attention.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_circles.dart';
import '../domain/community_feed_modes.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';
import '../domain/community_referral.dart';
import '../domain/community_rewards.dart';
import '../domain/community_text_policy.dart';
import '../domain/community_topics.dart';
import '../services/community_post_image_picker.dart';
import 'community_post_cloud_store.dart';
import 'community_feed_repository_mixin.dart';
import 'community_social_repository_mixin.dart';

class CommunityRepository
    with CommunitySocialRepositoryMixin, CommunityFeedRepositoryMixin {
  CommunityRepository(this._client, {CommunityPostStoreContract? postStore})
    // Keep the public injection seam named `postStore` while its field stays private.
    // ignore: prefer_initializing_formals
    : _postStore = postStore;

  final SupabaseClient _client;
  final CommunityPostStoreContract? _postStore;

  @override
  SupabaseClient get communitySocialClient => _client;

  @override
  CommunityPostStoreContract get communityPostStore => _posts;

  @override
  Future<T> runCommunitySocialMutation<T>(Future<T> Function() mutation) =>
      _runCommunityMutation(mutation);

  @override
  Future<void> requireAcceptedCommunityPolicy() =>
      _requireAcceptedContentPolicy();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _unsafeText = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  String get currentUserId => _user.id;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign-in required');
    return user;
  }

  CommunityPostStoreContract get _posts =>
      _postStore ?? CommunityPostCloudStore(_client, _user);

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
        (beforeId != null && !_uuid.hasMatch(beforeId)) ||
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
    if (!_uuid.hasMatch(postId) ||
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
        (beforeId != null && !_uuid.hasMatch(beforeId)) ||
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
    if (!_uuid.hasMatch(postId)) {
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
    if (!_uuid.hasMatch(postId)) {
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

  Future<List<CommunityPoll>> loadCommunityPolls(List<String> postIds) async {
    if (postIds.isEmpty) return const <CommunityPoll>[];
    if (postIds.length > 100 ||
        postIds.toSet().length != postIds.length ||
        postIds.any((id) => !_uuid.hasMatch(id))) {
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
      final poll = CommunityPoll.fromJson(
        Map<String, dynamic>.from(rawPoll),
      );
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
    if (!_uuid.hasMatch(postId) ||
        optionIds.isEmpty ||
        optionIds.length > 6 ||
        optionIds.toSet().length != optionIds.length ||
        optionIds.any((id) => !_uuid.hasMatch(id))) {
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
    if (!_uuid.hasMatch(postId)) {
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
        (beforeId != null && !_uuid.hasMatch(beforeId)) ||
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

  Future<CommunityProfile?> loadMyProfile() async {
    final row = await _client
        .from('bil_public_profiles')
        .select(
          'user_id,display_name,avatar_url,bio,locale_code,discoverable,profile_visibility,allow_friend_requests,allow_follows,allow_messages_from,country_code,show_followers,show_following,show_friends,show_posts,show_membership_tier',
        )
        .eq('user_id', _user.id)
        .maybeSingle();
    return row == null ? null : CommunityProfile.fromJson(row);
  }

  Future<CommunityProfileOverview?> loadMyProfileOverview() async {
    try {
      return await loadProfileOverview(_user.id);
    } on Object {
      final profile = await loadMyProfile();
      return profile == null
          ? null
          : CommunityProfileOverview.fromProfile(profile);
    }
  }

  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    if (!_uuid.hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId');
    }
    final response = await _client.rpc(
      'bil_community_profile_projection_v1',
      params: {'p_user_id': userId},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community profile projection');
    }
    final overview = CommunityProfileOverview.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (overview.userId != userId) {
      throw const FormatException('Community profile projection mismatch');
    }
    return overview;
  }

  Future<List<CommunityProfileConnection>> loadProfileConnections({
    required String userId,
    required CommunityProfileConnectionKind kind,
    DateTime? before,
    String? beforeUserId,
    int limit = 30,
  }) async {
    if (!_uuid.hasMatch(userId) ||
        (before == null) != (beforeUserId == null) ||
        (beforeUserId != null && !_uuid.hasMatch(beforeUserId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community profile connection cursor');
    }
    final response = await _client.rpc(
      'bil_community_profile_connections_v1',
      params: {
        'p_user_id': userId,
        'p_kind': kind.name,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_user_id': beforeUserId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile connections');
    }
    return List<CommunityProfileConnection>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community profile connection');
        }
        return CommunityProfileConnection.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<void> saveMyProfilePrivacy({
    String? countryCode,
    required bool showFollowers,
    required bool showFollowing,
    required bool showFriends,
    required bool showPosts,
    required bool showMembershipTier,
  }) async {
    final normalizedCountry = countryCode?.trim().toUpperCase();
    final validCountry =
        normalizedCountry == null ||
        normalizedCountry.isEmpty ||
        (normalizedCountry.length == 2 &&
            normalizedCountry.codeUnits.every(
              (unit) => unit >= 65 && unit <= 90,
            ));
    if (!validCountry) {
      throw const FormatException('Invalid Community country code');
    }
    final changed = await _client
        .from('bil_public_profiles')
        .update({
          'country_code': normalizedCountry == null || normalizedCountry.isEmpty
              ? null
              : normalizedCountry,
          'show_followers': showFollowers,
          'show_following': showFollowing,
          'show_friends': showFriends,
          'show_posts': showPosts,
          'show_membership_tier': showMembershipTier,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _user.id)
        .select('user_id');
    if (changed.length != 1) {
      throw StateError('Community profile privacy was not available to update');
    }
  }

  Future<void> saveMyProfile({
    required String displayName,
    required String localeCode,
    required bool discoverable,
    String? bio,
    CommunityProfileVisibility visibility = CommunityProfileVisibility.friends,
    bool allowFriendRequests = true,
    bool allowFollows = false,
    CommunityMessagePermission allowMessagesFrom =
        CommunityMessagePermission.friends,
  }) async {
    final name = displayName.trim();
    final about = bio?.trim();
    if (name.length < 2 || name.length > 60) {
      throw const FormatException('Invalid community display name');
    }
    final canonicalLocale = BilLocalePolicy.canonicalSupportedTag(localeCode);
    if (canonicalLocale == null) {
      throw const FormatException('Unsupported community locale');
    }
    if (about != null && about.length > 280) {
      throw const FormatException('Community bio is too long');
    }
    CommunityTextPolicy.enforceAll({
      CommunityTextSurface.profileDisplayName: name,
      CommunityTextSurface.profileBio: about,
    });
    await _client.from('bil_public_profiles').upsert({
      'user_id': _user.id,
      'display_name': name,
      'bio': about == null || about.isEmpty ? null : about,
      'locale_code': canonicalLocale,
      'discoverable': discoverable,
      'profile_visibility': visibility.name,
      'allow_friend_requests': allowFriendRequests,
      'allow_follows': allowFollows,
      'allow_messages_from': allowMessagesFrom.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<bool> isCommunityModerator() async {
    if (_client.auth.currentUser == null) return false;
    final response = await _client.rpc('bil_is_community_moderator');
    if (response is! bool) {
      throw const FormatException('Invalid community moderator result');
    }
    return response;
  }

  Future<List<CommunityPost>> loadPendingPostsForModeration({
    int limit = 100,
  }) => _posts.loadModerationQueue(limit: limit);

  Future<CommunityPostModerationResult> moderatePost({
    required String postId,
    required CommunityPostModerationDecision decision,
  }) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    final response = await _client.rpc(
      'bil_moderate_community_post',
      params: {'p_post_id': postId, 'p_decision': decision.name},
    );
    if (response is! Map) {
      throw const FormatException('Invalid community moderation result');
    }
    return CommunityPostModerationResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> removePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    if (!const {
      'spam',
      'abuse',
      'misleading',
      'privacy',
      'unsafe_or_inappropriate',
      'other',
    }.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    await _client.rpc(
      'bil_remove_published_community_post',
      params: {'p_post_id': postId, 'p_reason': reason},
    );
  }

  Future<void> hidePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) => _moderatePublishedPost(postId: postId, action: 'hide', reason: reason);

  Future<void> restoreHiddenPostAsModerator({required String postId}) =>
      _moderatePublishedPost(postId: postId, action: 'restore');

  Future<void> _moderatePublishedPost({
    required String postId,
    required String action,
    String? reason,
  }) async {
    if (!_uuid.hasMatch(postId)) throw ArgumentError.value(postId, 'postId');
    const reasons = {
      'spam',
      'abuse',
      'misleading',
      'privacy',
      'unsafe_or_inappropriate',
      'other',
    };
    if (action != 'restore' && !reasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    await _client.rpc(
      'bil_moderate_published_community_post',
      params: {'p_post_id': postId, 'p_action': action, 'p_reason': reason},
    );
  }

  Future<List<CommunityPost>> loadHiddenPostsForModeration({
    int limit = 100,
  }) async {
    final response = await _client.rpc(
      'bil_list_hidden_community_posts',
      params: {'p_limit': limit.clamp(1, 100)},
    );
    if (response is! List) {
      throw const FormatException('Invalid hidden Community posts result');
    }
    return response
        .whereType<Map>()
        .map((row) => CommunityPost.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> publishPost(String body) async {
    await assertCommunityPublishReady();
    await _runCommunityMutation(() => _posts.publishText(body));
  }

  Future<void> publishPostWithTopics(
    String body, {
    required List<String> topicSlugs,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    if (topicSlugs.isEmpty) {
      await _runCommunityMutation(() => _posts.publishText(body));
      return;
    }

    final store = _posts;
    if (store is! CommunityPostPublishingReceiptContract) {
      throw StateError('Community topic publishing receipt is unavailable');
    }
    final receiptStore = store as CommunityPostPublishingReceiptContract;
    final postId = await _runCommunityMutation(
      () => receiptStore.publishTextWithReceipt(body),
    );
    if (postId == null) return;
    try {
      await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
    } on Object {
      try {
        await store.delete(postId);
      } on Object {
        // The pending post is still private if best-effort cleanup fails.
      }
      rethrow;
    }
  }

  Future<void> publishPostWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    // Run the server guard before CommunityPostCloudStore sends image bytes.
    // Storage and the post INSERT keep their own server guards for race
    // protection. If Storage hides an RLS reason behind its generic error,
    // re-read the authoritative guard so the UI can explain the current block.
    await assertCommunityPublishReady();
    try {
      await _runCommunityMutation(() => _posts.publishWithImage(body, image));
    } on StorageException catch (error, stackTrace) {
      await _rethrowPolicyStateAfterStorageFailure(error, stackTrace);
    }
  }

  Future<void> publishPostWithImageAndTopics(
    String body,
    CommunityPostImageDraft image, {
    required List<String> topicSlugs,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    try {
      if (topicSlugs.isEmpty) {
        await _runCommunityMutation(() => _posts.publishWithImage(body, image));
        return;
      }

      final store = _posts;
      if (store is! CommunityPostPublishingReceiptContract) {
        throw StateError('Community topic publishing receipt is unavailable');
      }
      final receiptStore = store as CommunityPostPublishingReceiptContract;
      final postId = await _runCommunityMutation(
        () => receiptStore.publishWithImageReceipt(body, image),
      );
      if (postId == null) return;
      try {
        await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
      } on Object {
        try {
          await store.delete(postId);
        } on Object {
          // The pending post is still private if best-effort cleanup fails.
        }
        rethrow;
      }
    } on StorageException catch (error, stackTrace) {
      await _rethrowPolicyStateAfterStorageFailure(error, stackTrace);
    }
  }

  Future<void> publishPostWithTopicsAndCircle(
    String body, {
    List<String> topicSlugs = const [],
    String? circleSlug,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);

    if (topicSlugs.isEmpty && circleSlug == null) {
      await _runCommunityMutation(() => _posts.publishText(body));
      return;
    }

    final store = _posts;
    if (store is! CommunityPostPublishingReceiptContract) {
      throw StateError('Community post publishing receipt is unavailable');
    }
    final receiptStore = store as CommunityPostPublishingReceiptContract;
    final postId = await _runCommunityMutation(
      () => receiptStore.publishTextWithReceipt(body),
    );
    if (postId == null) return;
    try {
      if (topicSlugs.isNotEmpty) {
        await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
      }
      if (circleSlug != null) {
        await setMyCommunityPostCircle(postId: postId, slug: circleSlug);
      }
    } on Object {
      try {
        await store.delete(postId);
      } on Object {
        // The moderation-pending post remains non-public if cleanup fails.
      }
      rethrow;
    }
  }

  Future<void> publishPostWithTopicsCircleAndPoll(
    String body, {
    List<String> topicSlugs = const [],
    String? circleSlug,
    required CommunityPollDraft poll,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);
    final normalizedPoll = poll.normalized();

    final store = _posts;
    if (store is! CommunityPostPublishingReceiptContract) {
      throw StateError('Community poll publishing receipt is unavailable');
    }
    final receiptStore = store as CommunityPostPublishingReceiptContract;
    final postId = await _runCommunityMutation(
      () => receiptStore.publishTextWithReceipt(body),
    );
    if (postId == null) return;

    try {
      if (topicSlugs.isNotEmpty) {
        await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
      }
      if (circleSlug != null) {
        await setMyCommunityPostCircle(postId: postId, slug: circleSlug);
      }
      await createCommunityPoll(postId: postId, draft: normalizedPoll);
    } on Object {
      try {
        await store.delete(postId);
      } on Object {
        // The moderation-pending post remains non-public if cleanup fails.
      }
      rethrow;
    }
  }

  Future<void> publishPostWithImageTopicsAndCircle(
    String body,
    CommunityPostImageDraft image, {
    List<String> topicSlugs = const [],
    String? circleSlug,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);

    if (topicSlugs.isEmpty && circleSlug == null) {
      await publishPostWithImage(body, image);
      return;
    }

    final store = _posts;
    if (store is! CommunityPostPublishingReceiptContract) {
      throw StateError('Community post publishing receipt is unavailable');
    }
    final receiptStore = store as CommunityPostPublishingReceiptContract;
    try {
      final postId = await _runCommunityMutation(
        () => receiptStore.publishWithImageReceipt(body, image),
      );
      if (postId == null) return;
      try {
        if (topicSlugs.isNotEmpty) {
          await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
        }
        if (circleSlug != null) {
          await setMyCommunityPostCircle(postId: postId, slug: circleSlug);
        }
      } on Object {
        try {
          await store.delete(postId);
        } on Object {
          // The moderation-pending post remains non-public if cleanup fails.
        }
        rethrow;
      }
    } on StorageException catch (error, stackTrace) {
      await _rethrowPolicyStateAfterStorageFailure(error, stackTrace);
    }
  }

  Future<void> publishPostWithImageTopicsCircleAndPoll(
    String body,
    CommunityPostImageDraft image, {
    List<String> topicSlugs = const [],
    String? circleSlug,
    required CommunityPollDraft poll,
  }) async {
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);
    final normalizedPoll = poll.normalized();

    final store = _posts;
    if (store is! CommunityPostPublishingReceiptContract) {
      throw StateError('Community poll publishing receipt is unavailable');
    }
    final receiptStore = store as CommunityPostPublishingReceiptContract;
    try {
      final postId = await _runCommunityMutation(
        () => receiptStore.publishWithImageReceipt(body, image),
      );
      if (postId == null) return;

      try {
        if (topicSlugs.isNotEmpty) {
          await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
        }
        if (circleSlug != null) {
          await setMyCommunityPostCircle(postId: postId, slug: circleSlug);
        }
        await createCommunityPoll(postId: postId, draft: normalizedPoll);
      } on Object {
        try {
          await store.delete(postId);
        } on Object {
          // The moderation-pending post remains non-public if cleanup fails.
        }
        rethrow;
      }
    } on StorageException catch (error, stackTrace) {
      await _rethrowPolicyStateAfterStorageFailure(error, stackTrace);
    }
  }

  void _validateCircleSlug(String? slug) {
    if (slug != null &&
        (slug.length > 48 || !CommunityCircle.slugPattern.hasMatch(slug))) {
      throw ArgumentError.value(slug, 'circleSlug');
    }
  }

  void _validateTopicSlugs(List<String> slugs) {
    if (slugs.length > 3 ||
        slugs.toSet().length != slugs.length ||
        slugs.any(
          (slug) =>
              slug.length > 48 || !CommunityTopic.slugPattern.hasMatch(slug),
        )) {
      throw ArgumentError('Invalid Community post topics');
    }
  }

  Future<List<Map<String, dynamic>>> loadFriendships() async {
    return await _client
        .from('bil_friendships')
        .select()
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    final response = await _client.rpc('bil_list_community_connections');
    if (response is! List) {
      throw const FormatException('Invalid community connections result');
    }
    return response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where((row) {
          final id = row['id'];
          final requester = row['requester_id'];
          final addressee = row['addressee_id'];
          final status = row['status'];
          final otherUserId = row['other_user_id'];
          final displayName = row['display_name'];
          final avatarUrl = row['avatar_url'];
          return id is String &&
              _uuid.hasMatch(id) &&
              requester is String &&
              _uuid.hasMatch(requester) &&
              addressee is String &&
              _uuid.hasMatch(addressee) &&
              (requester == _user.id || addressee == _user.id) &&
              status is String &&
              const {'pending', 'accepted'}.contains(status) &&
              otherUserId is String &&
              _uuid.hasMatch(otherUserId) &&
              (displayName == null ||
                  (displayName is String &&
                      displayName.trim().length >= 2 &&
                      displayName.trim().length <= 60 &&
                      !_unsafeText.hasMatch(displayName))) &&
              (avatarUrl == null || avatarUrl is String);
        })
        .map((row) {
          return {
            ...row,
            'profile': {
              'display_name': row['display_name'],
              'avatar_url': row['avatar_url'],
            },
          };
        })
        .toList(growable: false);
  }

  Future<List<CommunityNotification>> loadCommunityNotifications({
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    final response = await _client.rpc(
      'bil_list_community_activity_v2',
      params: {
        'p_before': null,
        'p_before_id': null,
        'p_kinds': null,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community notifications result');
    }
    return List<CommunityNotification>.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid Community notification');
        }
        return CommunityNotification.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }

  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return 0;
    if (unique.length > 100 || unique.any((id) => !_uuid.hasMatch(id))) {
      throw ArgumentError.value(ids, 'ids');
    }
    final response = await _client.rpc(
      'bil_mark_community_activity_seen_v2',
      params: {'p_ids': unique},
    );
    if (response is! int || response < 0 || response > unique.length) {
      throw const FormatException('Invalid Community seen result');
    }
    return response;
  }

  Future<void> follow(String userId) =>
      _client.rpc('bil_follow_member', params: {'p_followed_id': userId});

  Future<void> unfollow(String userId) =>
      _client.rpc('bil_unfollow_member', params: {'p_followed_id': userId});

  Future<void> respondToFriendship(String id, {required bool accept}) async {
    if (!_uuid.hasMatch(id)) throw ArgumentError.value(id, 'id');
    final changed = await _client
        .from('bil_friendships')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('addressee_id', _user.id)
        .eq('status', 'pending')
        .select('id');
    if (changed.length != 1) {
      throw StateError('Friend request was not available to update');
    }
  }

  Future<void> removeFriendship(String id) async {
    if (!_uuid.hasMatch(id)) throw ArgumentError.value(id, 'id');
    final changed = await _client
        .from('bil_friendships')
        .delete()
        .eq('id', id)
        .or('requester_id.eq.${_user.id},addressee_id.eq.${_user.id}')
        .select('id');
    if (changed.length != 1) {
      throw StateError('Friendship was not available to remove');
    }
  }

  Future<void> blockMember(String userId) async {
    await _client.rpc(
      'bil_block_community_member',
      params: {'p_blocked_id': userId},
    );
  }

  Future<List<CommunityMessage>> loadMessages(String otherUserId) async {
    final userId = _user.id;
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .or(
          'and(sender_id.eq.$userId,recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.$userId)',
        )
        .order('created_at')
        .order('id');
    final messages = rows
        .map((row) => CommunityMessage.fromJson(row))
        .toList(growable: true);
    // Keep the conversation transcript chronological even if an edge/cache
    // returns rows outside the requested order. The chat viewport is reversed
    // so this places the newest message at the latest (bottom) end.
    messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime == 0 ? left.id.compareTo(right.id) : byTime;
    });
    return List<CommunityMessage>.unmodifiable(messages);
  }

  Stream<void> watchConversationChanges(String otherUserId) {
    final currentUserId = _user.id;
    if (!_uuid.hasMatch(otherUserId) || otherUserId == currentUserId) {
      throw ArgumentError.value(otherUserId, 'otherUserId');
    }

    Stream<void> changesWhere(String column) => _client
        .from('bil_messages')
        .stream(primaryKey: const ['id'])
        .eq(column, otherUserId)
        .order('created_at')
        .order('id')
        .limit(1)
        .map<void>((_) {});

    final streams = <Stream<void>>[
      // With message RLS, these are respectively other -> current and
      // current -> other. No rows from unrelated conversations are visible.
      changesWhere('sender_id'),
      changesWhere('recipient_id'),
    ];
    final subscriptions = <StreamSubscription<void>>[];
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(
              (_) => controller.add(null),
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> loadInboxMessages() async {
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .eq('recipient_id', _user.id)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return _enrichMessageRows(rows, profileKey: 'sender_id');
  }

  Stream<void> watchInboxChanges() => _client
      .from('bil_messages')
      .stream(primaryKey: const ['id'])
      .eq('recipient_id', _user.id)
      .order('created_at')
      .limit(1)
      .map<void>((_) {});

  Future<List<Map<String, dynamic>>> loadSentMessages() async {
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .eq('sender_id', _user.id)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return _enrichMessageRows(rows, profileKey: 'recipient_id');
  }

  Future<List<Map<String, dynamic>>> _enrichMessageRows(
    List<Map<String, dynamic>> rows, {
    required String profileKey,
  }) async {
    final currentUserId = _user.id;
    final validRows = rows
        .where((row) {
          final id = row['id'];
          final sender = row['sender_id'];
          final recipient = row['recipient_id'];
          final body = row['body'];
          final createdAt = row['created_at'];
          final parsedAt = createdAt is String
              ? DateTime.tryParse(createdAt)
              : null;
          final envelopeValid = body is String && _validMessageEnvelope(body);
          final ownsRow = profileKey == 'sender_id'
              ? recipient == currentUserId
              : sender == currentUserId;
          return id is String &&
              _uuid.hasMatch(id) &&
              sender is String &&
              _uuid.hasMatch(sender) &&
              recipient is String &&
              _uuid.hasMatch(recipient) &&
              ownsRow &&
              envelopeValid &&
              parsedAt != null;
        })
        .toList(growable: false);
    if (validRows.isEmpty) return const [];
    final ids = validRows
        .map((row) => row[profileKey] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url')
        .inFilter('user_id', ids);
    final byId = <String, Map<String, dynamic>>{};
    for (final row in profiles) {
      final id = row['user_id'];
      final name = row['display_name'];
      final avatar = row['avatar_url'];
      if (id is String &&
          _uuid.hasMatch(id) &&
          name is String &&
          name.trim().isNotEmpty &&
          name.length <= 60 &&
          (avatar == null || avatar is String)) {
        byId[id] = row;
      }
    }
    return validRows
        .map((row) => {...row, 'profile': byId[row[profileKey]]})
        .toList(growable: false);
  }

  static bool _validMessageEnvelope(String body) {
    if (body.trim().isEmpty ||
        body.length > 4200 ||
        _unsafeText.hasMatch(body)) {
      return false;
    }
    const marker = '[BIL-SUBJECT]';
    if (!body.startsWith(marker)) return true;
    final newline = body.indexOf('\n');
    if (newline < 0) return false;
    final subject = body.substring(marker.length, newline);
    final message = body.substring(newline + 1);
    return subject.length <= 120 &&
        message.trim().isNotEmpty &&
        message.length <= 4000;
  }

  Future<void> sendMessage(String recipientId, String body) async {
    if (!_uuid.hasMatch(recipientId) || recipientId == _user.id) {
      throw ArgumentError.value(recipientId, 'recipientId');
    }
    final text = body.trim();
    if (text.isEmpty || text.length > 4200 || _unsafeText.hasMatch(text)) {
      throw ArgumentError.value(body, 'body');
    }
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.message);
    await _requireAcceptedContentPolicy();
    await _runCommunityMutation(
      () => _client.from('bil_messages').insert({
        'sender_id': _user.id,
        'recipient_id': recipientId,
        'body': text,
      }),
    );
  }

  Future<void> deleteMessage(String messageId) =>
      _client.rpc('bil_delete_message', params: {'p_message_id': messageId});

  Future<void> acceptContentPolicy(String version) => _client
      .from('bil_content_policy_acceptances')
      .upsert({'user_id': _user.id, 'policy_version': version});

  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    if (localeCode.trim().isEmpty) {
      throw ArgumentError.value(localeCode, 'localeCode');
    }
    final response = await _client.rpc('bil_current_community_policy_status');
    if (response is! Map) {
      throw const FormatException('Invalid Community policy status payload');
    }
    return CommunityPolicyState.fromServerSnapshot(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> _requireAcceptedContentPolicy() async {
    late final CommunityPolicyState state;
    try {
      // The production policy is a single canonical row. English is also the
      // repository's documented fallback when a localized row is unavailable.
      state = await loadCommunityPolicyState(localeCode: 'en');
    } on CommunityPolicyAccessException {
      rethrow;
    } on Object {
      throw const CommunityPolicyAccessException(
        failure: CommunityPolicyAccessFailure.verificationFailed,
      );
    }

    switch (state.status) {
      case CommunityPolicyStatus.unavailable:
        throw const CommunityPolicyAccessException(
          failure: CommunityPolicyAccessFailure.unavailable,
        );
      case CommunityPolicyStatus.acceptanceRequired:
        throw CommunityPolicyAccessException(
          failure: CommunityPolicyAccessFailure.acceptanceRequired,
          policyVersion: state.policy?.version,
        );
      case CommunityPolicyStatus.accepted:
        if (state.permitsCommunityPublishing) return;
        throw const CommunityPolicyAccessException(
          failure: CommunityPolicyAccessFailure.verificationFailed,
        );
    }
  }

  /// Performs the server-side membership and exact-policy-receipt assertion.
  ///
  /// This deliberately runs before an image store can send any bytes. The
  /// database INSERT guards repeat the checks to cover a state change between
  /// this preflight and the eventual post mutation.
  Future<void> assertCommunityPublishReady() => _runCommunityMutation(() async {
    await _client.rpc('bil_assert_community_publish_ready');
  });

  Future<Never> _rethrowPolicyStateAfterStorageFailure(
    StorageException error,
    StackTrace stackTrace,
  ) async {
    try {
      await assertCommunityPublishReady();
    } on CommunityPolicyAccessException catch (policyError, policyStackTrace) {
      Error.throwWithStackTrace(policyError, policyStackTrace);
    } on CommunityMembershipAccessException catch (
      membershipError,
      membershipStackTrace
    ) {
      Error.throwWithStackTrace(membershipError, membershipStackTrace);
    } on Object {
      // A diagnostic read failure must not replace the original Storage error.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  Future<T> _runCommunityMutation<T>(Future<T> Function() mutation) async {
    try {
      return await mutation();
    } on PostgrestException catch (error, stackTrace) {
      final message = error.message.toLowerCase();
      final policyFailure = switch (message) {
        'community_policy_unavailable' =>
          CommunityPolicyAccessFailure.unavailable,
        'community_policy_acceptance_required' =>
          CommunityPolicyAccessFailure.acceptanceRequired,
        _ => null,
      };
      if (policyFailure != null) {
        Error.throwWithStackTrace(
          CommunityPolicyAccessException(failure: policyFailure),
          stackTrace,
        );
      }
      final membershipFailure = switch (message) {
        'community_access_suspended' =>
          CommunityMembershipAccessFailure.suspended,
        'community_relationship_blocked' =>
          CommunityMembershipAccessFailure.relationshipBlocked,
        _ => null,
      };
      if (membershipFailure != null) {
        Error.throwWithStackTrace(
          CommunityMembershipAccessException(failure: membershipFailure),
          stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadOpenModerationReports() async {
    final response = await _client.rpc('bil_list_open_community_reports');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> moderateReport({
    required String reportId,
    required String resolution,
    String action = 'none',
  }) => _client.rpc(
    'bil_moderate_community_report',
    params: {
      'p_report_id': reportId,
      'p_resolution': resolution,
      'p_action': action,
    },
  );

  Future<void> requestAccountDeletion({String? reason}) => _client.rpc(
    'bil_request_account_deletion',
    params: {'p_reason': reason?.trim()},
  );

  Future<void> markConversationRead(String otherUserId) async {
    await _client.rpc(
      'bil_mark_conversation_read',
      params: {'p_sender_id': otherUserId},
    );
  }

  Future<void> deletePost(String postId) => _posts.delete(postId);

  Future<List<Map<String, dynamic>>> loadReviewableFoods() async {
    final response = await _client.rpc('bil_list_reviewable_products');
    return (response as List)
        .cast<Map<String, dynamic>>()
        .take(40)
        .toList(growable: false);
  }

  Future<void> reviewFood({
    required String submissionId,
    required String verdict,
    String? note,
  }) async {
    CommunityTextPolicy.enforceAll({CommunityTextSurface.peerReviewNote: note});
    await _client.from('bil_food_peer_reviews').upsert({
      'submission_id': submissionId,
      'reviewer_id': _user.id,
      'verdict': verdict,
      'note': note?.trim(),
    }, onConflict: 'submission_id,reviewer_id');
  }

  Future<void> finalizeFoodSubmission({
    required String submissionId,
    required String decision,
  }) async {
    await _client.rpc(
      'bil_finalize_food_submission',
      params: {'submission_id': submissionId, 'decision': decision},
    );
  }

  Future<void> submitFood(CommunityFoodDraft draft) async {
    if (!draft.servingGrams.isFinite ||
        draft.servingGrams <= 0 ||
        !draft.calories.isFinite ||
        draft.calories < 0 ||
        !draft.protein.isFinite ||
        draft.protein < 0 ||
        !draft.carbohydrate.isFinite ||
        draft.carbohydrate < 0 ||
        !draft.fat.isFinite ||
        draft.fat < 0) {
      throw const FormatException('Invalid community food values');
    }
    CommunityTextPolicy.enforce(
      draft.name,
      surface: CommunityTextSurface.foodName,
    );
    await _client.from('bil_community_food_submissions').insert({
      'contributor_id': _user.id,
      'canonical_name': draft.name.trim(),
      'localized_names': {'ar': draft.name.trim()},
      'serving_grams': draft.servingGrams,
      'calories_kcal': draft.calories,
      'protein_g': draft.protein,
      'carbohydrate_g': draft.carbohydrate,
      'fat_g': draft.fat,
      'barcode': draft.barcode,
      'country_code': draft.countryCode,
      'evidence_url': draft.evidenceUrl,
      'product_kind': 'food',
      'submission_source': 'user_submission',
      'submission_confidence': 'low',
      'status': 'pending',
    });
  }

  Future<void> submitProductReview(ProductReviewDraft draft) async {
    String? optional(String? value) {
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    }

    final brand = optional(draft.brand);
    final note = optional(draft.note);
    CommunityTextPolicy.enforceAll({
      CommunityTextSurface.foodName: draft.name,
      CommunityTextSurface.foodBrand: brand,
      CommunityTextSurface.foodReviewNote: note,
    });

    await _client.from('bil_community_food_submissions').insert({
      'contributor_id': _user.id,
      'canonical_name': draft.name.trim(),
      'localized_names': <String, String>{},
      'barcode': draft.barcode.trim(),
      'brand': brand,
      'product_kind': productKindWireValue(draft.kind),
      'country_code': optional(draft.countryCode)?.toUpperCase(),
      'evidence_url': optional(draft.evidenceUrl),
      'review_note': note,
      'submission_source': 'user_submission',
      'submission_confidence': 'low',
      'observed_source': optional(draft.observedSource),
      'observed_confidence': draft.observedConfidence == null
          ? null
          : productConfidenceWireValue(draft.observedConfidence!),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async {
    return await _client
        .from('bil_community_food_submissions')
        .select()
        .eq('contributor_id', _user.id)
        .order('created_at', ascending: false);
  }

  Future<void> report({
    required String targetKind,
    required String targetId,
    required String reason,
  }) async {
    await _client.from('bil_community_reports').insert({
      'reporter_id': _user.id,
      'target_kind': targetKind,
      'target_id': targetId,
      'reason': reason.trim(),
    });
  }
}
