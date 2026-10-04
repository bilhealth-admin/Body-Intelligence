import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_post_context.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_composer_voice_input_service.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _collaborator = '22222222-2222-4222-8222-222222222222';

final _acceptedPolicy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

final class _NoImagePicker implements CommunityPostImagePickerContract {
  const _NoImagePicker();

  @override
  Future<CommunityPostImageDraft?> pick() async => null;
}

final class _ReferenceComposerRepository extends CommunityRepository {
  _ReferenceComposerRepository()
    : super(
        SupabaseClient(
          'https://reference-composer.invalid',
          'reference-composer-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  CommunityDraftSaveInput? savedDraft;
  List<CommunityPostImageDraft>? savedImages;
  int saveCalls = 0;
  int publishCalls = 0;
  String? publishedBody;
  String? publishedTitle;
  String? publishedDraftId;
  List<String> publishedHashtags = const <String>[];
  List<CommunityMentionCandidate> publishedCollaborators =
      const <CommunityMentionCandidate>[];

  static const candidate = CommunityMentionCandidate(
    userId: _collaborator,
    handle: 'collab_member',
    displayName: 'Collab Member',
  );

  @override
  bool get useServerCommunityReferenceParity => false;

  @override
  String get currentUserId => _owner;

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    _acceptedPolicy,
    acceptedVersion: _acceptedPolicy.version,
  );

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async =>
      const <CommunityPost>[];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async =>
      const <CommunityTopic>[];

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async =>
      const <CommunityCircle>[];

  @override
  Future<List<CommunityMentionCandidate>> searchCommunityMentions(
    String query, {
    int limit = 12,
  }) async => query.trim().isEmpty
      ? const <CommunityMentionCandidate>[]
      : const <CommunityMentionCandidate>[candidate];

  @override
  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    saveCalls++;
    savedDraft = input;
    savedImages = images;
    return input.draftId;
  }

  @override
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
  }) async {
    publishCalls++;
    publishedBody = body;
    publishedTitle = title;
    publishedHashtags = List<String>.unmodifiable(hashtags);
    publishedCollaborators = List<CommunityMentionCandidate>.unmodifiable(
      collaborators,
    );
    publishedDraftId = persistentDraftId;
  }
}

final class _FakeSpeechToText extends SpeechToText {
  _FakeSpeechToText()
    : super(
        methods: const MethodChannel('bil/community/voice/test'),
        events: const EventChannel('bil/community/voice/test/events'),
      );

  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
  }) async => true;

  @override
  Future<List<LocaleName>> locales() async => const <LocaleName>[
    LocaleName('en-US'),
  ];

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    required SpeechListenOptions listenOptions,
  }) async {
    _listening = true;
    onResult(
      const SpeechRecognitionResult(
        'Community voice draft',
        isFinal: true,
        localeId: 'en-US',
      ),
    );
    _listening = false;
  }

  @override
  Future<void> stop() async => _listening = false;

  @override
  Future<void> cancel() async => _listening = false;

  @override
  Future<void> dispose() async => _listening = false;
}

Widget _app(CommunityRepository repository) => MaterialApp(
  locale: const Locale('en'),
  home: CommunityHubPage(
    repository: repository,
    postImagePicker: const _NoImagePicker(),
  ),
);

