import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _acceptedPolicy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

class _FeedRepository extends CommunityRepository {
  _FeedRepository()
    : super(
        SupabaseClient(
          'https://unit.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int calls = 0;
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    _acceptedPolicy,
    acceptedVersion: _acceptedPolicy.version,
  );
  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: 'post',
      authorId: currentUserId,
      body: 'A saved community post',
      createdAt: DateTime.utc(2026, 9, 8),
    ),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [];
  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => [];
  @override
  Future<void> publishPost(String body) async {
    calls++;
  }
}

void main() {
  testWidgets(
    'feed is for reading; creation is separate and back preserves its draft',
    (tester) async {
      final repository = _FeedRepository();
      await tester.pumpWidget(
        MaterialApp(home: CommunityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('A saved community post'), findsOneWidget);
      expect(find.byKey(const Key('community-post-composer')), findsNothing);
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-post-editor-page')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('community-post-composer')),
        'Saved draft',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('A saved community post'), findsOneWidget);
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();
      expect(find.text('Saved draft'), findsOneWidget);
      await tester.tap(find.byKey(const Key('community-post-publish')));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.byKey(const Key('community-post-editor-page')), findsNothing);
      expect(find.byKey(const Key('community-post-composer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
