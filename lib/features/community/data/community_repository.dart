import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
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

  Future<CommunityProfile?> loadMyProfile() async {
    final row = await _client
        .from('bil_public_profiles')
        .select(
          'user_id,display_name,avatar_url,bio,locale_code,discoverable,profile_visibility,allow_friend_requests,allow_follows,allow_messages_from',
        )
        .eq('user_id', _user.id)
        .maybeSingle();
    return row == null ? null : CommunityProfile.fromJson(row);
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

  Future<void> publishPost(String body) async {
    await assertCommunityPublishReady();
    await _runCommunityMutation(() => _posts.publishText(body));
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
              displayName is String &&
              displayName.trim().length >= 2 &&
              displayName.trim().length <= 60 &&
              !_unsafeText.hasMatch(displayName) &&
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
        .order('created_at');
    return rows
        .map((row) => CommunityMessage.fromJson(row))
        .toList(growable: false);
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
