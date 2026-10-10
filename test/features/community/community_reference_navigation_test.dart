import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

class _NavigationRepository extends CommunityRepository {
  _NavigationRepository(super.client);
  static const owner = '11111111-1111-4111-8111-111111111111';
  final requests =
      <
        ({
          CommunityFeedMode mode,
          int? priority,
          DateTime? before,
          String? beforeId,
        })
      >[];
  bool twoPages = false;
  bool empty = false;
  Completer<CommunityFeedModeBatch>? delayedExplore;
  @override
  String get currentUserId => owner;
  @override
  bool get useServerCommunityReferenceParity => false;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfile?> loadMyProfile() async => const CommunityProfile(
    userId: owner,
    displayName: 'QA member',
    localeCode: 'en',
    discoverable: false,
  );
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      CommunityProfileOverview.fromProfile((await loadMyProfile())!);
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [];
  @override
  Future<CommunityAttention> loadAttention() async =>
      const CommunityAttention(incomingRequests: 2, unreadMessages: 3);
  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async => const [];
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'fixture-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://policy.invalid/community',
      'effective_at': '2026-10-01T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  CommunityFeedModeBatch page(CommunityFeedMode mode, {bool older = false}) {
    final posts = <CommunityPost>[
      if (!empty)
        for (var index = 0; index < 2; index++)
          CommunityPost(
            id: '66666666-6666-4666-8666-6666666666${mode.index}${older ? index + 2 : index}',
            authorId: owner,
            authorName: 'QA member',
            body: '${mode.wireValue} server item ${older ? index + 2 : index}',
            createdAt: DateTime.utc(2026, 10, 5, 10 - index),
          ),
    ];
    return CommunityFeedModeBatch(
      posts: posts,
      hasMore: twoPages && !older && !empty,
      references: [
        for (final post in posts)
          CommunityFeedReference(
            postId: post.id,
            createdAt: post.createdAt,
            priority: 70,
            reasons: const ['followed_author'],
          ),
      ],
      nextPriority: posts.isEmpty ? null : 70,
      nextBefore: posts.lastOrNull?.createdAt,
      nextBeforeId: posts.lastOrNull?.id,
    );
  }

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    expect(limit, 40);
    requests.add((
      mode: mode,
      priority: beforePriority,
      before: before,
      beforeId: beforeId,
    ));
    if (mode == CommunityFeedMode.explore && delayedExplore != null) {
      return delayedExplore!.future;
    }
    return page(mode, older: before != null);
  }
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _NavigationRepository repository, {
  String initial = '/community',
  String language = 'en',
  Brightness brightness = Brightness.light,
  double scale = 1,
  GlobalKey? captureKey,
}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/community',
        builder: (_, _) =>
            CommunityHubPage(repository: repository, entryWelcomeHandled: true),
      ),
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => CommunitySurface(
          child: CommunityNotificationsPage(repository: repository),
        ),
      ),
      for (final route in [
        '/dashboard',
        '/intelligence-center',
        '/settings',
        '/daily-log',
      ])
        GoRoute(
          path: route,
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text(state.uri.toString(), key: const Key('destination')),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: visualEvidenceTheme(
          ThemeData(brightness: brightness),
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: captureKey, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

Future<void> _mode(WidgetTester tester, CommunityFeedMode mode) async {
  await tester.tap(find.byKey(const Key('community-settings')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('community-navigation-sheet')), findsOneWidget);
  await tester.tap(find.byKey(const Key('community-feed-mode-menu')));
  await tester.pumpAndSettle();
  for (final value in CommunityFeedMode.values) {
    expect(
      find.byKey(Key('community-feed-mode-${value.wireValue}')),
      findsOneWidget,
    );
  }
  await tester.tap(find.byKey(Key('community-feed-mode-${mode.wireValue}')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('community-navigation-sheet')), findsNothing);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['BIL_NAVIGATION_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1.5);
    try {
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    } finally {
      bitmap.dispose();
    }
  });
}

void main() {
  late SupabaseClient client;
  late _NavigationRepository repository;
  setUpAll(loadVisualEvidenceFont);
  setUp(() {
    client = SupabaseClient(
      'https://navigation.invalid',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = _NavigationRepository(client);
  });
  tearDown(() async => client.dispose());

  testWidgets('Community tab has no Back when it is the root', (tester) async {
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-safe-return')), findsNothing);
    expect(find.byKey(const Key('bil-reference-navigation')), findsOneWidget);
  });

  testWidgets('Community opened over another page provides real Back', (
    tester,
  ) async {
    final router = await _mount(tester, repository, initial: '/dashboard');
    router.push('/community');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-safe-return')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
  });

  testWidgets('one Home tab row retains all four authoritative feed modes', (
    tester,
  ) async {
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.requests.map((value) => value.mode), [
      CommunityFeedMode.explore,
    ]);
    expect(find.byKey(const Key('community-feed-mode-menu')), findsNothing);
    expect(find.text('Explore'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-hub-following-tab')));
    await tester.pumpAndSettle();
    expect(repository.requests.last.mode, CommunityFeedMode.following);
    await _mode(tester, CommunityFeedMode.friends);
    expect(repository.requests.last.mode, CommunityFeedMode.friends);
    final feed = tester.widget<Semantics>(
      find.byKey(const Key('community-public-feed')),
    );
    expect(feed.properties.value, 'Friends');
    await _mode(tester, CommunityFeedMode.forYou);
    expect(repository.requests.last.mode, CommunityFeedMode.forYou);
    await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
    await tester.pumpAndSettle();
    expect(repository.requests.map((value) => value.mode), [
      CommunityFeedMode.explore,
      CommunityFeedMode.following,
      CommunityFeedMode.friends,
      CommunityFeedMode.forYou,
      CommunityFeedMode.explore,
    ]);
    expect(
      repository.requests.every(
        (value) => value.before == null && value.beforeId == null,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mode picker works from Circles and pagination uses the selected server cursor',
    (tester) async {
      repository.twoPages = true;
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-hub-circles-tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-circles-list')), findsOneWidget);
      await _mode(tester, CommunityFeedMode.friends);
      expect(repository.requests.last.mode, CommunityFeedMode.friends);
      final expectedCursor = repository.page(CommunityFeedMode.friends);
      await tester.scrollUntilVisible(
        find.byKey(const Key('community-feed-load-more')),
        220,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('community-public-feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('community-feed-load-more')));
      await tester.pumpAndSettle();
      expect(repository.requests.last, (
        mode: CommunityFeedMode.friends,
        priority: expectedCursor.nextPriority,
        before: expectedCursor.nextBefore,
        beforeId: expectedCursor.nextBeforeId,
      ));
      expect(find.text('friends server item 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late Explore readback cannot replace the newly selected Following feed',
    (tester) async {
      final pending = Completer<CommunityFeedModeBatch>();
      repository.delayedExplore = pending;
      await _mount(tester, repository);
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pumpAndSettle();
      expect(find.text('following server item 0'), findsOneWidget);
      pending.complete(repository.page(CommunityFeedMode.explore));
      await tester.pumpAndSettle();
      expect(find.text('following server item 0'), findsOneWidget);
      expect(find.text('explore server item 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final initial in ['/community', '/community/notifications']) {
    testWidgets(
      '$initial opens actual Quick Add, keeps its page on dismiss and sends food to Food Log',
      (tester) async {
        final router = await _mount(
          tester,
          repository,
          initial: initial,
          brightness: Brightness.dark,
        );
        await tester.pumpAndSettle();
        final box = tester.widget<DecoratedBox>(
          find.byKey(const Key('bil-reference-nav-surface')),
        );
        expect(
          (box.decoration as BoxDecoration).gradient!.colors.first,
          const Color(0xFF121B28),
        );
        await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
        await tester.pumpAndSettle();
        expect(find.byType(BilQuickAddSheet), findsOneWidget);
        expect(find.byKey(const Key('community-post-publish')), findsNothing);
        await tester.tapAt(const Offset(10, 20));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, initial);
        await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quick-add-primary-0')));
        await tester.pumpAndSettle();
        final uri = GoRouterState.of(
          tester.element(find.byKey(const Key('destination'))),
        ).uri;
        expect(uri.path, '/daily-log');
        expect(uri.queryParameters, {'foodLog': '1', 'from': initial});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'native Home and Notifications $language ${brightness.name} $scale',
          (tester) async {
            final key = GlobalKey();
            final router = await _mount(
              tester,
              repository,
              captureKey: key,
              language: language,
              brightness: brightness,
              scale: scale,
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('community-feed-mode-menu')),
              findsNothing,
            );
            var tallestTabText = 0.0;
            for (final id in ['explore', 'following', 'circles']) {
              final tab = find.byKey(Key('community-hub-$id-tab'));
              final label = find.descendant(
                of: tab,
                matching: find.byType(Text),
              );
              final text = tester.widget<Text>(label);
              expect(text.maxLines, isNull);
              expect(text.overflow, isNot(TextOverflow.ellipsis));
              final bounds = tester.getRect(label);
              expect(
                bounds.height + 20,
                lessThanOrEqualTo(tester.getSize(tab).height + .1),
              );
              if (bounds.height > tallestTabText) {
                tallestTabText = bounds.height;
              }
            }
            expect(
              tester
                  .getSize(find.byKey(const Key('community-hub-explore-tab')))
                  .height,
              closeTo(tallestTabText + 20 < 48 ? 48 : tallestTabText + 20, .1),
            );
            for (final id in ['photo', 'poll', 'circles', 'coach']) {
              final action = find.byKey(Key('community-compose-$id'));
              final bounds = tester.getRect(action);
              expect(bounds.height, greaterThanOrEqualTo(48));
              expect(bounds.width, greaterThanOrEqualTo(48));
              final icon = tester.getRect(
                find.descendant(of: action, matching: find.byType(Icon)),
              );
              final label = tester.getRect(
                find.descendant(of: action, matching: find.byType(Text)),
              );
              if (language == 'ar') {
                expect(icon.left, greaterThanOrEqualTo(label.right));
              } else {
                expect(icon.right, lessThanOrEqualTo(label.left));
              }
              expect((icon.center.dy - label.center.dy).abs(), lessThan(1));
            }
            expect(tester.takeException(), isNull);
            await _capture(
              tester,
              key,
              'home_${language}_${brightness.name}_$scale',
            );
            router.go('/community/notifications');
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('bil-reference-navigation')),
              findsOneWidget,
            );
            await _capture(
              tester,
              key,
              'notifications_${language}_${brightness.name}_$scale',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