void main() {
  test('composer migrations keep persistence private and collaboration durable', () {
    final composer = File(
      'supabase/migrations/20261003211000_community_reference_composer_persistence_v1.sql',
    ).readAsStringSync().toLowerCase();
    final workInProgress = File(
      'supabase/migrations/20261003211500_community_draft_work_in_progress_v1.sql',
    ).readAsStringSync().toLowerCase();
    final collaboration = File(
      'supabase/migrations/20261003212000_community_reference_collaboration_activity_v1.sql',
    ).readAsStringSync().toLowerCase();

    for (final required in const [
      'bil_community_post_drafts_v1',
      'bil_community_post_draft_media_v1',
      'bil_set_my_community_post_draft_media_v1',
      'bil_list_my_community_post_drafts_v1',
      'bil_get_my_community_post_draft_v1',
      'bil_delete_my_community_post_draft_v1',
      'bil_community_post_hashtags_v1',
      'bil_community_post_collaborators_v1',
      'bil_community_post_reference_metadata_v1',
      'topics jsonb',
      'circle jsonb',
      'security definer',
      "set search_path=''",
      'revoke all on table',
    ]) {
      expect(composer, contains(required), reason: required);
    }

    expect(workInProgress, contains('bil_consume_my_community_post_draft_v1'));
    expect(workInProgress, contains("p.moderation_status='pending'"));

    for (final required in const [
      'collaboration_invite',
      'collaboration_accepted',
      'bil_post_collaboration_activity_v1',
      'bil_respond_community_collaboration_v1',
      'private.bil_activity_pair_allowed_v1',
      "'duplicate',true",
      'bil_list_community_activity_v2',
    ]) {
      expect(collaboration, contains(required), reason: required);
    }

    expect(collaboration, isNot(contains('push_outbox')));
    expect(composer, isNot(contains('grant all on table')));
    expect(composer, isNot(contains('weight')));
    expect(composer, isNot(contains('waist')));
    expect(composer, isNot(contains('body_fat')));
  });

  test(
    'reference metadata parses title hashtags topic circle and collaborators',
    () {
      final metadata = CommunityPostReferenceMetadata.fromJson({
        'post_id': '33333333-3333-4333-8333-333333333333',
        'title': 'Reference title',
        'hashtags': ['habits', 'progress'],
        'topics': [
          {
            'slug': 'success-stories',
            'title_copy_key': 'community_topic_success_stories',
            'post_count': 14,
          },
        ],
        'circle': {
          'slug': 'healthy-habits',
          'title_copy_key': 'community_circle_healthy_habits',
          'post_count': 9,
          'member_count': 31,
        },
        'collaborators': [
          {
            'user_id': _collaborator,
            'handle': 'collab_member',
            'display_name': 'Collab Member',
            'avatar_url': null,
            'status': 'accepted',
          },
        ],
      });

      expect(metadata.title, 'Reference title');
      expect(metadata.hashtags, ['habits', 'progress']);
      expect(metadata.topics.single.slug, 'success-stories');
      expect(metadata.topics.single.postCount, 14);
      expect(metadata.circle?.memberCount, 31);
      expect(
        metadata.collaborators.single.status,
        CommunityCollaborationStatus.accepted,
      );
    },
  );

  testWidgets(
    'composer saves and publishes title hashtags collaborator and persistent draft id',
    (tester) async {
      final repository = _ReferenceComposerRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-composer-title')), findsOneWidget);
      expect(
        find.byKey(const Key('community-composer-voice-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-post-save-draft')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-reference-action-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-media-tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-action-location')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-action-poll')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-action-circle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-action-collab')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-composer-action-more')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('community-composer-title')),
        'My reference title',
      );
      await tester.enterText(
        find.byKey(const Key('community-post-composer')),
        'My reference body',
      );
      await tester.ensureVisible(
        find.byKey(const Key('community-composer-hashtag-input')),
      );
      await tester.enterText(
        find.byKey(const Key('community-composer-hashtag-input')),
        'Progress',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final hashtagAdd = find.byKey(
        const Key('community-composer-hashtag-add'),
      );
      await tester.ensureVisible(hashtagAdd);
      await tester.pumpAndSettle();
      await tester.tap(hashtagAdd);
      await tester.pumpAndSettle();
      expect(find.text('#progress'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('community-composer-collaborator-query')),
      );
      await tester.enterText(
        find.byKey(const Key('community-composer-collaborator-query')),
        'collab',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final collaboratorSearch = find.byKey(
        const Key('community-composer-collaborator-search'),
      );
      await tester.ensureVisible(collaboratorSearch);
      await tester.pumpAndSettle();
      await tester.tap(collaboratorSearch);
      await tester.pumpAndSettle();
      final collaboratorChip = find.byKey(
        const Key('community-composer-collaborator-$_collaborator'),
      );
      await tester.ensureVisible(collaboratorChip);
      await tester.pumpAndSettle();
      await tester.tap(collaboratorChip);
      await tester.pumpAndSettle();
      expect(find.text('@collab_member'), findsWidgets);

      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-post-save-draft')));
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(repository.savedDraft?.title, 'My reference title');
      expect(repository.savedDraft?.body, 'My reference body');
      expect(repository.savedDraft?.hashtags, ['progress']);
      expect(repository.savedDraft?.collaborators.single.userId, _collaborator);
      final savedId = repository.savedDraft?.draftId;
      expect(savedId, isNotNull);
      expect(repository.savedImages, isEmpty);
      expect(find.text('Update draft'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-post-publish')));
      await tester.pumpAndSettle();

      expect(repository.publishCalls, 1);
      expect(repository.publishedBody, 'My reference body');
      expect(repository.publishedTitle, 'My reference title');
      expect(repository.publishedHashtags, ['progress']);
      expect(repository.publishedCollaborators.single.userId, _collaborator);
      expect(repository.publishedDraftId, savedId);
      expect(find.byKey(const Key('community-post-editor-page')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('voice capture is reviewed before transcript is returned', (
    tester,
  ) async {
    final service = CommunityComposerVoiceInputService(
      _FakeSpeechToText(),
      permissionGate: (_) async => true,
    );
    String? accepted;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  accepted = await service.capture(context);
                },
                child: const Text('Voice'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('community-voice-transcript')),
    );
    expect(field.controller?.text, 'Community voice draft');
    expect(accepted, isNull);

    await tester.tap(find.byKey(const Key('community-use-voice-transcript')));
    await tester.pumpAndSettle();

    expect(accepted, 'Community voice draft');
    expect(tester.takeException(), isNull);
  });
}
