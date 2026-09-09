import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _communityPolicyV1 = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

final class _EntryPointRepository extends CommunityRepository {
  _EntryPointRepository(this.policyState, {this.messageFailure})
    : super(
        SupabaseClient(
          'https://community-entrypoints.invalid',
          'community-entrypoints-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const currentUser = '11111111-1111-4111-8111-111111111111';
  static const otherUser = '22222222-2222-4222-8222-222222222222';

  CommunityPolicyState policyState;
  final Object? messageFailure;
  final List<String> acceptedVersions = [];
  int messageSendCalls = 0;

  @override
  String get currentUserId => currentUser;

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => policyState;

  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptedVersions.add(version);
    final policy = policyState.policy;
    if (policy != null && policy.version == version) {
      policyState = CommunityPolicyState.accepted(
        policy,
        acceptedVersion: version,
      );
    }
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async =>
      const [
        {
          'user_id': otherUser,
          'display_name': 'BIL QA Partner',
          'avatar_url': null,
        },
      ];

  @override
  Future<List<CommunityMessage>> loadMessages(String otherUserId) async =>
      const [];

  @override
  Future<void> markConversationRead(String otherUserId) async {}

  @override
  Stream<void> watchConversationChanges(String otherUserId) =>
      const Stream<void>.empty();

  @override
  Future<void> sendMessage(String recipientId, String body) async {
    messageSendCalls += 1;
    final failure = messageFailure;
    if (failure != null) throw failure;
  }
}

Widget _app(Widget home) => MaterialApp(home: home);

CommunityPolicyState _acceptedPolicyState() => CommunityPolicyState.accepted(
  _communityPolicyV1,
  acceptedVersion: _communityPolicyV1.version,
);

Future<void> _tapCreatePost(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('community-create-post')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('feed shows no-policy notice and never opens the composer', (
    tester,
  ) async {
    final repository = _EntryPointRepository(
      const CommunityPolicyState.unavailable(),
    );
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-policy-notice-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-post-editor-page')), findsNothing);

    await _tapCreatePost(tester);

    expect(
      find.byKey(const Key('community-policy-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-post-editor-page')), findsNothing);
    expect(repository.acceptedVersions, isEmpty);
  });

  testWidgets('feed Not now records no acceptance and opens no composer', (
    tester,
  ) async {
    final repository = _EntryPointRepository(
      CommunityPolicyState.acceptanceRequired(_communityPolicyV1),
    );
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-policy-notice-acceptance-required')),
      findsOneWidget,
    );
    await _tapCreatePost(tester);
    await tester.tap(find.byKey(const Key('community-policy-not-now')));
    await tester.pumpAndSettle();

    expect(repository.acceptedVersions, isEmpty);
    expect(find.byKey(const Key('community-post-editor-page')), findsNothing);
    expect(
      find.byKey(const Key('community-policy-notice-acceptance-required')),
      findsOneWidget,
    );
  });

  testWidgets(
    'accepting the real v1 policy then returning opens the composer',
    (tester) async {
      final repository = _EntryPointRepository(
        CommunityPolicyState.acceptanceRequired(_communityPolicyV1),
      );
      await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
      await tester.pumpAndSettle();

      await _tapCreatePost(tester);
      expect(find.textContaining('community-policy-v1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-community-policy')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('accept-community-policy')));
      await tester.pumpAndSettle();

      expect(repository.acceptedVersions, ['community-policy-v1']);
      expect(find.text('Accepted'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('community-post-editor-page')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('community-post-composer')), findsOneWidget);
    },
  );

  testWidgets('new-message suspension is clear and preserves its draft', (
    tester,
  ) async {
    final repository = _EntryPointRepository(
      _acceptedPolicyState(),
      messageFailure: const CommunityMembershipAccessException(
        failure: CommunityMembershipAccessFailure.suspended,
      ),
    );
    await tester.pumpWidget(
      _app(NewCommunityMessagePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BIL QA Partner'));
    final subject = find.byKey(const Key('community-message-subject'));
    await tester.ensureVisible(subject);
    await tester.pumpAndSettle();
    await tester.enterText(subject, 'A retained subject');
    await tester.pump();
    expect(
      tester.widget<TextField>(subject).controller!.text,
      'A retained subject',
    );
    final body = find.byKey(const Key('community-message-body'));
    await tester.ensureVisible(body);
    await tester.pumpAndSettle();
    await tester.enterText(body, 'A retained new-message draft');
    await tester.pump();
    expect(
      tester.widget<TextField>(subject).controller!.text,
      'A retained subject',
    );
    expect(
      tester.widget<TextField>(body).controller!.text,
      'A retained new-message draft',
    );
    await tester.tap(find.byKey(const Key('community-message-send')));
    await tester.pumpAndSettle();

    expect(repository.messageSendCalls, 1);
    expect(
      find.text(
        'Your Community access is suspended. Messaging remains locked.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(subject).controller!.text,
      'A retained subject',
    );
    expect(
      tester.widget<TextField>(body).controller!.text,
      'A retained new-message draft',
    );
  });

  testWidgets('chat relationship block is clear and preserves its draft', (
    tester,
  ) async {
    final repository = _EntryPointRepository(
      _acceptedPolicyState(),
      messageFailure: const CommunityMembershipAccessException(
        failure: CommunityMembershipAccessFailure.relationshipBlocked,
      ),
    );
    await tester.pumpWidget(
      _app(
        CommunityChatPage(
          userId: _EntryPointRepository.otherUser,
          displayName: 'BIL QA Partner',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byKey(const Key('community-message-composer'));
    await tester.enterText(composer, 'A retained chat draft');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(repository.messageSendCalls, 1);
    expect(
      find.text(
        'Messaging is unavailable because the relationship is blocked.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'A retained chat draft',
    );
  });
}
