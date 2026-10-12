import 'dart:async';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_comment_threads.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_translation_service.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

const _postId = '11111111-1111-4111-8111-111111111111';
const _owner = '22222222-2222-4222-8222-222222222222';
const _rootId = '33333333-3333-4333-8333-333333333333';
const _replyId = '44444444-4444-4444-8444-444444444444';

class _Port implements CommunityTranslationPort {
  final requests = <Map<String, String>>[];
  final targets = <String>[];
  @override
  Future<void> cancel(String requestId) async {}
  @override
  Future<CommunityTranslationResult> translate({
    required String requestId,
    required Map<String, String> texts,
    required String targetTag,
    String? statusLabel,
    String? cancelLabel,
  }) async {
    requests.add(Map.of(texts));
    targets.add(targetTag);
    // Synthetic deterministic text proves wiring, never native engine quality.
    return CommunityTranslationResult(
      texts.map((key, value) => MapEntry(key, 'Çeviri · $value')),
      'apple',
    );
  }
}

class _Repository extends CommunityRepository {
  int metadataReads = 0;
  late Zone feedRpcZone;
  late void Function(CommunityFeedModeBatch) refresh;
  void refreshAfterRpcCompleted() => feedRpcZone.run(
    () => refresh(
      CommunityFeedModeBatch(
        posts: [post],
        hasMore: false,
        references: const [],
      ),
    ),
  );
  _Repository()
    : super(
        SupabaseClient(
          'https://translation-ui-fixture.invalid',
          'public-test-anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  String get currentUserId => _owner;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => [];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => [];
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => {_postId: 1};
  @override
  Future<Map<String, CommunityComment>> loadCommunityFeedCommentPreviews(
    List<String> ids,
  ) async => {};
  @override
  Future<int> recordCommunityPostView(String postId) async => 1;
  @override
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> ids,
  ) async => {};
  @override
  Future<Map<String, String>> loadCommentMembershipTiers(
    List<String> ids,
  ) async => {};
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  final post = CommunityPost(
    id: _postId,
    authorId: _owner,
    authorName: 'QA author',
    body: 'I walked today',
    createdAt: DateTime.utc(2026, 10, 12),
    commentCount: 2,
  );
  final root = CommunityComment(
    id: _rootId,
    authorId: _owner,
    body: 'Good progress',
    createdAt: DateTime.utc(2026, 10, 12),
    likeCount: 0,
    liked: false,
    replyCount: 1,
  );
  final reply = CommunityComment(
    id: _replyId,
    parentId: _rootId,
    authorId: _owner,
    body: 'Thank you',
    createdAt: DateTime.utc(2026, 10, 12, 1),
    likeCount: 0,
    liked: false,
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
    feedRpcZone = Zone.current;
    refresh = onRefresh;
    return CommunityFeedModeBatch(
      posts: [post],
      hasMore: false,
      references: const [],
    );
  }

  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) async {
    metadataReads++;
    return [
      const CommunityPostReferenceMetadata(
        postId: _postId,
        title: 'My progress',
        hashtags: [],
        collaborators: [],
      ),
    ];
  }

  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> ids) async => [
    CommunityPostStats(
      postId: _postId,
      likeCount: 0,
      liked: false,
      commentCount: 2,
    ),
  ];
  @override
  Future<List<CommunityCommentThread>> loadPostCommentThreads(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 20,
  }) async => [
    CommunityCommentThread(root: root, replies: [reply], replyCount: 1),
  ];
  @override
  Future<List<CommunityComment>> loadCommentReplies(
    String rootId, {
    DateTime? after,
    String? afterId,
    int limit = 20,
  }) async => [reply];
}

Future<void> _tap(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  late _Repository repository;
  setUp(() => repository = _Repository());
  tearDown(() => repository.communitySocialClient.dispose());
  testWidgets(
    'real feed, post detail, comment and reply preserve originals while translating to app language',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final port = _Port();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityTranslationProvider.overrideWithValue(port)],
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: const [Locale('tr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: visualEvidenceTheme(BilFlagshipTheme.light()),
            builder: (_, child) => RepaintBoundary(key: capture, child: child!),
            home: CommunityHubPage(repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 40 && find.text('My progress').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repository.metadataReads, greaterThan(0));
      repository.refreshAfterRpcCompleted();
      await tester.pumpAndSettle();
      expect(repository.metadataReads, 2);
      expect(find.text('My progress'), findsOneWidget);
      final feed = find.byKey(const Key('community-translate-post-$_postId'));
      expect(feed, findsOneWidget);
      expect(find.text('I walked today'), findsOneWidget);
      expect(find.text('My progress'), findsOneWidget);
      await _tap(tester, feed);
      expect(find.text('Çeviri · I walked today'), findsOneWidget);
      expect(find.text('Çeviri · My progress'), findsOneWidget);
      expect(port.targets, ['tr']);
      expect(repository.post.body, 'I walked today');
      await _tap(
        tester,
        feed,
      ); // Show the exact original without a second request.
      expect(find.text('I walked today'), findsOneWidget);
      expect(port.requests, hasLength(1));
      await _tap(
        tester,
        find.byKey(const Key('community-post-comments-$_postId')),
      );
      expect(find.text('Good progress'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const Key('community-translate-comment-$_rootId')),
      );
      expect(find.text('Çeviri · Good progress'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const Key('community-comment-view-replies-$_rootId')),
      );
      expect(find.text('Thank you'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const Key('community-translate-comment-$_replyId')),
      );
      expect(find.text('Çeviri · Thank you'), findsOneWidget);
      expect(port.targets, ['tr', 'tr', 'tr']);
      expect(repository.root.body, 'Good progress');
      expect(repository.reply.body, 'Thank you');
      await captureClosureSurface(
        tester,
        find.byKey(capture),
        'actual-translated-comment-and-reply-tr',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
