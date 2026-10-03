import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../domain/community_attention.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_circles.dart';
import '../domain/community_feed_modes.dart';
import '../domain/community_models.dart';
import '../domain/community_polls.dart';
import '../domain/community_post_context.dart';
import '../domain/community_referral.dart';
import '../domain/community_rewards.dart';
import '../domain/community_text_policy.dart';
import '../domain/community_topics.dart';
import '../services/community_post_image_picker.dart';
import 'community_post_cloud_store.dart';
import 'community_feed_repository_mixin.dart';
import 'community_social_repository_mixin.dart';

part 'community_repository_connections_messaging_mixin.dart';
part 'community_repository_discovery_mixin.dart';
part 'community_repository_profile_moderation_mixin.dart';
part 'community_repository_publishing_mixin.dart';

class CommunityRepository
    with
        CommunitySocialRepositoryMixin,
        CommunityFeedRepositoryMixin,
        _CommunityDiscoveryRepositoryMixin,
        _CommunityProfileModerationRepositoryMixin,
        _CommunityPublishingRepositoryMixin,
        _CommunityConnectionsMessagingRepositoryMixin {
  CommunityRepository(this._client, {CommunityPostStoreContract? postStore})
    // Keep the public injection seam named `postStore` while its field stays private.
    // ignore: prefer_initializing_formals
    : _postStore = postStore;

  @override
  final SupabaseClient _client;
  final CommunityPostStoreContract? _postStore;

  @override
  SupabaseClient get communitySocialClient => _client;

  @override
  CommunityPostStoreContract get communityPostStore => _posts;

  @override
  bool get useServerRankedCommunityFeed =>
      _postStore == null && _client.auth.currentUser != null;

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

  @override
  String get currentUserId => _user.id;

  @override
  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign-in required');
    return user;
  }

  @override
  CommunityPostStoreContract get _posts =>
      _postStore ?? CommunityPostCloudStore(_client, _user);

  @override
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
  @override
  Future<void> assertCommunityPublishReady() => _runCommunityMutation(() async {
    await _client.rpc('bil_assert_community_publish_ready');
  });

  @override
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

  @override
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
