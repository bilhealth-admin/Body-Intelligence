import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _postId = '33333333-3333-4333-8333-333333333333';
const _viewerId = '11111111-1111-4111-8111-111111111111';

// The circle entry surface is owner-scoped even for read-only browsing.
// Authenticate solely against the local fake transport, and simulate the
// optional legacy-server metadata endpoint being absent without fabricating
// privileged membership or post-view records.
Future<http.Response> _legacyCircleFixture(http.Request request) async {
  if (request.url.path == '/auth/v1/token') {
    final tokenPayload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': _viewerId, 'exp': 4102444800})))
        .replaceAll('=', '');
    return http.Response(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$tokenPayload.fixture',
        'refresh_token': 'offline-fixture-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': _viewerId,
          'email': 'read-only-fixture@example.invalid',
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
  if (request.url.path == '/rest/v1/rpc/bil_circle_read_v1') {
    return http.Response(
      jsonEncode({
        'code': 'PGRST202',
        'details': null,
        'hint': null,
        'message': 'Could not find function public.bil_circle_read_v1()',
      }),
      404,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
  throw StateError('Unexpected read-only fixture call: ${request.url.path}');
}

class _BrowseRepository extends CommunityRepository {
  _BrowseRepository(super.client);

  @override
  String get currentUserId => _viewerId;
  final requests = <({DateTime? before, String? id})>[];
  Completer<void>? more;
  bool failMore = true;
  int firstLoads = 0;
  int viewBatches = 0;
  bool failCounts = false;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async {
    viewBatches++;
    expect(postIds, [_postId]);
    if (failCounts) throw StateError('synthetic metric failure');
    return {_postId: 37};
  }

  final _time = DateTime.utc(2026, 10, 4);
  List<CommunityPost> get posts => [
    CommunityPost(
      id: _postId,
      authorId: '22222222-2222-4222-8222-222222222222',
      authorName: 'Peer',
      body: 'Authoritative first page',
      createdAt: _time,
      moderationStatus: CommunityPostModerationStatus.approved,
    ),
  ];
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [
    CommunityTopic(
      slug: 'success-stories',
      titleCopyKey: 'community_topic_success_stories',
      descriptionCopyKey: 'community_topic_success_stories_desc',
      iconKey: 'trophy',
      featured: false,
      followerCount: 2,
      postCount: 2,
      following: false,
    ),
  ];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [
    CommunityCircle(
      slug: 'healthy-eating',
      titleCopyKey: 'community_circle_healthy_eating',
      descriptionCopyKey: 'community_circle_healthy_eating_desc',
      rulesCopyKey: 'community_circle_healthy_eating_rules',
      access: CommunityCircleAccess.public,
      joinPolicy: CommunityCircleJoinPolicy.open,
      featured: false,
      memberCount: 2,
      postCount: 2,
    ),
  ];
  Future<void> _load(DateTime? before, String? id) async {
    requests.add((before: before, id: id));
    if (before == null) {
      firstLoads++;
      return;
    }
    if (more != null) await more!.future;
    if (failMore) throw StateError('synthetic transport details');
  }

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    await _load(before, beforeId);
    return CommunityTopicPostBatch(
      posts: before == null ? posts : [],
      hasMore: before == null,
      nextBefore: _time,
      nextBeforeId: _postId,
    );
  }

  @override
  Future<CommunityCirclePostBatch> loadCommunityCirclePosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    await _load(before, beforeId);
    return CommunityCirclePostBatch(
      posts: before == null ? posts : [],
      hasMore: before == null,
      nextBefore: _time,
      nextBeforeId: _postId,
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _BrowseRepository repository,
  String language,
  bool circle, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: circle
          ? CommunityCirclesPage(repository: repository)
          : CommunityTopicsPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    circle
        ? find.byKey(const Key('community-circle-row-healthy-eating'))
        : find.byType(InkWell).first,
  );
  await tester.pumpAndSettle();
  expect(repository.firstLoads, 1);
}

Future<void> _more(WidgetTester tester, String language) async {
  final more = find.widgetWithText(
    TextButton,
    language == 'ar' ? 'تحميل المزيد' : 'Load more',
  );
  await tester.scrollUntilVisible(
    more,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(more);
  await tester.pump();
}

void main() {
  late SupabaseClient client;
  setUp(() async {
    client = SupabaseClient(
      'https://browse.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_legacyCircleFixture)),
    );
    await client.auth.signInWithPassword(
      email: 'read-only-fixture@example.invalid',
      password: 'synthetic',
    );
  });
  tearDown(() async => client.dispose());

  for (final language in ['en', 'ar']) {
    for (final circle in [false, true]) {
      testWidgets(
        'older ${circle ? 'circle' : 'topic'} posts retry safely in $language',
        (tester) async {
          final repository = _BrowseRepository(client);
          await _open(tester, repository, language, circle);
          await _more(tester, language);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.textContaining('synthetic transport'), findsNothing);
          final cursor = repository.requests.last;
          expect(cursor.id, _postId);
          repository.failMore = false;
          await _more(tester, language);
          await tester.pumpAndSettle();
          expect(repository.requests.last, cursor);
          expect(repository.viewBatches, 1);
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    const Key('community-profile-post-views-$_postId'),
                  ),
                )
                .data,
            '37',
          );
          expect(find.text('Authoritative first page'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'unknown ${circle ? 'circle' : 'topic'} views are not fabricated in $language',
        (tester) async {
          final repository = _BrowseRepository(client)..failCounts = true;
          await _open(tester, repository, language, circle);
          expect(
            find.byKey(const Key('community-profile-post-views-$_postId')),
            findsNothing,
          );
          expect(find.text('Authoritative first page'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${circle ? 'circle' : 'topic'} posts fit 320x568 at 200% in $language',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await _open(
            tester,
            _BrowseRepository(client),
            language,
            circle,
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          final more = find.widgetWithText(
            TextButton,
            language == 'ar' ? 'تحميل المزيد' : 'Load more',
          );
          await tester.scrollUntilVisible(
            more,
            150,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'late ${circle ? 'circle' : 'topic'} failure after route exit is contained in $language',
        (tester) async {
          final repository = _BrowseRepository(client);
          await _open(tester, repository, language, circle);
          final pending = Completer<void>();
          repository.more = pending;
          await _more(tester, language);
          // Do not settle while the intentionally pending spinner is active.
          final context = tester.element(find.byType(Scaffold).last);
          Navigator.of(context).pop();
          await tester.pumpAndSettle();
          pending.complete();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SnackBar), findsNothing);
        },
      );
    }
  }
}
