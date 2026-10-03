import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../domain/community_attention.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_models.dart';
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
    if (!_uuid.hasMatch(postId) ||
        slugs.length > 3 ||
        slugs.toSet().length != slugs.length ||
        slugs.any(
          (slug) =>
              slug.length > 48 || !CommunityTopic.slugPattern.hasMatch(slug),
        )) {
      throw ArgumentError('Invalid Community post topics');
    }
    final response = await _client.rpc(
      'bil_set_my_community_post_topics_v1',
      params: {'p_post_id': postId, 'p_slugs': slugs},
    );
    if (response is! num || response.toInt() != slugs.length) {
      throw const FormatException('Invalid Community post topic result');
    }
  }

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