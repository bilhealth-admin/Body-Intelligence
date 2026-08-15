import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../domain/community_models.dart';

class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _unsafeText = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  String get currentUserId => _user.id;

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final text = query.trim();
    var request = _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url,bio,locale_code')
        .neq('user_id', _user.id)
        .eq('discoverable', true);
    if (text.isNotEmpty) request = request.ilike('display_name', '%$text%');
    final rows = await request.order('display_name').limit(30);
    return rows
        .where((row) {
          final id = row['user_id'];
          final name = row['display_name'];
          final avatar = row['avatar_url'];
          final bio = row['bio'];
          return id is String &&
              _uuid.hasMatch(id) &&
              name is String &&
              name.trim().length >= 2 &&
              name.trim().length <= 60 &&
              !_unsafeText.hasMatch(name) &&
              (avatar == null || avatar is String) &&
              (bio == null ||
                  (bio is String &&
                      bio.length <= 280 &&
                      !_unsafeText.hasMatch(bio)));
        })
        .toList(growable: false);
  }

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign-in required');
    return user;
  }

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

  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    final rows = await _client
        .from('bil_community_posts')
        .select('id,author_id,body,created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    if (rows.isEmpty) return const [];
    final authorIds = rows
        .map((row) => row['author_id'] as String)
        .toSet()
        .toList(growable: false);
    final profiles = await _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url')
        .inFilter('user_id', authorIds);
    final profilesById = {
      for (final profile in profiles) profile['user_id'] as String: profile,
    };
    return rows
        .map((row) {
          final profile = profilesById[row['author_id'] as String];
          return CommunityPost.fromJson({
            ...row,
            'author_name': profile?['display_name'],
            'author_avatar_url': profile?['avatar_url'],
          });
        })
        .toList(growable: false);
  }

  Future<void> publishPost(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _client.from('bil_community_posts').insert({
      'author_id': _user.id,
      'body': text,
      'visibility': 'community',
    });
  }

  Future<List<Map<String, dynamic>>> loadFriendships() async {
    return await _client
        .from('bil_friendships')
        .select()
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    final friendships = (await loadFriendships())
        .where((row) {
          final id = row['id'];
          final requester = row['requester_id'];
          final addressee = row['addressee_id'];
          final status = row['status'];
          return id is String &&
              _uuid.hasMatch(id) &&
              requester is String &&
              _uuid.hasMatch(requester) &&
              addressee is String &&
              _uuid.hasMatch(addressee) &&
              (requester == _user.id || addressee == _user.id) &&
              status is String &&
              const {'pending', 'accepted'}.contains(status);
        })
        .toList(growable: false);
    if (friendships.isEmpty) return const [];
    final myId = _user.id;
    final ids = friendships
        .map(
          (row) => row['requester_id'] == myId
              ? row['addressee_id'] as String
              : row['requester_id'] as String,
        )
        .toSet()
        .toList();
    final profiles = await _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url,bio')
        .inFilter('user_id', ids);
    final byId = <String, Map<String, dynamic>>{};
    for (final row in profiles) {
      final id = row['user_id'];
      if (id is String && _uuid.hasMatch(id)) byId[id] = row;
    }
    return friendships
        .map((row) {
          final otherId = row['requester_id'] == myId
              ? row['addressee_id'] as String
              : row['requester_id'] as String;
          return {...row, 'other_user_id': otherId, 'profile': byId[otherId]};
        })
        .toList(growable: false);
  }

  Future<void> requestFriend(String addresseeId) async {
    await _client.rpc(
      'bil_request_friendship',
      params: {'p_addressee_id': addresseeId},
    );
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

  Future<List<Map<String, dynamic>>> loadInboxMessages() async {
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .eq('recipient_id', _user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return _enrichMessageRows(rows, profileKey: 'sender_id');
  }

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
    await _client.from('bil_messages').insert({
      'sender_id': _user.id,
      'recipient_id': recipientId,
      'body': text,
    });
  }

  Future<void> deleteMessage(String messageId) =>
      _client.rpc('bil_delete_message', params: {'p_message_id': messageId});

  Future<void> acceptContentPolicy(String version) => _client
      .from('bil_content_policy_acceptances')
      .upsert({'user_id': _user.id, 'policy_version': version});

  Future<Map<String, dynamic>?> loadActiveContentPolicy({
    required String localeCode,
  }) async {
    final preferred = await _client
        .from('bil_content_policies')
        .select('version,locale_code,document_url,effective_at')
        .eq('active', true)
        .eq('locale_code', localeCode)
        .order('effective_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (preferred != null) return preferred;
    return _client
        .from('bil_content_policies')
        .select('version,locale_code,document_url,effective_at')
        .eq('active', true)
        .eq('locale_code', 'en')
        .order('effective_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<bool> hasAcceptedContentPolicy(String version) async {
    final row = await _client
        .from('bil_content_policy_acceptances')
        .select('policy_version')
        .eq('user_id', _user.id)
        .eq('policy_version', version)
        .maybeSingle();
    return row != null;
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

  Future<void> deletePost(String postId) async {
    await _client
        .from('bil_community_posts')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', postId)
        .eq('author_id', _user.id);
  }

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

    await _client.from('bil_community_food_submissions').insert({
      'contributor_id': _user.id,
      'canonical_name': draft.name.trim(),
      'localized_names': <String, String>{},
      'barcode': draft.barcode.trim(),
      'brand': optional(draft.brand),
      'product_kind': productKindWireValue(draft.kind),
      'country_code': optional(draft.countryCode)?.toUpperCase(),
      'evidence_url': optional(draft.evidenceUrl),
      'review_note': optional(draft.note),
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
