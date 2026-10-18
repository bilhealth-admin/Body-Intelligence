import 'dart:async';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late SupabaseClient _testClient;

final _acceptedPolicy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

class _FeedRepository extends CommunityRepository {
  _FeedRepository() : super(_testClient);
  int calls = 0;
  int feedLoads = 0;
  List<CommunityPost> feed = <CommunityPost>[];
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: currentUserId,
    displayName: 'Existing member',
    localeCode: 'en',
    discoverable: false,
    visibility: CommunityProfileVisibility.private,
  );
  @override
  Future<CommunityPublicCode> loadPublicCode() async =>
      CommunityPublicCode.fromJson({
        'code': 'aabbccddaabbccddaabbccddaabbccdd',
        'uri': 'bil://community/member/aabbccddaabbccddaabbccddaabbccdd',
        'handle': 'existing_member',
      });
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    _acceptedPolicy,
    acceptedVersion: _acceptedPolicy.version,
  );
  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    feedLoads++;
    return feed.isEmpty
        ? [
            CommunityPost(
              id: 'post',
              authorId: currentUserId,
              body: 'A saved community post',
              createdAt: DateTime.utc(2026, 9, 8),
            ),
          ]
        : List<CommunityPost>.unmodifiable(feed);
  }

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [];
  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => [];
  @override
  Future<void> publishPost(String body) async {
    calls++;
  }
}

class _ModeFeedRepository extends _FeedRepository {
  @override
  bool get useServerRankedCommunityFeed => true;
  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required void Function() onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) => loadCommunityFeedMode(mode: mode, limit: limit);
  final following = Completer<CommunityFeedModeBatch>();
  final reaction = Completer<CommunityPostStats>();
  final modeReads = <CommunityFeedMode>[];
  int likes = 0;
  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    modeReads.add(mode);
    if (mode == CommunityFeedMode.following) return following.future;
    return page(mode);
  }

  CommunityFeedModeBatch page(CommunityFeedMode mode) => CommunityFeedModeBatch(
    posts: [
      CommunityPost(
        id: mode.wireValue,
        authorId: currentUserId,
        body: '${mode.wireValue} stable post',
        createdAt: DateTime.utc(2026, 10, 18),
      ),
    ],
    references: const [],
    hasMore: false,
  );
  @override
  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) {
    likes++;
    return reaction.future;
  }
}

void main() {
  testWidgets(
    'mode swaps preserve ready posts and positions without a spinner or wrong feed',
    (tester) async {
      final repository = _ModeFeedRepository();
      await tester.pumpWidget(
        MaterialApp(home: CommunityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('explore stable post'), findsOneWidget);
      final exploreY = tester.getTopLeft(find.text('explore stable post')).dy;
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      expect(find.text('explore stable post'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.following.complete(
        repository.page(CommunityFeedMode.following),
      );
      await tester.pumpAndSettle();
      final followingY = tester
          .getTopLeft(find.text('following stable post'))
          .dy;
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      expect(find.text('explore stable post'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('explore stable post')).dy,
        closeTo(exploreY, 1),
      );
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      expect(find.text('following stable post'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('following stable post')).dy,
        closeTo(followingY, 1),
      );
      expect(
        repository.modeReads.where(
          (mode) => mode == CommunityFeedMode.following,
        ),
        hasLength(1),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'pending reaction retains its heart and blocks duplicate requests',
    (tester) async {
      final repository = _ModeFeedRepository();
      repository.following.complete(
        repository.page(CommunityFeedMode.following),
      );
      await tester.pumpWidget(
        MaterialApp(home: CommunityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('community-post-like-explore'));
      // Center the action inside the feed viewport, away from the fixed nav bar.
      await Scrollable.ensureVisible(tester.element(action), alignment: .5);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pump();
      expect(
        find.descendant(
          of: action,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: action,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(tester.widget<TextButton>(action).onPressed, isNull);
      repository.reaction.complete(
        const CommunityPostStats(
          postId: 'explore',
          likeCount: 1,
          liked: true,
          commentCount: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.likes, 1);
      expect(
        find.descendant(
          of: action,
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(action).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  setUp(() {
    _testClient = SupabaseClient(
      'https://unit.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => _testClient.dispose());

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
      await tester.tap(find.byKey(const Key('community-post-editor-close')));
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

  testWidgets(
    'feed composer is branded as a post and hides its own author story',
    (tester) async {
      final repository = _FeedRepository()
        ..feed = [
          CommunityPost(
            id: 'own-post',
            authorId: '11111111-1111-4111-8111-111111111111',
            authorName: 'Current member',
            body: 'My own post',
            createdAt: DateTime.utc(2026, 9, 8),
          ),
          CommunityPost(
            id: 'friend-post',
            authorId: '22222222-2222-4222-8222-222222222222',
            authorName: 'Friend member',
            body: 'Friend post',
            createdAt: DateTime.utc(2026, 9, 7),
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(home: CommunityHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('community-create-post-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('community-story-11111111-1111-4111-8111-111111111111'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('community-story-22222222-2222-4222-8222-222222222222'),
        ),
        findsOneWidget,
      );
      expect(find.text('My own post'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pull-to-refresh keeps community posts anchored', (tester) async {
    final repository = _FeedRepository();
    await tester.pumpWidget(
      MaterialApp(home: CommunityHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final scroll = find.byType(CustomScrollView).first;
    final physics = tester.widget<CustomScrollView>(scroll).physics;
    expect(physics, isA<ClampingScrollPhysics>());
    expect(physics?.parent, isA<AlwaysScrollableScrollPhysics>());
    final body = find.text('A saved community post');
    final before = tester.getTopLeft(body).dy;

    await tester.drag(scroll, const Offset(0, 160));
    await tester.pumpAndSettle();

    expect(repository.feedLoads, greaterThanOrEqualTo(2));
    expect(tester.getTopLeft(body).dy, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });
}
