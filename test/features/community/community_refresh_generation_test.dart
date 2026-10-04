import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '22222222-2222-4222-8222-222222222222';
const _viewer = '11111111-1111-4111-8111-111111111111';
final _time = DateTime.utc(2026, 10, 4);

SupabaseClient _client() => SupabaseClient(
  'https://deferred-community-fixture.invalid',
  'synthetic-fixture-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

// These deferred repository boundaries model already-authorized RPC responses.
// They do not mutate Production or prove a genuine device/network transaction.
class _ProfileRepository extends CommunityRepository {
  _ProfileRepository() : super(_client());

  bool private = false;
  int postPages = 0;
  int firstPostPages = 0;
  final returnedPostCounts = <int>[];
  int reviewPages = 0;
  final pendingPosts = Completer<CommunityFeedBatch>();
  final pendingReviews = Completer<List<CommunityProfileReview>>();

  @override
  bool get useServerCommunityReferenceParity => true;

  @override
  String get currentUserId => _viewer;

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview(
        userId: _owner,
        displayName: 'Privacy owner',
        isSelf: false,
        relationship: CommunityRelationshipStatus.none,
        allowFriendRequests: false,
        allowFollows: false,
        showFollowers: false,
        showFollowing: false,
        showFriends: false,
        showPosts: !private,
        showMembershipTier: false,
      );

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (before != null) {
      postPages++;
      final result = await pendingPosts.future;
      returnedPostCounts.add(result.posts.length);
      return result;
    }
    firstPostPages++;
    if (private) {
      returnedPostCounts.add(0);
      return const CommunityFeedBatch(posts: [], hasMore: false);
    }
    returnedPostCounts.add(1);
    final post = _post(30);
    return CommunityFeedBatch(
      posts: [post],
      hasMore: true,
      nextBefore: post.createdAt,
      nextBeforeId: post.id,
    );
  }

  @override
  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    final batch = await loadProfilePosts(
      userId: _owner,
      before: before,
      beforeId: beforeId,
    );
    return CommunitySavedPostBatch(
      posts: batch.posts,
      hasMore: batch.hasMore,
      nextBefore: batch.nextBefore,
      nextBeforeId: batch.nextBeforeId,
    );
  }

  @override
  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) => loadProfilePosts(userId: _owner, before: before, beforeId: beforeId);

  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (before != null) {
      reviewPages++;
      return pendingReviews.future;
    }
    return private ? [] : List.generate(24, _review);
  }

  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async => CommunityCreatorProfile(
    userId: _owner,
    contributor: null,
    approvedPosts: null,
    followers: null,
    likesReceived: null,
    commentsReceived: null,
    postsVisible: !private,
    followersVisible: false,
    qualifiedReferrals: 0,
    communityXp: 0,
    communityLevel: 1,
    currentLevelMinXp: 0,
    earnedBadgeCount: 0,
    totalBadgeCount: 0,
    badges: const [],
    certificationStatus: CommunityCreatorCertificationStatus.notCertified,
  );

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => {for (final id in ids) id: 5};

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) async => [];

  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async => null;
}

CommunityPost _post(int id) => CommunityPost(
  id: '33333333-3333-4333-8333-${id.toString().padLeft(12, '0')}',
  authorId: _owner,
  authorName: 'Privacy owner',
  body: 'STALE private moment $id',
  createdAt: _time.subtract(Duration(minutes: id)),
  moderationStatus: CommunityPostModerationStatus.approved,
);

CommunityProfileReview _review(int id) => CommunityProfileReview(
  reviewId: '44444444-4444-4444-8444-${id.toString().padLeft(12, '0')}',
  productKind: 'food',
  canonicalName: 'Review $id',
  reviewNote: 'STALE private review $id',
  createdAt: _time.subtract(Duration(minutes: id)),
);

class _HistoryRepository extends CommunityRepository {
  _HistoryRepository() : super(_client());

