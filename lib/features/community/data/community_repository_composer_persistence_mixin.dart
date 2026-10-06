part of 'community_repository.dart';

mixin _CommunityComposerPersistenceRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  Future<void> assertCommunityPublishReady();

  Future<T> _runCommunityOwnerOperation<T>(
    Future<T> Function(CommunityOwnerOperation operation) action,
  );

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
      throw const FormatException('Community post reference metadata mismatch');
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
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
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
        return CommunityDraftSummary.fromJson(Map<String, dynamic>.from(raw));
      }),
    );
  }

  Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  loadMyCommunityDraftPreview(String draftId) =>
      _runCommunityOwnerOperation((operation) async {
        if (!CommunityRepository._uuid.hasMatch(draftId)) {
          throw ArgumentError.value(draftId, 'draftId');
        }
        final response = await _client.rpc(
          'bil_get_my_community_post_draft_v1',
          params: {'p_draft_id': draftId},
        );
        operation.check();
        if (response is! Map) {
          throw const FormatException('Invalid Community draft');
        }
        final draft = CommunityPersistentDraft.fromJson(
          Map<String, dynamic>.from(response),
        );
        if (draft.draftId != draftId) {
          throw const FormatException('Community draft id mismatch');
        }
        if (draft.media.isEmpty) return (draft: draft, image: null);

        final metadata = [...draft.media]
          ..sort((left, right) => left.position.compareTo(right.position));
        final media = metadata.first;
        final bytes = await _client.storage
            .from(_draftBucket)
            .download(media.objectPath);
        operation.check();
        final image = await validateCommunityPostImageAsync(bytes);
        operation.check();
        if (image.mimeType != media.mimeType ||
            image.byteLength != media.bytes ||
            image.width != media.width ||
            image.height != media.height) {
          throw const FormatException('Community draft preview media mismatch');
        }
        return (draft: draft, image: image);
      });

  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImageDraft> images})
  >
  loadMyCommunityDraft(String draftId) =>
      _runCommunityOwnerOperation((operation) async {
        if (!CommunityRepository._uuid.hasMatch(draftId)) {
          throw ArgumentError.value(draftId, 'draftId');
        }
        final response = await _client.rpc(
          'bil_get_my_community_post_draft_v1',
          params: {'p_draft_id': draftId},
        );
        operation.check();
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
          operation.check();
          final image = await validateCommunityPostImageAsync(bytes);
          operation.check();
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
      });

  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) => _runCommunityOwnerOperation((operation) async {
    if (!CommunityRepository._uuid.hasMatch(input.draftId) ||
        images.length > 4) {
      throw ArgumentError('Invalid Community draft');
    }
    if (CommunityTextLimits.exceedsBodyLimit(input.body)) {
      throw const FormatException('Invalid Community draft body length');
    }
    final owner = _user.id;
    await assertCommunityPublishReady();
    operation.check();

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
    operation.check();
    if (draftId != input.draftId) {
      throw const FormatException('Invalid Community draft save receipt');
    }

    final validated = <CommunityPostImageDraft>[];
    for (final image in images) {
      validated.add(await validateCommunityPostImageAsync(image.bytes));
      operation.check();
    }

    final uploaded = <String>[];
    var mediaCommitStarted = false;
    try {
      final items = <Map<String, Object>>[];
      for (final image in validated) {
        final objectId = _uuidGenerator.v4();
        final path = '$owner/${input.draftId}/$objectId.${image.extension}';
        operation.check();
        await _client.storage
            .from(_draftBucket)
            .uploadBinary(
              path,
              image.bytes,
              retryAttempts: 0,
              fileOptions: FileOptions(
                upsert: false,
                contentType: image.mimeType,
                cacheControl: '86400',
              ),
            );
        operation.check();
        uploaded.add(path);
        items.add({
          'object_path': path,
          'mime_type': image.mimeType,
          'bytes': image.byteLength,
          'width': image.width,
          'height': image.height,
        });
      }

      mediaCommitStarted = true;
      final stale = await _client.rpc(
        'bil_set_my_community_post_draft_media_v1',
        params: {'p_draft_id': input.draftId, 'p_items': items},
      );
      operation.check();
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
      // Once the metadata RPC starts, a lost reply cannot prove the images
      // are unreferenced. Keep them private until a verified retry supplies
      // the authoritative stale-path list instead of deleting saved media.
      if (!mediaCommitStarted && uploaded.isNotEmpty && operation.isCurrent) {
        try {
          await _client.storage.from(_draftBucket).remove(uploaded);
        } on Object {
          // Best effort: uploaded objects remain private to the owner.
        }
      }
      rethrow;
    }
  });

  Future<void> consumeMyCommunityDraftAfterPublish({
    required String draftId,
    required String postId,
  }) => _runCommunityOwnerOperation((operation) async {
    if (!CommunityRepository._uuid.hasMatch(draftId) ||
        !CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError('Invalid Community draft publish receipt');
    }
    final response = await _client.rpc(
      'bil_consume_my_community_post_draft_v1',
      params: {'p_draft_id': draftId, 'p_post_id': postId},
    );
    operation.check();
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
    operation.check();
  });

  Future<void> deleteMyCommunityDraft(String draftId) =>
      _runCommunityOwnerOperation((operation) async {
        if (!CommunityRepository._uuid.hasMatch(draftId)) {
          throw ArgumentError.value(draftId, 'draftId');
        }
        final response = await _client.rpc(
          'bil_delete_my_community_post_draft_v1',
          params: {'p_draft_id': draftId},
        );
        operation.check();
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
        operation.check();
      });
}
