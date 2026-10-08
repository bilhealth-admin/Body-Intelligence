import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/home_profile/community_profile_activity_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _other = '33333333-3333-4333-8333-333333333333';
const _post1 = '44444444-4444-4444-8444-444444444441';
const _post2 = '44444444-4444-4444-8444-444444444442';
const _post3 = '44444444-4444-4444-8444-444444444443';
const _comment1 = '55555555-5555-4555-8555-555555555551';
const _comment2 = '55555555-5555-4555-8555-555555555552';
const _pollOption1 = '66666666-6666-4666-8666-666666666661';
const _pollOption2 = '66666666-6666-4666-8666-666666666662';

class _AuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};

  late final SupabaseClient client = SupabaseClient(
    'https://bil08.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
              )
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
              'refresh_token': 'synthetic-refresh-$owner',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': owner,
                'email': 'bil08@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-10-07T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path == '/auth/v1/logout') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        throw StateError('Unexpected network request: ${request.url}');
      }),
    ),
  );

  Future<void> signIn(String id) async {
    owner = id;
    await client.auth.signInWithPassword(
      email: 'bil08@example.invalid',
      password: 'synthetic-password',
    );
    sessions[id] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> roundTrip() async {
    final b = client.auth.recoverSession(sessions[_ownerB]!);
    final a = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([b, a]);
  }
}

CommunityPoll _poll() => CommunityPoll(
  postId: _post1,
  question: 'Which habit should continue?',
  allowMultiple: false,
  closed: false,
  totalVotes: 3,
  options: const [
    CommunityPollOption(
      id: _pollOption1,
      position: 0,
      text: 'Walk',
      voteCount: 2,
      selected: false,
    ),
    CommunityPollOption(
      id: _pollOption2,
      position: 1,
      text: 'Sleep',
      voteCount: 1,
      selected: false,
    ),
  ],
);

List<CommunityPostMedia> _fourDeletedMedia(String postId) => List.generate(
  4,
  (index) => CommunityPostMedia(
    position: index,
    objectPath: '$_ownerA/$postId/$index.webp',
    mimeType: 'image/webp',
    bytes: 128,
    width: 600,
    height: 600,
  ),
);

CommunityPost _post(
  String id,
  String authorId,
  String body, {
  bool rich = false,
}) => CommunityPost(
  id: id,
  authorId: authorId,
  authorName: authorId == _ownerA ? 'Owner A' : 'Member B',
  body: body,
  createdAt: DateTime.utc(2026, 10, 7, 8, id == _post1 ? 1 : 2),
  moderationStatus: CommunityPostModerationStatus.approved,
  media: rich ? _fourDeletedMedia(id) : const [],
  poll: rich ? _poll() : null,
);

CommunityProfileOverview _profile(
  String userId, {
  required bool self,
  bool showPosts = true,
}) => CommunityProfileOverview(
  userId: userId,
  displayName: self ? 'Owner A' : 'Other member',
  isSelf: self,
  relationship: self
      ? CommunityRelationshipStatus.self
      : CommunityRelationshipStatus.none,
  allowFriendRequests: true,
  allowFollows: true,
  showFollowers: true,
  showFollowing: true,
  showFriends: true,
  showPosts: showPosts,
  showMembershipTier: false,
  postCount: showPosts ? 3 : null,
);

class _Repository extends CommunityRepository {
  _Repository(super.client);

  bool otherPostsVisible = true;
  Completer<void>? pendingLike;
  int likeMutations = 0;
  final feedPosts = <CommunityPost>[
    _post(_post1, _ownerA, 'Rich owner post', rich: true),
    _post(_post2, _ownerA, 'Second owner post'),
  ];

  @override
  bool get useServerCommunityReferenceParity => false;

  @override
  void invalidateCommunityModeratorStatus() {}

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      _profile(currentUserId, self: true);

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      _profile(
        userId,
        self: userId == currentUserId,
        showPosts: userId == currentUserId || otherPostsVisible,
      );

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (userId != currentUserId && !otherPostsVisible) {
      return const CommunityFeedBatch(posts: [], hasMore: false);
    }
    if (before != null) {
      return CommunityFeedBatch(
        posts: [_post(_post3, userId, 'Older page post')],
        hasMore: false,
      );
    }
    return CommunityFeedBatch(
      posts: [
        _post(_post1, userId, 'Rich owner post', rich: userId == currentUserId),
        _post(_post2, userId, 'Second owner post'),
      ],
      hasMore: true,
      nextBefore: DateTime.utc(2026, 10, 7, 7),
      nextBeforeId: _post2,
    );
  }

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => const CommunityPolicyState.unavailable();

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => CommunityFeedModeBatch(
    posts: List.unmodifiable(feedPosts),
    references: const [],
    hasMore: false,
  );

  @override
  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) async {
    likeMutations++;
    final pending = pendingLike;
    pendingLike = null;
    if (pending != null) await pending.future;
    return CommunityPostStats(
      postId: postId,
      likeCount: liked ? 1 : 0,
      liked: liked,
      commentCount: 0,
    );
  }
}