  int firstPages = 0;
  final cursors = <int?>[];
  final returnedFirstRanges = <({int newest, int oldest})>[];
  final pending = Completer<List<CommunityGoldLedgerEntry>>();

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      const CommunityGoldBalance(balance: 200);

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [];

  @override
  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async {
    cursors.add(beforeId);
    if (beforeId == 71 && !pending.isCompleted) return pending.future;
    final newest = beforeId == null
        ? (firstPages++ == 0 ? 100 : 101)
        : beforeId - 1;
    if (beforeId == null) {
      returnedFirstRanges.add((newest: newest, oldest: newest - limit + 1));
    }
    return List.generate(limit, (index) => _entry(newest - index));
  }
}

CommunityGoldLedgerEntry _entry(int id) => CommunityGoldLedgerEntry(
  id: id,
  delta: id,
  balanceAfter: 200,
  sourceKind: 'quest_reward',
  copyKey: 'synthetic_history_row',
  createdAt: _time.add(Duration(minutes: id)),
);

Future<void> _pump(WidgetTester tester, Widget page, String language) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Finder _outer(WidgetTester tester, Type type) {
  final scrollable = find
      .descendant(
        of: find.byType(type).hitTestable(),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(position.axisDirection, AxisDirection.down);
  expect(position.viewportDimension, greaterThan(0));
  return scrollable;
}

Future<void> _more(WidgetTester tester, String language, Type type) async {
  final more = find.widgetWithText(
    TextButton,
    language == 'ar' ? 'تحميل المزيد' : 'Load more',
  );
  final surface = tester.element(_outer(tester, type));
  // Keep the identified outer surface stable while dragging: its center may
  // temporarily stop being hit-testable without that Scrollable being removed.
  final scrollable = find.byElementPredicate(
    (element) => identical(element, surface),
  );
  final list = surface.findAncestorWidgetOfExactType<ListView>();
  final children = list?.childrenDelegate.estimatedChildCount ?? 0;
  // Large-text history rows have natural height. Use the actual fixture row
  // count for a bounded reachability search, not Flutter's default50 drags,
  // which cannot traverse60 tall rows and fails before the cursor assertion.
  final maxScrolls = children > 25 ? children * 2 : 50;
  await tester.scrollUntilVisible(
    more,
    400,
    scrollable: scrollable,
    maxScrolls: maxScrolls,
  );
  await Scrollable.ensureVisible(tester.element(more), alignment: .5);
  await tester.pump();
  expect(more.hitTestable(), findsOneWidget);
  await tester.tap(more.hitTestable());
  await tester.pump();
}

Future<void> _refresh(WidgetTester tester, Type type) async {
  final scrollable = _outer(tester, type);
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  // Start in the real scroll surface's padding rather than a nested selectable
  // post body/action that may win the gesture arena.
  await tester.dragFrom(
    tester.getTopLeft(scrollable) + const Offset(8, 8),
    const Offset(0, 300),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final reviews in [false, true]) {
      testWidgets(
        '$language 200% profile refresh rejects delayed ${reviews ? 'reviews' : 'moments'} after privacy change',
        (tester) async {
          final repository = _ProfileRepository();
          await _pump(
            tester,
            CommunityMemberProfilePage(userId: _owner, repository: repository),
            language,
          );
          if (reviews) {
            final tab = find.byKey(const Key('community-profile-tab-reviews'));
            await tester.scrollUntilVisible(
              tab,
              250,
              scrollable: _outer(tester, CustomScrollView),
            );
            await tester.tap(tab.hitTestable());
            await tester.pump();
          }
          await _more(tester, language, CustomScrollView);
          expect(reviews ? repository.reviewPages : repository.postPages, 1);
          repository.private = true;
          await _refresh(tester, CustomScrollView);
          expect(
            repository.firstPostPages,
            2,
            reason: 'The real refresh gesture must start a new first page.',
          );
          final privateCopy = language == 'ar'
              ? (reviews
                    ? 'المراجعات خاصة في هذا الملف.'
                    : 'اللحظات خاصة في هذا الملف.')
              : (reviews
                    ? 'Reviews are private on this profile.'
                    : 'Moments are private on this profile.');
          await tester.scrollUntilVisible(
            find.text(privateCopy),
            250,
            scrollable: _outer(tester, CustomScrollView),
          );
          expect(find.text(privateCopy), findsOneWidget);
          if (reviews) {
            repository.pendingReviews.complete([_review(99)]);
          } else {
            repository.pendingPosts.complete(
              CommunityFeedBatch(posts: [_post(99)], hasMore: false),
            );
          }
          await tester.pumpAndSettle();
          expect(
            find.text(privateCopy),
            findsOneWidget,
            reason:
                'An earlier authorized RPC response must not restore now-private content.',
          );
          expect(find.textContaining('STALE private'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final saved in [true, false]) {
      testWidgets(
        '$language 200% ${saved ? 'Saved' : 'My'} posts refresh rejects delayed removed content',
        (tester) async {
          final repository = _ProfileRepository();
          await _pump(
            tester,
            saved
                ? CommunitySavedPostsPage(repository: repository)
                : CommunityMyPostsPage(repository: repository),
            language,
          );
          await _more(tester, language, ListView);
          expect(repository.postPages, 1);
          repository.private = true;
          await _refresh(tester, ListView);
          expect(
            repository.firstPostPages,
            2,
            reason: 'The real refresh gesture must start a new first page.',
          );
          // Await the actual page's new first-load future, then paint its
          // completion. Fixed time pumps alone can precede this final frame;
          // settling every animation would hang on the intentionally pending
          // older-page spinner.
          final firstLoad = tester
              .widget<FutureBuilder<void>>(find.byType(FutureBuilder<void>))
              .future!;
          await firstLoad;
          await tester.pump();
          expect(
            repository.returnedPostCounts,
            [1, 0],
            reason:
                'The refreshed server fixture must actually return zero posts before the delayed older response completes.',
          );
          final emptyCopy = saved
              ? (language == 'ar'
                    ? 'المنشورات التي تحفظها خاصة وتظهر هنا.'
                    : 'Posts you save are private and appear here.')
              : (language == 'ar'
                    ? 'تظهر هنا المنشورات التي تنشرها. المنشورات المعلّقة أو المرفوضة لا يراها سواك.'
                    : 'Posts you publish appear here. Pending and rejected posts are visible only to you.');
          expect(find.text(emptyCopy), findsOneWidget);
          repository.pendingPosts.complete(
            CommunityFeedBatch(posts: [_post(99)], hasMore: false),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(emptyCopy),
            findsOneWidget,
            reason:
                'An old authorized page must not undo a newer removal/privacy refresh.',
          );
          expect(find.textContaining('STALE private'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$language 200% refreshed Gold cursor survives delayed older page',
      (tester) async {
        final repository = _HistoryRepository();
        await _pump(
          tester,
          CommunityRewardsPage(repository: repository),
          language,
        );
        await tester.tap(find.text(language == 'ar' ? 'السجل' : 'History'));
        await tester.pumpAndSettle();
        await _more(tester, language, ListView);
        expect(repository.cursors, [null, 71]);
        await _refresh(tester, ListView);
        expect(repository.cursors, [null, 71, null]);
        final firstLoad = tester
            .widget<FutureBuilder>(
              find.byWidgetPredicate((widget) => widget is FutureBuilder),
            )
            .future!;
        await firstLoad;
        await tester.pump();
        expect(
          repository.returnedFirstRanges,
          [(newest: 100, oldest: 71), (newest: 101, oldest: 72)],
          reason:
              'The refreshed authoritative fixture first page must finish101..72 before releasing70..41.',
        );
        repository.pending.complete(
          List.generate(30, (index) => _entry(70 - index)),
        );
        await tester.pumpAndSettle();
        await _more(tester, language, ListView);
        await tester.pumpAndSettle();
        expect(
          repository.cursors.last,
          72,
          reason:
              'The refreshed first page is101..72; stale70..41 must not replace cursor72 and permanently skip71.',
        );
        expect(find.text('+71'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
