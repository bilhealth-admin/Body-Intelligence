part of 'community_repository.dart';

mixin _CommunityComposerPersistenceRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  Future<void> assertCommunityPublishReady();

  static const _draftBucket = 'community-post-images';
  static const _uuidGenerator = Uuid();

  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async {
    if (postIds.isEmpty) return const <CommunityPostReferenceMetadata>[];
    if (postIds.length > 100 ||
        postIds.toSet().length != postIds.length ||
        postIds.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    final response = await _client.rpc(
      'bil_community_post_reference_metadata_v1',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException(
        'Invalid Community post reference metadata batch',
      );
    }
    return List<CommunityPostReferenceMetadata>.unmodifiable(
      response.map((raw) {
        if (raw is! Map) {
          throw const FormatException(
            'Invalid Community post reference metadata row',
          );
        }
        return CommunityPostReferenceMetadata.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }),
    );
  }

  Future<void> setMyCommunityPostReferenceMetadata({
    required String postId,
    String? title,
    List<String> hashtags = const <String>[],
    List<String> collaboratorUserIds = const <String>[],
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId) ||
        collaboratorUserIds.length > 3 ||
        collaboratorUserIds.toSet().length != collaboratorUserIds.length ||
        collaboratorUserIds.any(
          (id) => !CommunityRepository._uuid.hasMatch(id),
        )) {
      throw ArgumentError('Invalid Community post reference metadata');
    }
    final response = await _client.rpc(
      'bil_set_my_community_post_reference_metadata_v1',
      params: {
        'p_post_id': postId,
        'p_title': title?.trim(),
        'p_hashtags': hashtags,
        'p_collaborator_user_ids': collaboratorUserIds,
      },
    );
    if (response is! Map) {
      throw const FormatException(
        'Invalid Community post reference metadata receipt',
      );
    }
    final json = Map<String, dynamic>.from(response);
    if (json['post_id'] != postId ||
        json['hashtag_count'] != hashtags.length ||
        json['collaborator_count'] != collaboratorUserIds.length) {
      throw const FormatException(
        'Community post reference metadata mismatch',
      );
    }
  }

  Future<CommunityCollaborationStatus> respondCommunityCollaboration({
    required String postId,
    required bool accept,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final response = await _client.rpc(
      'bil_respond_community_collaboration_v1',
      params: {'p_post_id': postId, 'p_accept': accept},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community collaboration response');
    }
    final json = Map<String, dynamic>.from(response);
    if (json['post_id'] != postId) {
      throw const FormatException('Community collaboration post mismatch');
    }
    return CommunityCollaborationStatus.fromWire(json['status']);
  }

  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    if ((before == null) != (beforeId == null) ||
        (beforeId != null &&
            !CommunityRepository._uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 50) {
      throw ArgumentError('Invalid Community draft cursor');
    }
    final response = await _client.rpc(
      'bil_list_my_community_post_drafts_v1',
      params: {
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community draft list');
    }
    return List<CommunityDraftSummary>.unmodifiable(
      response.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid Community draft row');
        }
        return CommunityDraftSummary.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }),
    );
  }

  Future<({CommunityPersistentDraft draft, List<CommunityPostImageDraft> images})>
  loadMyCommunityDraft(String draftId) async {
    if (!CommunityRepository._uuid.hasMatch(draftId)) {
      throw ArgumentError.value(draftId, 'draftId');
    }
    final response = await _client.rpc(
      'bil_get_my_community_post_draft_v1',
      params: {'p_draft_id': draftId},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community draft');
    }
    final draft = CommunityPersistentDraft.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (draft.draftId != draftId) {
      throw const FormatException('Community draft id mismatch');
    }

    final images = <CommunityPostImageDraft>[];
    for (final media in draft.media) {
      final bytes = await _client.storage
          .from(_draftBucket)
          .download(media.objectPath);
      final image = await validateCommunityPostImageAsync(bytes);
      if (image.mimeType != media.mimeType ||
          image.byteLength != media.bytes ||
          image.width != media.width ||
          image.height != media.height) {
        throw const FormatException('Community draft media mismatch');
      }
      images.add(image);
    }
    return (
      draft: draft,
      images: List<CommunityPostImageDraft>.unmodifiable(images),
    );
  }

  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(input.draftId) ||
        images.length > 4) {
      throw ArgumentError('Invalid Community draft');
    }
    await assertCommunityPublishReady();

    final draftId = await _client.rpc(
      'bil_upsert_my_community_post_draft_v1',
      params: {
        'p_draft_id': input.draftId,
        'p_title': input.title?.trim(),
        'p_body': input.body,
        'p_topic_slugs': input.topicSlugs,
        'p_circle_slug': input.circleSlug,
        'p_location_label': input.locationLabel,
        'p_mentioned_user_ids': [
          for (final value in input.mentions) value.userId,
        ],
        'p_collaborator_user_ids': [
          for (final value in input.collaborators) value.userId,
        ],
        'p_hashtags': input.hashtags,
        'p_poll_question': input.pollQuestion,
        'p_poll_options': input.pollOptions,
        'p_poll_allow_multiple': input.pollAllowMultiple,
      },
    );
    if (draftId != input.draftId) {
      throw const FormatException('Invalid Community draft save receipt');
    }

    final validated = <CommunityPostImageDraft>[];
    for (final image in images) {
      validated.add(await validateCommunityPostImageAsync(image.bytes));
    }

    final uploaded = <String>[];
    try {
      final items = <Map<String, Object>>[];
      for (final image in validated) {
        final objectId = _uuidGenerator.v4();
        final path =
            '${_user.id}/${input.draftId}/$objectId.${image.extension}';
        await _client.storage
            .from(_draftBucket)
            .uploadBinary(
              path,
              image.bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: image.mimeType,
                cacheControl: '86400',
              ),
            );
        uploaded.add(path);
        items.add({
          'object_path': path,
          'mime_type': image.mimeType,
          'bytes': image.byteLength,
          'width': image.width,
          'height': image.height,
        });
      }

      final stale = await _client.rpc(
        'bil_set_my_community_post_draft_media_v1',
        params: {'p_draft_id': input.draftId, 'p_items': items},
      );
      if (stale is! List || stale.any((value) => value is! String)) {
        throw const FormatException('Invalid Community draft media receipt');
      }
      final stalePaths = stale.cast<String>();
      if (stalePaths.isNotEmpty) {
        try {
          await _client.storage.from(_draftBucket).remove(stalePaths);
        } on Object {
          // The authoritative draft metadata no longer references stale paths.
        }
      }
      return input.draftId;
    } on Object {
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_draftBucket).remove(uploaded);
        } on Object {
          // Best effort: uploaded objects remain private to the owner.
        }
      }
      rethrow;
    }
  }

  Future<void> consumeMyCommunityDraftAfterPublish({
    required String draftId,
    required String postId,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(draftId) ||
        !CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError('Invalid Community draft publish receipt');
    }
    final response = await _client.rpc(
      'bil_consume_my_community_post_draft_v1',
      params: {'p_draft_id': draftId, 'p_post_id': postId},
    );
    if (response is! List || response.any((value) => value is! String)) {
      throw const FormatException(
        'Invalid Community draft publish consumption receipt',
      );
    }
    final paths = response.cast<String>();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(_draftBucket).remove(paths);
      } on Object {
        // The authoritative draft row is already gone. Private orphan cleanup
        // can retry independently without leaving a visible duplicate draft.
      }
    }
  }

  Future<void> deleteMyCommunityDraft(String draftId) async {
    if (!CommunityRepository._uuid.hasMatch(draftId)) {
      throw ArgumentError.value(draftId, 'draftId');
    }
    final response = await _client.rpc(
      'bil_delete_my_community_post_draft_v1',
      params: {'p_draft_id': draftId},
    );
    if (response is! List || response.any((value) => value is! String)) {
      throw const FormatException('Invalid Community draft delete receipt');
    }
    final paths = response.cast<String>();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(_draftBucket).remove(paths);
      } on Object {
        // The draft is already deleted and no longer user-visible.
      }
    }
  }
}
