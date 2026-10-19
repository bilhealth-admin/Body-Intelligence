import 'package:body_intelligence_log/features/community/presentation/community_post_surface.dart';
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
  bool simulateCachedRefreshFailure = false;
  bool refreshAuthorIdentity = false;
  String cachedAuthorId = owner;
  String cachedAuthorName = 'QA member';
  String? cachedAuthorHandle;
  String? customBody;
  List<CommunityTopic> topicData = const [];
  final categoryRequests = <String>[];
  Future<CommunityTopicPostBatch> Function(String, DateTime?, String?)?
  categoryRead;

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    expect(limit, 30);
    categoryRequests.add(slug);
    if (categoryRead != null) return categoryRead!(slug, before, beforeId);
    return CommunityTopicPostBatch(
      posts: [
        CommunityPost(
          id: slug == 'nutrition'
              ? '77777777-7777-4777-8777-777777777777'
              : '88888888-8888-4888-8888-888888888888',
          authorId: owner,
          body: '$slug category post',
          createdAt: DateTime.utc(2026, 10, 19),
        ),
      ],
      hasMore: false,
    );
  }

  Completer<List<CommunityPostAuthorIdentity>>? authorIdentity;
  @override
  bool get useServerCommunityReferenceParity => refreshAuthorIdentity;
  @override
  Future<List<CommunityPostAuthorIdentity>> loadPostAuthorIdentities(
    List<String> ids,
  ) {
    expect(ids, [cachedAuthorId]);
    return authorIdentity?.future ?? Future.value(const []);
  }

  @override
  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) async => CommunityPostStats(
    postId: postId,
    liked: liked,
    likeCount: liked ? 1 : 0,
    commentCount: 0,
  );

  VoidCallback? failCachedRefresh;
  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required VoidCallback onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) async {
    if (!simulateCachedRefreshFailure) {
      return super.loadCommunityFeedCachedFirst(
        mode: mode,
        locale: locale,
        current: current,
        onRefresh: onRefresh,
        onRefreshing: onRefreshing,
        onRefreshError: onRefreshError,
        limit: limit,
      );
    }
    await Future<void>.delayed(Duration.zero);
    if (current()) onRefreshing();
    failCachedRefresh = () {
      if (current()) onRefreshError(StateError('Synthetic offline refresh'));
    };
    return page(mode);
  }

  bool twoPages = false;
  bool empty = false;
  Completer<CommunityFeedModeBatch>? delayedExplore;
  @override
  String get currentUserId => owner;
  @override
  Future<bool> isCommunityModerator() async => true;
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
  Future<List<CommunityTopic>> loadCommunityTopics() async => topicData;
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
            authorId: cachedAuthorId,
            authorName: cachedAuthorName,
            authorHandle: cachedAuthorHandle,
            body:
                customBody ??
                '${mode.wireValue} server item ${older ? index + 2 : index}',
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

List<CommunityTopic> _categories() => [
  for (final slug in ['nutrition', 'fitness', 'motivation-support', 'wellness'])
    CommunityTopic(
      slug: slug,
      titleCopyKey: 'topic_title',
      descriptionCopyKey: 'topic_description',
      iconKey: 'group',
      featured: false,
      followerCount: 0,
      postCount: 0,
      following: false,
    ),
];

CommunityPost _categoryPost(String slug, {String? id}) => CommunityPost(
  id: id ?? '77777777-7777-4777-8777-777777777777',
  authorId: _NavigationRepository.owner,
  body: '$slug response',
  createdAt: DateTime.utc(2026, 10, 19),
);

