import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _member = '22222222-2222-4222-8222-222222222222';
const _allowed = '33333333-3333-4333-8333-333333333333';
const _ownPostId = '44444444-4444-4444-8444-444444444444';
const _memberName = 'Synthetic blocked member';
const _ownBody = 'My removable fixture';
const _allowedBody = 'Unaffected authorized content';

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://member-return.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'code': 'PGRST202',
            'message': 'Synthetic optional RPC absent',
          }),
          404,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
  });
  tearDown(() => client.dispose());

  for (final backgroundPending in [false, true]) {
    testWidgets(
      'Find people block refreshes stories despite old background=$backgroundPending',
      (tester) async {
        final repository = _Repository(client)
          ..backgroundPending = backgroundPending;
        final router = _router(repository);
        await _pump(tester, router);
        final story = find.byKey(const ValueKey('community-story-$_member'));
        expect(story, findsOneWidget);
        expect(find.text(_allowedBody), findsOneWidget);
        final stalePage = repository.page;

        await tester.tap(find.byKey(const Key('community-search')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_memberName));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-member-safety')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block member'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('community-member-confirm-block')),
        );
        await tester.pumpAndSettle();
        expect(repository.blockCalls, 1);
        expect(find.text(_memberName), findsNothing);

        final refreshed = Completer<CommunityFeedModeBatch>();
        repository.nextFeed = refreshed;
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(repository.feedReads, 2);
        // Keep already rendered content anchored during this explicit reload.
        expect(find.text(_allowedBody), findsOneWidget);
        expect(refreshed.isCompleted, isFalse);
        refreshed.complete(repository.page);
        await tester.pumpAndSettle();
        expect(story, findsNothing);
        expect(find.text(_allowedBody), findsOneWidget);
        if (backgroundPending) {
          repository.oldBackgroundRefresh!(stalePage);
          await tester.pumpAndSettle();
          expect(story, findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
      },
    );
  }

  for (final language in ['en', 'ar']) {
    for (final denied in [false, true]) {
      testWidgets(
        'profile error explains unavailable without guessing block $language denied=$denied',
        (tester) async {
          final repository = _Repository(client)
            ..profileFailure = denied
                ? const PostgrestException(
                    message: 'community_profile_unavailable',
                    code: '42501',
                  )
                : StateError('Synthetic network unavailable');
          final router = _router(
            repository,
            initial: '/community/profile/$_member',
          );
          await _pump(tester, router, locale: Locale(language));
          final message = tester
              .widget<Text>(
                find.byKey(const Key('community-profile-load-error-message')),
              )
              .data!;
          expect(
            message,
            language == 'ar'
                ? denied
                      ? 'هذا الملف الشخصي غير متاح.'
                      : 'تعذر تحميل هذا الملف الشخصي. أعد المحاولة.'
                : denied
                ? 'This profile is unavailable.'
                : 'Could not load this profile. Try again.',
          );
          expect(message.toLowerCase(), isNot(contains('blocked')));
          expect(
            find.byKey(const Key('community-profile-load-retry')),
            findsOneWidget,
          );
          expect(find.text(_memberName), findsNothing);
          expect(find.text('Previously authorized member post'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          router.dispose();
        },
      );
    }
  }

  testWidgets(
    'Find people block refreshes selected category and retires older reads',
    (tester) async {
      final repository = _Repository(client)
        ..backgroundPending = true
        ..topicEnabled = true;
      final router = _router(repository);
      await _pump(tester, router);
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.topicReads, 1);
      final memberCard = find.byKey(
        const ValueKey('community-category-post-member-post'),
      );
      expect(memberCard, findsOneWidget);
      final staleFeed = repository.page;
      final staleTopic = repository.topicPage;

      // Keep an older category pagination read pending before the block.
      // Returning must supersede it as well as the background Explore read.
      final olderTopic = Completer<CommunityTopicPostBatch>();
      addTearDown(() {
        if (!olderTopic.isCompleted) olderTopic.complete(staleTopic);
      });
      repository.nextTopic = olderTopic;
      final more = find.byKey(const Key('community-category-load-more'));
      await tester.scrollUntilVisible(
        more,
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('community-public-feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(more);
      await tester.pump();
      expect(repository.topicReads, 2);

      await tester.tap(find.byKey(const Key('community-search')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_memberName));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-member-safety')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block member'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-member-confirm-block')));
      await tester.pumpAndSettle();
      expect(repository.blockCalls, 1);

      final refreshedFeed = Completer<CommunityFeedModeBatch>();
      final refreshedTopic = Completer<CommunityTopicPostBatch>();
      addTearDown(() {
        if (!refreshedFeed.isCompleted) refreshedFeed.complete(repository.page);
        if (!refreshedTopic.isCompleted) {
          refreshedTopic.complete(repository.topicPage);
        }
      });
      repository.nextFeed = refreshedFeed;
      repository.nextTopic = refreshedTopic;
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.feedReads, 2);
      expect(repository.topicReads, 3);
      refreshedFeed.complete(repository.page);
      refreshedTopic.complete(repository.topicPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(memberCard, findsNothing);
      expect(
        find.byKey(const ValueKey('community-category-post-allowed-post')),
        findsOneWidget,
      );

      olderTopic.complete(staleTopic);
      repository.oldBackgroundRefresh!(staleFeed);
      await tester.pumpAndSettle();
      expect(memberCard, findsNothing);
      expect(
        find.byKey(const ValueKey('community-story-$_member')),
        findsNothing,
      );
      expect(repository.topicReads, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
    },
  );

  testWidgets(
    'deletion in My posts refreshes parent profile count and card on return',
    (tester) async {
      final repository = _Repository(client);
      final router = _router(repository, initial: '/community/profile/$_owner');
      await _pump(tester, router);
      expect(find.text(_ownBody), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('My posts'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('community-post-actions-$_ownPostId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, 1);
      expect(find.text(_ownBody), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repository.profileReads, greaterThanOrEqualTo(2));
      expect(find.text(_ownBody), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(
        find.byKey(const Key('community-member-profile-page')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
    },
  );
}

GoRouter _router(_Repository repository, {String initial = '/community'}) =>
    GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, _) => CommunityHubPage(
            repository: repository,
            entryWelcomeHandled: true,
          ),
        ),
        GoRoute(
          path: '/community/people',
          builder: (_, _) => CommunityPeoplePage(repository: repository),
        ),
        GoRoute(
          path: '/community/profile/:id',
          builder: (_, state) => CommunityMemberProfilePage(
            userId: state.pathParameters['id']!,
            repository: repository,
          ),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  GoRouter router, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    ),
  );
  // A deliberately held cache refresh has an active indicator; settle would
  // incorrectly wait for that controlled request instead of the ready page.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

final class _Repository extends CommunityRepository {
  _Repository(super.client);
  bool blocked = false;
  bool ownDeleted = false;
  bool backgroundPending = false;
  bool topicEnabled = false;
  int feedReads = 0;
  int topicReads = 0;
  int profileReads = 0;
  int blockCalls = 0;
  int deleteCalls = 0;
  Object? profileFailure;
  Completer<CommunityFeedModeBatch>? nextFeed;
  Completer<CommunityTopicPostBatch>? nextTopic;
  void Function(CommunityFeedModeBatch)? oldBackgroundRefresh;

  @override
  String get currentUserId => _owner;
  @override
  bool get useServerRankedCommunityFeed => true;
  @override
  bool get useServerCommunityReferenceParity => false;

  CommunityPost get ownPost => CommunityPost(
    id: _ownPostId,
    authorId: _owner,
    body: _ownBody,
    createdAt: DateTime.utc(2026, 11, 8),
  );
  CommunityFeedModeBatch get page => CommunityFeedModeBatch(
    posts: [
      if (!blocked)
        CommunityPost(
          id: 'member-post',
          authorId: _member,
          authorName: _memberName,
          body: 'Previously authorized member post',
          createdAt: DateTime.utc(2026, 11, 8),
        ),
      CommunityPost(
        id: 'allowed-post',
        authorId: _allowed,
        authorName: 'Allowed member',
        body: _allowedBody,
        createdAt: DateTime.utc(2026, 11, 8),
      ),
    ],
    references: const [],
    hasMore: false,
  );

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required void Function() onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) async {
    feedReads++;
    if (feedReads == 1 && backgroundPending) {
      oldBackgroundRefresh = onRefresh;
      onRefreshing();
    }
    final held = nextFeed;
    nextFeed = null;
    return held == null ? page : await held.future;
  }

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => page;
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => topicEnabled
      ? const [
          CommunityTopic(
            slug: 'nutrition',
            titleCopyKey: 'topic_title',
            descriptionCopyKey: 'topic_description',
            iconKey: 'nutrition',
            featured: false,
            followerCount: 0,
            postCount: 2,
            following: false,
          ),
        ]
      : [];

  CommunityTopicPostBatch get topicPage => CommunityTopicPostBatch(
    posts: page.posts,
    hasMore: !blocked,
    nextBefore: blocked ? null : DateTime.utc(2026, 11, 8),
    nextBeforeId: blocked ? null : 'allowed-post',
  );

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    expect(slug, 'nutrition');
    topicReads++;
    final held = nextTopic;
    nextTopic = null;
    return held == null ? topicPage : await held.future;
  }

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async =>
      CommunityPolicyState.accepted(_policy, acceptedVersion: _policy.version);
  static final _policy = CommunityContentPolicy.fromJson({
    'version': 'community-policy-v1',
    'locale_code': 'en',
    'document_url': 'https://www.bilhealth.com/community-guidelines',
    'effective_at': '2026-09-08T00:00:00Z',
  });
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      _overview(_owner);
  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    profileReads++;
    if (profileFailure case final failure?) throw failure;
    if (blocked && userId == _member) {
      throw const PostgrestException(
        message: 'community_profile_unavailable',
        code: '42501',
      );
    }
    return _overview(userId);
  }

  CommunityProfileOverview _overview(String userId) => CommunityProfileOverview(
    userId: userId,
    displayName: userId == _owner ? 'My synthetic profile' : _memberName,
    isSelf: userId == _owner,
    relationship: CommunityRelationshipStatus.none,
    allowFriendRequests: true,
    allowFollows: true,
    showFollowers: true,
    showFollowing: true,
    showFriends: true,
    showPosts: true,
    showMembershipTier: false,
    followerCount: 0,
    followingCount: 0,
    friendCount: 0,
    postCount: userId == _owner
        ? ownDeleted
              ? 0
              : 1
        : blocked
        ? 0
        : 1,
  );
  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => CommunityFeedBatch(
    posts: userId == _owner
        ? ownDeleted
              ? []
              : [ownPost]
        : blocked
        ? []
        : page.posts.where((post) => post.authorId == _member).toList(),
    hasMore: false,
  );
  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async =>
      blocked
      ? []
      : [
          {'user_id': _member, 'display_name': _memberName},
        ];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [];
  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => [];
  @override
  Future<void> blockMember(String userId) async {
    expect(userId, _member);
    blockCalls++;
    blocked = true;
  }

  @override
  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async =>
      CommunityFeedBatch(posts: ownDeleted ? [] : [ownPost], hasMore: false);
  @override
  Future<void> deletePost(String postId) async {
    expect(postId, _ownPostId);
    deleteCalls++;
    ownDeleted = true;
  }
}
