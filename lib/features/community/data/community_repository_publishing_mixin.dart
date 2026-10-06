part of 'community_repository.dart';

mixin _CommunityPublishingRepositoryMixin {
  CommunityPostStoreContract get _posts;

  SupabaseClient get _client;
  User get _user;
  bool get useServerIdempotentCommunityPublishing;

  Future<T> _runCommunityMutation<T>(Future<T> Function() mutation);

  Future<T> _runCommunityOwnerOperation<T>(
    Future<T> Function(CommunityOwnerOperation operation) action,
  );

  Future<void> assertCommunityPublishReady();

  Future<Never> _rethrowPolicyStateAfterStorageFailure(
    StorageException error,
    StackTrace stackTrace,
  );

  Future<void> createCommunityPoll({
    required String postId,
    required CommunityPollDraft draft,
  });

  Future<void> setMyCommunityPostCircle({required String postId, String? slug});

  Future<void> setMyCommunityPostContext({
    required String postId,
    String? locationLabel,
    List<CommunityMentionCandidate> mentions =
        const <CommunityMentionCandidate>[],
  });

  Future<void> setMyCommunityPostTopics({
    required String postId,
    required List<String> slugs,
  });

  Future<void> setMyCommunityPostReferenceMetadata({
    required String postId,
    String? title,
    List<String> hashtags,
    List<String> collaboratorUserIds,
  });

  Future<void> consumeMyCommunityDraftAfterPublish({
    required String draftId,
    required String postId,
  });

  Future<void> publishPost(String body) async {
    if (useServerIdempotentCommunityPublishing) return publishRichPost(body);
    await assertCommunityPublishReady();
    await _runCommunityMutation(() => _posts.publishText(body));
  }

  Future<void> publishPostWithTopics(
    String body, {
    required List<String> topicSlugs,
  }) async {
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(body, topicSlugs: topicSlugs);
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(body, images: [image]);
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(body, images: [image], topicSlugs: topicSlugs);
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
      );
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
        poll: poll,
      );
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        images: [image],
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
      );
    }
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
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        images: [image],
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
        poll: poll,
      );
    }
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

  Future<void> publishPostWithImagesTopicsAndCircle(
    String body,
    List<CommunityPostImageDraft> images, {
    List<String> topicSlugs = const [],
    String? circleSlug,
  }) async {
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        images: images,
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
      );
    }
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);
    if (images.isEmpty || images.length > 4) {
      throw ArgumentError.value(images.length, 'images');
    }

    final store = _posts;
    if (store is! CommunityPostMultiImagePublishingContract) {
      throw StateError('Community multi-image publishing is unavailable');
    }
    final mediaStore = store as CommunityPostMultiImagePublishingContract;
    try {
      final postId = await _runCommunityMutation(
        () => mediaStore.publishWithImagesReceipt(body, images),
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

  Future<void> publishPostWithImagesTopicsCircleAndPoll(
    String body,
    List<CommunityPostImageDraft> images, {
    List<String> topicSlugs = const [],
    String? circleSlug,
    required CommunityPollDraft poll,
  }) async {
    if (useServerIdempotentCommunityPublishing) {
      return publishRichPost(
        body,
        images: images,
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
        poll: poll,
      );
    }
    await assertCommunityPublishReady();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);
    if (images.isEmpty || images.length > 4) {
      throw ArgumentError.value(images.length, 'images');
    }
    final normalizedPoll = poll.normalized();

    final store = _posts;
    if (store is! CommunityPostMultiImagePublishingContract) {
      throw StateError('Community multi-image publishing is unavailable');
    }
    final mediaStore = store as CommunityPostMultiImagePublishingContract;
    try {
      final postId = await _runCommunityMutation(
        () => mediaStore.publishWithImagesReceipt(body, images),
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

  Future<void> publishRichPost(
    String body, {
    List<CommunityPostImageDraft> images = const <CommunityPostImageDraft>[],
    List<String> topicSlugs = const <String>[],
    String? circleSlug,
    CommunityPollDraft? poll,
    String? locationLabel,
    List<CommunityMentionCandidate> mentions =
        const <CommunityMentionCandidate>[],
    String? title,
    List<String> hashtags = const <String>[],
    List<CommunityMentionCandidate> collaborators =
        const <CommunityMentionCandidate>[],
    String? persistentDraftId,
  }) => _runCommunityOwnerOperation((operation) async {
    final text = body.trim();
    if (text.isEmpty ||
        CommunityTextLimits.exceedsBodyLimit(text) ||
        CommunityRepository._unsafeText.hasMatch(text)) {
      throw const FormatException('Invalid community post body');
    }
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.post);
    await assertCommunityPublishReady();
    operation.check();
    _validateTopicSlugs(topicSlugs);
    _validateCircleSlug(circleSlug);
    if (images.length > 4) {
      throw ArgumentError.value(images.length, 'images');
    }

    final context = CommunityPostContextDraft(
      locationLabel: locationLabel,
      mentions: mentions,
    ).normalized();
    final normalizedPoll = poll?.normalized();
    if (useServerIdempotentCommunityPublishing) {
      await _runCommunityMutation(
        () => CommunityPublishOperationService(_client, _user.id).publish({
          'body': text,
          'topic_slugs': topicSlugs,
          'circle_slug': circleSlug,
          'location_label': context.locationLabel,
          'mentioned_user_ids': context.mentionedUserIds,
          'title': title?.trim().isEmpty == true ? null : title?.trim(),
          'hashtags': hashtags,
          'collaborator_user_ids': collaborators
              .map((item) => item.userId)
              .toList(),
          'poll': normalizedPoll == null
              ? null
              : {
                  'question': normalizedPoll.question,
                  'options': normalizedPoll.options,
                  'allow_multiple': normalizedPoll.allowMultiple,
                  'closes_at': normalizedPoll.closesAt
                      ?.toUtc()
                      .toIso8601String(),
                },
          'persistent_draft_id': persistentDraftId,
        }, images),
      );
      operation.check();
      return;
    }
    final store = _posts;
    String? postId;

    try {
      if (images.isEmpty) {
        if (store is! CommunityPostPublishingReceiptContract) {
          throw StateError('Community post publishing receipt is unavailable');
        }
        final receiptStore = store as CommunityPostPublishingReceiptContract;
        postId = await _runCommunityMutation(
          () => receiptStore.publishTextWithReceipt(body),
        );
      } else if (images.length == 1) {
        if (store is! CommunityPostPublishingReceiptContract) {
          throw StateError('Community image publishing is unavailable');
        }
        final receiptStore = store as CommunityPostPublishingReceiptContract;
        postId = await _runCommunityMutation(
          () => receiptStore.publishWithImageReceipt(body, images.single),
        );
      } else {
        if (store is! CommunityPostMultiImagePublishingContract) {
          throw StateError('Community multi-image publishing is unavailable');
        }
        final mediaStore = store as CommunityPostMultiImagePublishingContract;
        postId = await _runCommunityMutation(
          () => mediaStore.publishWithImagesReceipt(body, images),
        );
      }

      if (postId == null) return;
      operation.check();

      final normalizedTitle = title?.trim();
      if ((normalizedTitle?.isNotEmpty ?? false) ||
          hashtags.isNotEmpty ||
          collaborators.isNotEmpty) {
        await setMyCommunityPostReferenceMetadata(
          postId: postId,
          title: normalizedTitle,
          hashtags: hashtags,
          collaboratorUserIds: [
            for (final collaborator in collaborators) collaborator.userId,
          ],
        );
        operation.check();
      }

      if (topicSlugs.isNotEmpty) {
        await setMyCommunityPostTopics(postId: postId, slugs: topicSlugs);
        operation.check();
      }
      if (circleSlug != null) {
        await setMyCommunityPostCircle(postId: postId, slug: circleSlug);
        operation.check();
      }
      if (context.locationLabel != null || context.mentions.isNotEmpty) {
        await setMyCommunityPostContext(
          postId: postId,
          locationLabel: context.locationLabel,
          mentions: context.mentions,
        );
        operation.check();
      }
      if (normalizedPoll != null) {
        await createCommunityPoll(postId: postId, draft: normalizedPoll);
        operation.check();
      }
      if (persistentDraftId != null) {
        await consumeMyCommunityDraftAfterPublish(
          draftId: persistentDraftId,
          postId: postId,
        );
        operation.check();
      }
    } on StorageException catch (error, stackTrace) {
      await _rethrowPolicyStateAfterStorageFailure(error, stackTrace);
    } on Object {
      if (postId != null && operation.isCurrent) {
        try {
          await store.delete(postId);
        } on Object {
          // The moderation-pending post remains non-public if cleanup fails.
        }
      }
      rethrow;
    }
  });

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
}
