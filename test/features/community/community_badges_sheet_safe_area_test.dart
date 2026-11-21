// Actual self-profile -> Stats -> Badges route. Host-only repository; no cloud.
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../visual_closure/visual_evidence_font.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _badgeKeys = [
  'profile_complete',
  'first_moment',
  'contributor',
  'conversation_starter',
  'appreciated',
  'connector',
  'referral_builder',
];

class _BadgeRepository extends CommunityRepository {
  _BadgeRepository(super.client);
  @override
  String get currentUserId => _owner;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview(
        userId: _owner,
        displayName: 'Badge fixture',
        isSelf: true,
        relationship: CommunityRelationshipStatus.none,
        allowFriendRequests: true,
        allowFollows: true,
        showFollowers: true,
        showFollowing: true,
        showFriends: true,
        showPosts: true,
        showMembershipTier: false,
        handle: 'badge_fixture',
        followerCount: 0,
        followingCount: 0,
        friendCount: 0,
        postCount: 0,
        communityXp: 0,
        communityLevel: 1,
        communityLevelCopyKey: 'community_level_1',
        currentLevelMinXp: 0,
        nextCommunityLevel: 2,
        nextLevelMinXp: 100,
        viewerFollows: false,
        followsViewer: false,
      );
  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => const CommunityFeedBatch(posts: [], hasMore: false);
  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async => CommunityCreatorProfile(
    userId: _owner,
    contributor: false,
    approvedPosts: 0,
    followers: 0,
    likesReceived: 0,
    commentsReceived: 0,
    qualifiedReferrals: 0,
    communityXp: 0,
    communityLevel: 1,
    currentLevelMinXp: 0,
    nextCommunityLevel: 2,
    nextLevelMinXp: 100,
    earnedBadgeCount: 0,
    totalBadgeCount: 7,
    badges: [
      for (final key in _badgeKeys)
        CommunityCreatorBadge(badgeKey: key, earned: false),
    ],
    certificationStatus: CommunityCreatorCertificationStatus.notCertified,
  );
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async => {};
  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> postIds) async => [];
  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => [];
  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async => [];
  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async => null;
  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      throw StateError('Host rewards unavailable');
  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  late SupabaseClient client;
  late MockClient transport;
  late _BadgeRepository repository;
  final requests = <String>[];
  setUp(() {
    requests.clear();
    transport = MockClient((request) async {
      requests.add(request.url.path);
      return http.Response('Unexpected host request', 500, request: request);
    });
    // Keep SDK isolate lifecycle outside WidgetTest FakeAsync.
    client = SupabaseClient(
      'https://badges-host.invalid',
      'host-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport,
    );
    repository = _BadgeRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    transport.close();
  });

  for (final sample in [
    (width: 320.0, height: 568.0, locale: 'en', scale: 1.0),
    (width: 390.0, height: 844.0, locale: 'en', scale: 1.0),
    (width: 320.0, height: 568.0, locale: 'ar', scale: 1.0),
    (width: 390.0, height: 844.0, locale: 'ar', scale: 1.0),
    (width: 320.0, height: 568.0, locale: 'en', scale: 2.0),
    (width: 390.0, height: 844.0, locale: 'ar', scale: 2.0),
  ]) {
    testWidgets(
      'badge sheet retains full final row above navigation inset ${sample.width}/${sample.locale}/${sample.scale}',
      (tester) async {
        const bottomInset = 48.0;
        tester.view.physicalSize = Size(sample.width, sample.height);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(
          top: 24,
          bottom: bottomInset,
        );
        tester.view.viewPadding = const FakeViewPadding(
          top: 24,
          bottom: bottomInset,
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() {
          tester.view.reset();
          debugDefaultTargetPlatformOverride = null;
        });
        final arabic = sample.locale == 'ar';
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: visualEvidenceTheme(
                BilFlagshipTheme.light(isArabic: arabic),
                fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
              ),
              locale: Locale(sample.locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(sample.scale)),
                child: child!,
              ),
              home: CommunityMemberProfilePage(
                userId: _owner,
                repository: repository,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final stats = find.byKey(const Key('community-self-stats'));
          final pageScroll = find
              .descendant(
                of: find.byType(CommunityMemberProfilePage),
                matching: find.byWidgetPredicate(
                  (w) => w is Scrollable && w.axis == Axis.vertical,
                ),
              )
              .first;
          await tester.scrollUntilVisible(
            stats.hitTestable(),
            160,
            scrollable: pageScroll,
          );
          await tester.tap(stats.hitTestable());
          await tester.pumpAndSettle();
          final badges = find.byKey(const Key('community-creator-badges'));
          await tester.ensureVisible(badges);
          await tester.pumpAndSettle();
          await tester.tap(badges.hitTestable());
          await tester.pumpAndSettle();
          final heading = find.byKey(
            const Key('community-badges-pinned-heading'),
          );
          final last = find.byKey(
            const Key('community-creator-badge-referral_builder'),
          );
          expect(heading, findsOneWidget);
          expect(last, findsOneWidget);
          final body = find.ancestor(
            of: last,
            matching: find.byType(SingleChildScrollView),
          );
          final scrolling = find.ancestor(
            of: last,
            matching: find.byType(Scrollable),
          );
          expect(body, findsOneWidget);
          expect(scrolling, findsOneWidget);
          final position = tester.state<ScrollableState>(scrolling).position;
          final headingBefore = tester.getRect(heading);
          final initialOffset = position.pixels;
          for (var i = 0; i < 6; i++) {
            final viewport = tester.getRect(body);
            final row = tester.getRect(last);
            if (row.top >= viewport.top &&
                row.bottom <= viewport.bottom &&
                row.bottom <= sample.height - bottomInset) {
              break;
            }
            await tester.drag(body, const Offset(0, -220));
            await tester.pumpAndSettle();
          }
          // One ordinary user swipe also proves the body gesture leaves the header fixed.
          await tester.drag(body, const Offset(0, -120));
          await tester.pumpAndSettle();
          final headingAfter = tester.getRect(heading);
          final row = tester.getRect(last);
          final viewport = tester.getRect(body);
          final subtitle = find.descendant(
            of: last,
            matching: find.text(arabic ? 'مقفلة' : 'Locked'),
          );
          final subtitleRect = tester.getRect(subtitle);
          debugPrint(
            'BADGE_GEOMETRY ${sample.width}/${sample.locale}/${sample.scale}: header=$headingAfter body=$viewport last=$row subtitle=$subtitleRect scroll=$initialOffset->${position.pixels}/${position.maxScrollExtent} safeBottom=${sample.height - bottomInset}',
          );
          expect(
            headingAfter.topLeft.dx,
            closeTo(headingBefore.topLeft.dx, .5),
          );
          expect(
            headingAfter.topLeft.dy,
            closeTo(headingBefore.topLeft.dy, .5),
          );
          expect(row.top, greaterThanOrEqualTo(viewport.top - .5));
          expect(row.bottom, lessThanOrEqualTo(viewport.bottom + .5));
          expect(
            row.bottom,
            lessThanOrEqualTo(sample.height - bottomInset + .5),
            reason:
                'The complete final badge must be reachable above Android navigation, not merely AX-present behind it',
          );
          expect(
            subtitleRect.bottom,
            lessThanOrEqualTo(sample.height - bottomInset + .5),
          );
          expect(last.hitTestable(), findsOneWidget);
          if (position.maxScrollExtent > 1) {
            expect(position.pixels, greaterThan(initialOffset));
          }
          expect(requests, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