Future<GoRouter> _mount(
  WidgetTester tester,
  _NavigationRepository repository, {
  String initial = '/community',
  String language = 'en',
  Brightness brightness = Brightness.light,
  double scale = 1,
  GlobalKey? captureKey,
  bool nestedNavigator = false,
}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final routes = <RouteBase>[
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
  ];
  final router = GoRouter(
    initialLocation: initial,
    routes: nestedNavigator
        ? [ShellRoute(builder: (_, _, child) => child, routes: routes)]
        : routes,
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
  expect(
    find.byKey(const Key('community-nav-/community/moderation')),
    findsNothing,
  );
  expect(
    find.byKey(const Key('community-nav-/community/food-review')),
    findsNothing,
  );
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

  testWidgets('Explore uses bounded body with working inline expansion', (
    tester,
  ) async {
    repository.customBody = List.filled(
      24,
      'A useful community post.',
    ).join(' ');
    final capture = GlobalKey();
    await _mount(tester, repository, captureKey: capture);
    await tester.pumpAndSettle();
    final firstId = repository.page(CommunityFeedMode.explore).posts.first.id;
    final body = find.byKey(Key('community-post-body-$firstId'));
    await tester.ensureVisible(body);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(body).maxLines, 3);
    final surface = find.ancestor(
      of: body,
      matching: find.byType(CommunityPostSurface),
    );
    expect(surface, findsOneWidget);
    final paint =
        tester
                .widget<Container>(
                  find
                      .descendant(of: surface, matching: find.byType(Container))
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(paint.color, Colors.white);
    expect(paint.gradient, isNull);
    final height = tester.getSize(body).height;
    final expand = find.byKey(Key('community-post-expand-$firstId'));
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await _capture(tester, capture, 'explore_compact_post');
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(tester.widget<SelectableText>(body).data, repository.customBody);
    expect(tester.getSize(body).height, greaterThan(height));
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(tester.getSize(body).height, closeTo(height, .1));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['ar', 'en']) {
    testWidgets(
      'category tabs filter inline, select blue and return All $language',
      (tester) async {
        repository.topicData = _categories();
        final capture = GlobalKey();
        final router = await _mount(
          tester,
          repository,
          language: language,
          captureKey: capture,
        );
        await tester.pumpAndSettle();
        final nutrition = find.byKey(const Key('community-category-nutrition'));
        await tester.tap(nutrition);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/community');
        expect(find.text('nutrition category post'), findsOneWidget);
        expect(find.text('explore server item 0'), findsNothing);
        final label = find.descendant(
          of: nutrition,
          matching: find.byType(Text),
        );
        expect(
          tester.widget<Text>(label).style!.color,
          Theme.of(tester.element(label)).colorScheme.primary,
        );
        expect(repository.categoryRequests, ['nutrition']);
        await _capture(tester, capture, 'category_selected_$language');
        await tester.tap(find.byKey(const Key('community-category-all')));
        await tester.pumpAndSettle();
        expect(find.text('nutrition category post'), findsNothing);
        expect(find.text('explore server item 0'), findsOneWidget);
        expect(repository.categoryRequests, ['nutrition']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late category response cannot replace another category or All', (
    tester,
  ) async {
    repository.topicData = _categories();
    final delayed = Completer<CommunityTopicPostBatch>();
    repository.categoryRead = (slug, before, beforeId) async {
      if (slug == 'nutrition') return delayed.future;
      return CommunityTopicPostBatch(
        posts: [_categoryPost('fitness')],
        hasMore: false,
      );
    };
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-category-nutrition')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('community-category-fitness')));
    await tester.pumpAndSettle();
    expect(find.text('fitness response'), findsOneWidget);
    delayed.complete(
      CommunityTopicPostBatch(
        posts: [_categoryPost('nutrition')],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nutrition response'), findsNothing);
    expect(find.text('fitness response'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-category-all')));
    await tester.pumpAndSettle();
    expect(find.text('fitness response'), findsNothing);
    expect(find.text('explore server item 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category pagination uses its own cursor and deduplicates posts',
    (tester) async {
      repository.topicData = _categories();
      var reads = 0;
      final cursor = DateTime.utc(2026, 10, 18);
      final first = _categoryPost('first');
      final older = _categoryPost(
        'older',
        id: '99999999-9999-4999-8999-999999999999',
      );
      repository.categoryRead = (slug, before, beforeId) async {
        expect(slug, 'nutrition');
        reads++;
        if (reads == 1) {
          expect(before, isNull);
          expect(beforeId, isNull);
          return CommunityTopicPostBatch(
            posts: [first],
            hasMore: true,
            nextBefore: cursor,
            nextBeforeId: first.id,
          );
        }
        expect(before, cursor);
        expect(beforeId, first.id);
        return CommunityTopicPostBatch(posts: [first, older], hasMore: false);
      };
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pumpAndSettle();
      expect(reads, 1);
      final more = find.byKey(const Key('community-category-load-more'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('first response'), findsOneWidget);
      expect(find.text('older response'), findsOneWidget);
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed category retries without a separate page or wrong posts',
    (tester) async {
      repository.topicData = _categories();
      var reads = 0;
      repository.categoryRead = (slug, before, beforeId) async {
        if (++reads == 1) throw StateError('Synthetic category read failure');
        return CommunityTopicPostBatch(
          posts: [_categoryPost('retry')],
          hasMore: false,
        );
      };
      final router = await _mount(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pumpAndSettle();
      expect(find.text('explore server item 0'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('retry response'), findsOneWidget);
      expect(reads, 2);
      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('return All cancels a pending category result', (tester) async {
    repository.topicData = _categories();
    final pending = Completer<CommunityTopicPostBatch>();
    repository.categoryRead = (slug, before, beforeId) => pending.future;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-category-nutrition')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('community-category-all')));
    await tester.pumpAndSettle();
    pending.complete(
      CommunityTopicPostBatch(
        posts: [_categoryPost('retired')],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('retired response'), findsNothing);
    expect(find.text('explore server item 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pull refresh reloads selected category and keeps the active tab',
    (tester) async {
      repository.topicData = _categories();
      var reads = 0;
      repository.categoryRead = (slug, before, beforeId) async {
        expect(slug, 'nutrition');
        expect(before, isNull);
        expect(beforeId, isNull);
        return CommunityTopicPostBatch(
          posts: [_categoryPost('refresh ${++reads}')],
          hasMore: false,
        );
      };
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      final tab = find.byKey(const Key('community-category-nutrition'));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('refresh 1 response'), findsOneWidget);
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('refresh 2 response'), findsOneWidget);
      expect(find.text('refresh 1 response'), findsNothing);
      expect(reads, 2);
      final label = find.descendant(of: tab, matching: find.byType(Text));
      expect(
        tester.widget<Text>(label).style!.color,
        Theme.of(tester.element(label)).colorScheme.primary,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category reaction invalidates All cache before returning', (
    tester,
  ) async {
    repository.topicData = _categories();
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-category-nutrition')));
    await tester.pumpAndSettle();
    final initialRequests = repository.requests.length;
    final like = find.byKey(
      const Key('community-post-like-77777777-7777-4777-8777-777777777777'),
    );
    await tester.ensureVisible(like);
    await tester.pumpAndSettle();
    await tester.tap(like);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-category-all')));
    await tester.pumpAndSettle();
    expect(repository.requests.length, greaterThan(initialRequests));
    expect(find.text('explore server item 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  for (final nested in [false, true]) {
    testWidgets(
      'Back from inline Circles retains Community and its entry page (nested=$nested)',
      (tester) async {
        final router = await _mount(
          tester,
          repository,
          initial: '/intelligence-center',
          nestedNavigator: nested,
        );
        router.push('/community');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-hub-circles-tab')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('community-circles-list')), findsOneWidget);
        await tester.tap(find.byKey(const Key('community-safe-return')));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityHubPage), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byType(CommunityHubPage)),
          ).uri.path,
          '/community',
        );
        expect(
          find.byKey(const Key('community-hub-explore-tab')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('community-safe-return')));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/intelligence-center',
        );
      },
    );
  }

  testWidgets(
    'cached post and author bubble refresh identity even when full feed refresh fails',
    (tester) async {
      const author = '22222222-2222-4222-8222-222222222222';
      final identity = Completer<List<CommunityPostAuthorIdentity>>();
      repository
        ..simulateCachedRefreshFailure = true
        ..refreshAuthorIdentity = true
        ..cachedAuthorId = author
        ..cachedAuthorName = 'Old member name'
        ..cachedAuthorHandle = 'member_old'
        ..authorIdentity = identity;
      await _mount(tester, repository);
      await tester.pump(const Duration(milliseconds: 200));
      repository.failCachedRefresh!();
      await tester.pumpAndSettle();
      expect(find.text('Old member name'), findsWidgets);
      identity.complete(const [
        CommunityPostAuthorIdentity(
          userId: author,
          displayName: 'Updated public name',
          social: CommunityPostAuthorSocial(
            userId: author,
            handle: 'updated_handle',
            relationship: CommunityRelationshipStatus.none,
            canRequest: true,
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Old member name'), findsNothing);
      expect(find.text('@member_old'), findsNothing);
      expect(find.text('Updated public name'), findsWidgets);
      expect(find.text('@updated_handle'), findsWidgets);
      expect(
        find.byKey(
          const ValueKey(
            'community-story-22222222-2222-4222-8222-222222222222',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-feed-cache-refresh-error')),
        findsOneWidget,
      );
      expect(find.text('explore server item 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed cache refresh retry keeps the first post at the same position',
    (tester) async {
      repository.simulateCachedRefreshFailure = true;
      await _mount(tester, repository);
      await tester.pump(const Duration(milliseconds: 200));
      repository.failCachedRefresh!();
      await tester.pumpAndSettle();
      final notice = find.byKey(
        const Key('community-feed-cache-refresh-error'),
      );
      expect(notice, findsOneWidget);
      final firstPost = find.text('explore server item 0');
      expect(firstPost, findsOneWidget);
      final position = tester.getTopLeft(firstPost);
      await tester.tap(
        find.descendant(of: notice, matching: find.byType(IconButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(firstPost), position);
      repository.failCachedRefresh!();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(firstPost), position);
      expect(notice, findsOneWidget);
    },
  );

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
            repository.topicData = [
              for (final slug in [
                'nutrition',
                'fitness',
                'motivation-support',
                'wellness',
              ])
                CommunityTopic(
                  slug: slug,
                  titleCopyKey: 'topic_title',
                  descriptionCopyKey: 'topic_description',
                  iconKey: 'group',
                  featured: false,
                  followerCount: 0,
                  postCount: 0,
                  following: false,
                ),
            ];
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
              expect(find.byKey(Key('community-compose-$id')), findsNothing);
            }
            final filters = find.byKey(
              const Key('community-reference-topic-chips'),
            );
            final composer = find.byKey(const Key('community-create-post'));
            final row = tester.widget<Row>(
              find.descendant(of: filters, matching: find.byType(Row)).first,
            );
            expect(row.children.length, 9);
            expect(
              tester.widget<SingleChildScrollView>(filters).scrollDirection,
              Axis.horizontal,
            );
            expect(
              find.descendant(of: filters, matching: find.byType(Material)),
              findsNothing,
            );
            final all = find.byKey(const Key('community-category-all'));
            final allText = find.descendant(
              of: all,
              matching: find.byType(Text),
            );
            final selectedStyle = tester.widget<Text>(allText).style!;
            final primary = Theme.of(
              tester.element(allText),
            ).colorScheme.primary;
            expect(selectedStyle.color, primary);
            expect(tester.widget<Text>(allText).softWrap, isFalse);
            expect(
              tester.getSize(allText).height + 20,
              lessThanOrEqualTo(tester.getSize(filters).height + .1),
            );
            final nutrition = find.byKey(
              const Key('community-category-nutrition'),
            );
            final nutritionText = find.descendant(
              of: nutrition,
              matching: find.byType(Text),
            );
            expect(
              tester.widget<Text>(nutritionText).style!.color,
              Theme.of(
                tester.element(nutritionText),
              ).colorScheme.onSurfaceVariant,
            );
            expect(
              tester.getTopLeft(filters).dy - tester.getBottomLeft(composer).dy,
              lessThan(12),
            );
            expect(tester.getSize(filters).height, greaterThanOrEqualTo(52));
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