class _ActivityDataSource implements CommunityProfileActivityDataSource {
  int replyCalls = 0;
  int likeCalls = 0;
  bool failNextReplyPage = false;
  Completer<CommunityProfileReplyPage>? pendingReplies;
  final replyCursors = <({DateTime? before, String? beforeId})>[];

  @override
  Future<CommunityProfileReplyPage> loadReplies({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    replyCalls++;
    replyCursors.add((before: before, beforeId: beforeId));
    final pending = pendingReplies;
    if (pending != null) {
      pendingReplies = null;
      return pending.future;
    }
    if (before != null && failNextReplyPage) {
      failNextReplyPage = false;
      throw StateError('synthetic later page failure');
    }
    if (before == null) {
      return CommunityProfileReplyPage(
        items: [
          CommunityProfileReplyItem(
            comment: CommunityComment(
              id: _comment1,
              authorId: userId,
              body: 'First visible reply',
              createdAt: DateTime.utc(2026, 10, 7, 9),
              likeCount: 2,
              liked: false,
            ),
            post: _post(_post1, userId, 'Reply source post', rich: true),
          ),
        ],
        hasMore: true,
        nextBefore: DateTime.utc(2026, 10, 7, 9),
        nextBeforeId: _comment1,
      );
    }
    return CommunityProfileReplyPage(
      items: [
        CommunityProfileReplyItem(
          comment: CommunityComment(
            id: _comment2,
            authorId: userId,
            parentId: _comment1,
            body: 'Older visible reply',
            createdAt: DateTime.utc(2026, 10, 7, 8),
            likeCount: 0,
            liked: false,
          ),
          post: _post(_post2, userId, 'Older reply source'),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<CommunityProfileLikePage> loadLikes({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    likeCalls++;
    return CommunityProfileLikePage(
      items: [
        CommunityProfileLikedPost(
          post: _post(_post2, _other, 'Actually liked post'),
          likedAt: DateTime.utc(2026, 10, 7, 10),
        ),
      ],
      hasMore: false,
    );
  }
}

Future<void> _visible(WidgetTester tester, Finder finder) async {
  // The approved profile header can exceed a short viewport. Its tabs are
  // lazy slivers and are not built until the main page scrolls them onscreen.
  // Locate real controls by scrolling, rather than assuming they were laid
  // out at the initial screen height.
  if (finder.evaluate().isEmpty) {
    final page = find.byType(CustomScrollView);
    expect(page, findsWidgets);
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find
          .descendant(of: page.first, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 40,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settles = true,
}) async {
  await _visible(tester, finder);
  await tester.tap(finder);
  if (settles) {
    await tester.pumpAndSettle();
  } else {
    // This scenario intentionally holds the network Future pending. A
    // blocking spinner correctly schedules frames until the owner changes;
    // pumpAndSettle would wait forever instead of verifying cancellation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _mountProfile(
  WidgetTester tester,
  _Repository repository,
  _ActivityDataSource activity, {
  String userId = _ownerA,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityMemberProfilePage(
        key: const ValueKey('bil08-profile'),
        userId: userId,
        repository: repository,
        profileActivityDataSource: activity,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  late _AuthFixture auth;
  late _Repository repository;
  late _ActivityDataSource activity;

  setUp(() async {
    auth = _AuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _Repository(auth.client);
    activity = _ActivityDataSource();
  });

  tearDown(() async {
    await auth.client.dispose();
  });

  testWidgets(
    'Profile tabs use distinct real sources with paging retry and rich media',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _mountProfile(tester, repository, activity);

      expect(
        find.byKey(const Key('community-profile-tab-posts')),
        findsOneWidget,
      );
      expect(find.byKey(Key('community-poll-$_post1')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('community-profile-tab-media')));
      for (var index = 0; index < 4; index++) {
        expect(
          find.byKey(Key('community-profile-media-$_post1-$index')),
          findsOneWidget,
        );
      }
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(4));

      await _tap(
        tester,
        find.byKey(const Key('community-profile-tab-replies')),
      );
      expect(find.text('First visible reply'), findsOneWidget);
      expect(activity.replyCalls, 1);
      activity.failNextReplyPage = true;
      await _tap(
        tester,
        find.byKey(const Key('community-profile-replies-load-more')),
      );
      expect(
        find.byKey(const Key('community-profile-replies-page-retry')),
        findsOneWidget,
      );
      final failedCursor = activity.replyCursors.last;
      await _tap(
        tester,
        find.byKey(const Key('community-profile-replies-page-retry')),
      );
      expect(activity.replyCursors.last, failedCursor);
      expect(find.text('Older visible reply'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('community-profile-tab-likes')));
      expect(activity.likeCalls, 1);
      expect(find.text('Actually liked post'), findsOneWidget);
      expect(find.text('Reviews'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'other private profile never probes Replies or Likes data source',
    (tester) async {
      repository.otherPostsVisible = false;
      await _mountProfile(tester, repository, activity, userId: _other);

      await _tap(
        tester,
        find.byKey(const Key('community-profile-tab-replies')),
      );
      expect(
        find.byKey(const Key('community-profile-replies-private')),
        findsOneWidget,
      );
      expect(activity.replyCalls, 0);

      await _tap(tester, find.byKey(const Key('community-profile-tab-likes')));
      expect(
        find.byKey(const Key('community-profile-likes-private')),
        findsOneWidget,
      );
      expect(activity.likeCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queued A B A cancels pending Profile activity read', (
    tester,
  ) async {
    final pending = Completer<CommunityProfileReplyPage>();
    activity.pendingReplies = pending;
    await _mountProfile(tester, repository, activity);
    await _tap(
      tester,
      find.byKey(const Key('community-profile-tab-replies')),
      settles: false,
    );
    expect(activity.replyCalls, 1);

    await auth.roundTrip();
    await tester.pump();
    pending.complete(
      CommunityProfileReplyPage(
        items: [
          CommunityProfileReplyItem(
            comment: CommunityComment(
              id: _comment1,
              authorId: _ownerA,
              body: 'Late private reply',
              createdAt: DateTime.utc(2026, 10, 7, 9),
              likeCount: 0,
              liked: false,
            ),
            post: _post(_post1, _ownerA, 'Late source'),
          ),
        ],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-profile-owner-changed')),
      findsOneWidget,
    );
    expect(find.text('Late private reply'), findsNothing);
  });

  testWidgets(
    'Home menu result captured before ABA cannot navigate successor owner',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(
            repository: repository,
            entryWelcomeHandled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('community-settings')));
      expect(
        find.byKey(const Key('community-navigation-sheet')),
        findsOneWidget,
      );

      await auth.roundTrip();
      await tester.pumpAndSettle();
      final changed = find.byKey(const Key('community-profile-owner-changed'));
      expect(changed, findsOneWidget);

      Navigator.of(tester.element(changed)).pop('saved');
      await tester.pumpAndSettle();
      expect(find.byType(CommunitySavedPostsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending Feed like result cannot land after queued ABA', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pendingLike = pending;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHubPage(
          repository: repository,
          entryWelcomeHandled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(
      tester,
      find.byKey(Key('community-post-like-$_post1')),
      settles: false,
    );
    expect(repository.likeMutations, 1);
    await auth.roundTrip();
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();

    expect(repository.likeMutations, 1);
    // An owner ABA retires the old feed; it must not keep a tappable control
    // belonging to a previous session or replay the late like result.
    expect(find.byKey(Key('community-post-like-$_post1')), findsNothing);
    // The rebuilt Feed does not re-expose the stale post. Without an active
    // production policy this fixture fails closed to the existing safety gate.
    expect(find.text('Community publishing is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile primary tabs remain reachable at 320dp and 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CommunityMemberProfilePage(
            userId: _ownerA,
            repository: repository,
            profileActivityDataSource: activity,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in const [
        Key('community-profile-tab-posts'),
        Key('community-profile-tab-replies'),
        Key('community-profile-tab-media'),
        Key('community-profile-tab-likes'),
      ]) {
        final finder = find.byKey(key);
        await _visible(tester, finder);
        expect(finder.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
