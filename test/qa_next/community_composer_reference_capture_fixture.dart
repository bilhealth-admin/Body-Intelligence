part of 'community_composer_reference_capture_test.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _restoredId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class _ComposerReferenceAuth {
  String owner = _owner;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://composer-reference.invalid',
    'synthetic-fixture-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path != '/auth/v1/token') {
        throw StateError(
          'Unexpected fixture HTTP request: ${request.url.path}',
        );
      }
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return http.Response(
        jsonEncode({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'email': 'fixture@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-06T00:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  Future<void> signIn(String next) async {
    owner = next;
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'synthetic',
    );
    sessions[next] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> roundTrip() async {
    final b = client.auth.recoverSession(sessions[_other]!);
    final a = client.auth.recoverSession(sessions[_owner]!);
    await Future.wait([b, a]);
  }
}

class _FixturePicker implements CommunityPostImagePickerContract {
  _FixturePicker(this.photos);
  final List<CommunityPostImageDraft> photos;
  int calls = 0;
  @override
  Future<CommunityPostImageDraft?> pick() async => photos[calls++];
}

class _ComposerReferenceRepository extends CommunityRepository {
  _ComposerReferenceRepository(super.client, this.photos, this.previews);
  final List<CommunityPostImageDraft> photos;
  final List<CommunityPostImagePreview> previews;
  final drafts =
      <
        String,
        ({CommunityDraftSaveInput input, List<CommunityPostImageDraft> images})
      >{};
  final saveAttempts = <CommunityDraftSaveInput>[];
  final publishAttempts = <CommunityDraftSaveInput>[];
  final publishedImages = <List<CommunityPostImageDraft>>[];
  final readOwners = <String>[];
  Completer<List<CommunityDraftSummary>>? nextList;
  bool loseNextSaveResponse = false;
  bool failNextPublish = false;
  int profileReads = 0;
  int codeReads = 0;
  int acceptedPolicies = 0;
  int publishCalls = 0;

  @override
  bool get useServerCommunityReferenceParity => false;
  @override
  bool get useServerRankedCommunityFeed => false;
  @override
  bool get useServerIdempotentCommunityPublishing => true;
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;
  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => const [];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];
  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptedPolicies++;
    throw StateError(
      'This fixture never authorizes automatic policy acceptance.',
    );
  }

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    return CommunityProfile(
      userId: currentUserId,
      displayName: 'Synthetic member',
      localeCode: 'en',
      discoverable: false,
      visibility: CommunityProfileVisibility.private,
    );
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeReads++;
    return CommunityPublicCode.fromJson({
      'code': 'aabbccddaabbccddaabbccddaabbccdd',
      'uri': 'bil://community/member/aabbccddaabbccddaabbccddaabbccdd',
      'handle': 'synthetic_member',
    });
  }

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => [
    for (final slug in ['success-stories', 'nutrition'])
      CommunityTopic(
        slug: slug,
        titleCopyKey: 'community_topic_${slug.replaceAll('-', '_')}',
        descriptionCopyKey: 'community_topic_description',
        iconKey: 'topic',
        featured: true,
        followerCount: 4,
        postCount: 8,
        following: false,
      ),
  ];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [
    CommunityCircle(
      slug: 'healthy-eating',
      titleCopyKey: 'community_circle_healthy_eating',
      descriptionCopyKey: 'community_circle_healthy_eating_body',
      rulesCopyKey: 'community_circle_standard_rules',
      access: CommunityCircleAccess.public,
      joinPolicy: CommunityCircleJoinPolicy.open,
      featured: true,
      memberCount: 8,
      postCount: 4,
      membershipStatus: CommunityCircleMembershipStatus.active,
    ),
  ];
  @override
  Future<List<CommunityMentionCandidate>> searchCommunityMentions(
    String query, {
    int limit = 12,
  }) async => const [
    CommunityMentionCandidate(
      userId: _other,
      handle: 'sample_friend',
      displayName: 'Sample friend',
    ),
  ];
  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    readOwners.add(currentUserId);
    final pending = nextList;
    nextList = null;
    if (pending != null) return pending.future;
    return [
      for (final entry in drafts.values.take(limit))
        CommunityDraftSummary.fromJson({
          'draft_id': entry.input.draftId,
          'title': entry.input.title,
          'body': entry.input.body,
          'updated_at': '2026-10-06T12:00:00Z',
          'media_count': entry.images.length,
        }),
    ];
  }

  @override
  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    saveAttempts.add(input);
    drafts[input.draftId] = (input: input, images: List.unmodifiable(images));
    if (loseNextSaveResponse) {
      loseNextSaveResponse = false;
      throw StateError('Synthetic response loss after the private commit');
    }
    return input.draftId;
  }

  CommunityPersistentDraft _readDraft(String id) {
    final entry = drafts[id]!;
    final input = entry.input;
    Map<String, dynamic> candidate(CommunityMentionCandidate value) => {
      'user_id': value.userId,
      'handle': value.handle,
      'display_name': value.displayName,
      'avatar_url': value.avatarUrl,
    };
    return CommunityPersistentDraft.fromJson({
      'draft_id': id,
      'title': input.title,
      'body': input.body,
      'topic_slugs': input.topicSlugs,
      'circle_slug': input.circleSlug,
      'location_label': input.locationLabel,
      'mentions': input.mentions.map(candidate).toList(),
      'collaborators': input.collaborators.map(candidate).toList(),
      'hashtags': input.hashtags,
      'poll_question': input.pollQuestion,
      'poll_options': input.pollOptions,
      'poll_allow_multiple': input.pollAllowMultiple,
      'created_at': '2026-10-06T12:00:00Z',
      'updated_at': '2026-10-06T12:00:00Z',
      'media': [
        for (var index = 0; index < entry.images.length; index++)
          {
            'position': index,
            'object_path':
                '$currentUserId/$id/photo-$index.${entry.images[index].extension}',
            'mime_type': entry.images[index].mimeType,
            'bytes': entry.images[index].byteLength,
            'width': entry.images[index].width,
            'height': entry.images[index].height,
          },
      ],
    });
  }

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImagePreview?> images})
  >
  loadMyCommunityDraftMosaicPreview(
    String draftId, {
    int maxImages = 4,
  }) async => (
    draft: _readDraft(draftId),
    images: [
      for (final image in drafts[draftId]!.images.take(maxImages))
        previews[photos.indexOf(image)],
    ],
  );
  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImageDraft> images})
  >
  loadMyCommunityDraft(String draftId) async =>
      (draft: _readDraft(draftId), images: drafts[draftId]!.images);
  @override
  Future<void> publishRichPost(
    String body, {
    List<CommunityPostImageDraft> images = const [],
    List<String> topicSlugs = const [],
    String? circleSlug,
    CommunityPollDraft? poll,
    String? locationLabel,
    List<CommunityMentionCandidate> mentions = const [],
    String? title,
    List<String> hashtags = const [],
    List<CommunityMentionCandidate> collaborators = const [],
    String? persistentDraftId,
  }) async {
    publishCalls++;
    publishedImages.add(List.unmodifiable(images));
    publishAttempts.add(
      CommunityDraftSaveInput(
        draftId: persistentDraftId ?? 'unsaved',
        body: body,
        title: title,
        topicSlugs: topicSlugs,
        circleSlug: circleSlug,
        locationLabel: locationLabel,
        mentions: mentions,
        hashtags: hashtags,
        collaborators: collaborators,
        pollQuestion: poll?.question,
        pollOptions: poll?.options ?? const [],
        pollAllowMultiple: poll?.allowMultiple ?? false,
      ),
    );
    if (failNextPublish) {
      failNextPublish = false;
      throw StateError('Synthetic publish response failure');
    }
  }
}
