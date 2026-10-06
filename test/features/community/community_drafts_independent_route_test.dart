import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _draft = '33333333-3333-4333-8333-333333333333';

class _DraftRepository extends CommunityRepository {
  _DraftRepository(super.client);

  int profileReads = 0;
  int previewReads = 0;

  @override
  String get currentUserId => _owner;

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    throw StateError('Drafts must not require a public profile');
  }

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async => [
    CommunityDraftSummary(
      draftId: _draft,
      title: '4 Simple Habits',
      body: 'Small habits can build meaningful progress over time.',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      mediaCount: 4,
    ),
  ];

  @override
  Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  loadMyCommunityDraftPreview(String draftId) async {
    previewReads++;
    return (
      draft: CommunityPersistentDraft(
        draftId: draftId,
        title: '4 Simple Habits',
        body: 'Small habits can build meaningful progress over time.',
        topicSlugs: const ['nutrition'],
        mentions: const [],
        collaborators: const [],
        hashtags: const ['health'],
        pollQuestion: 'Which habit is hardest?',
        pollOptions: const ['Food', 'Sleep'],
        pollAllowMultiple: false,
        createdAt: DateTime.utc(2026, 10, 5, 9),
        updatedAt: DateTime.utc(2026, 10, 5, 9, 20),
        media: const [],
      ),
      image: null,
    );
  }
}

void _draftTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

void main() {
  late SupabaseClient client;
  late _DraftRepository repository;
  setUp(() {
    client = SupabaseClient(
      'https://draft-route.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = _DraftRepository(client);
  });
  tearDown(() async {
    await client.dispose();
  });

  _draftTest('drafts are directly reachable without a Community profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CommunityDraftsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-drafts-page')), findsOneWidget);
    expect(find.text('Drafts (1)'), findsOneWidget);
    expect(find.text('4 Simple Habits'), findsOneWidget);
    expect(find.textContaining('4 photos'), findsOneWidget);
    expect(find.textContaining('Poll'), findsOneWidget);
    expect(
      find.byKey(const Key('community-draft-continue-$_draft')),
      findsOneWidget,
    );
    expect(repository.profileReads, 0);
    expect(repository.previewReads, 1);
    expect(tester.takeException(), isNull);
  });

  _draftTest('select mode is explicit and never opens a draft implicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CommunityDraftsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community-drafts-select')));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-draft-$_draft')));
    await tester.pump();
    expect(
      find.byKey(const Key('community-drafts-delete-selected')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
