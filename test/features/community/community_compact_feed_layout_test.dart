import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_translation_service.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _postId = '22222222-2222-4222-8222-222222222222';
const _photos = [
  'assets/images/nutrition_plans/balanced_market_lifestyle_v1.webp',
  'assets/images/nutrition_plans/mediterranean_coast_lifestyle_v1.webp',
  'assets/images/nutrition_plans/plant_forward_lifestyle_v1.webp',
  'assets/images/nutrition_plans/strength_lifestyle_v1.webp',
];

final class _Translation implements CommunityTranslationPort {
  int calls = 0;
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
    calls++;
    return CommunityTranslationResult({
      for (final entry in texts.entries)
        entry.key: 'Translated: ${entry.value}',
    }, 'apple');
  }
}

final class _Repository extends CommunityRepository {
  _Repository(super.client, {this.arabic = false});
  final bool arabic;
  int topicReads = 0;
  final votes = <(String, List<String>)>[];
  Completer<CommunityTopicPostBatch>? pendingTopic;
  @override
  String get currentUserId => _owner;
  @override
  bool get useServerRankedCommunityFeed => true;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => [];
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => [
    for (final slug in ['nutrition', 'fitness', 'wellness'])
      CommunityTopic(
        slug: slug,
        titleCopyKey: 'topic_title',
        descriptionCopyKey: 'topic_description',
        iconKey: slug,
        featured: true,
        followerCount: 0,
        postCount: 1,
        following: false,
      ),
  ];
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

  String get title => arabic
      ? 'أربع عادات بسيطة حسّنت صحتي'
      : '4 simple habits that improved my health';
  String get body => arabic
      ? 'التقدم الحقيقي يبدأ بعادات صغيرة تتكرر كل يوم. اخترت وجبات متنوعة ووقتًا للمشي والنوم المنتظم، وساعدني ذلك على الاستمرار. هذه تجربتي الشخصية التي أحب مشاركتها مع المجتمع.'
      : 'Real progress often comes from small habits repeated consistently. I choose varied meals, take a daily walk and make time for regular sleep. Here is the personal routine that helped me stay consistent.';
  CommunityPost get first => CommunityPost(
    id: _postId,
    authorId: _owner,
    authorName: 'Alex',
    body: body,
    createdAt: DateTime.utc(2026, 11, 21),
    locationLabel: 'Amman, Jordan',
    media: [
      for (var i = 0; i < _photos.length; i++)
        CommunityPostMedia.fromJson({
          'media_position': i,
          'object_path': 'fixture/$_postId/$i.webp',
          'mime_type': 'image/webp',
          'bytes': 1000,
          'width': 1000,
          'height': 700,
          'url': 'asset://${_photos[i]}',
        }),
    ],
    poll: CommunityPoll(
      postId: _postId,
      question: arabic
          ? 'أي عادة ستختار هذا الأسبوع؟'
          : 'Which habit will you choose this week?',
      allowMultiple: false,
      closed: false,
      totalVotes: 0,
      options: [
        CommunityPollOption(
          id: 'walk',
          position: 0,
          text: arabic ? 'مشي يومي' : 'A daily walk',
          voteCount: 0,
          selected: false,
        ),
        CommunityPollOption(
          id: 'meals',
          position: 1,
          text: arabic ? 'وجبات متنوعة' : 'Varied meals',
          voteCount: 0,
          selected: false,
        ),
      ],
    ),
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
  }) async => CommunityFeedModeBatch(
    posts: [
      first,
      for (var i = 0; i < 3; i++)
        CommunityPost(
          id: 'later-$i',
          authorId: _owner,
          authorName: 'Alex',
          body: 'Another member update $i',
          createdAt: DateTime.utc(2026, 11, 20),
        ),
    ],
    hasMore: false,
    references: const [],
  );
  @override
  Future<List<CommunityPostReferenceMetadata>>
  loadCommunityPostReferenceMetadata(List<String> ids) async => [
    if (ids.contains(_postId))
      CommunityPostReferenceMetadata(
        postId: _postId,
        title: title,
        hashtags: ['wellness', 'nutrition', 'fitness'],
        collaborators: const [],
        topics: const [
          CommunityPostTopicReference(
            slug: 'nutrition',
            titleCopyKey: 'topic_title',
            postCount: 1,
          ),
          CommunityPostTopicReference(
            slug: 'fitness',
            titleCopyKey: 'topic_title',
            postCount: 1,
          ),
          CommunityPostTopicReference(
            slug: 'wellness',
            titleCopyKey: 'topic_title',
            postCount: 1,
          ),
        ],
      ),
  ];
  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => {};
  @override
  Future<Map<String, CommunityComment>> loadCommunityFeedCommentPreviews(
    List<String> ids,
  ) async => {};
  @override
  Future<Map<String, String>> loadVisibleMembershipTiers(
    List<String> ids,
  ) async => {};
  @override
  Future<CommunityPoll> voteCommunityPoll({
    required String postId,
    required List<String> optionIds,
  }) async {
    votes.add((postId, List.of(optionIds)));
    final poll = first.poll!;
    return CommunityPoll(
      postId: poll.postId,
      question: poll.question,
      allowMultiple: false,
      closed: false,
      totalVotes: 1,
      options: [
        for (final option in poll.options)
          CommunityPollOption(
            id: option.id,
            position: option.position,
            text: option.text,
            voteCount: optionIds.contains(option.id) ? 1 : 0,
            selected: optionIds.contains(option.id),
          ),
      ],
    );
  }

  @override
  Future<CommunityTopicPostBatch> loadCommunityTopicPosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) {
    topicReads++;
    return pendingTopic?.future ??
        Future.value(CommunityTopicPostBatch(posts: [first], hasMore: false));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final dir = Platform.environment['BIL_COMMUNITY_COMPACT_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('compact-feed-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$dir/$name.png');
      if (await output.exists()) throw StateError('Use a fresh capture output');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

// Only the font files differ from a native install. Keep every production
// size, weight, spacing and color; Roboto renders Latin and the reviewed local
// Arabic face is an explicit fallback. Windows cannot prove iOS SF metrics.
ThemeData _productionEvidenceTheme(String lang) {
  final base = visualEvidenceTheme(
    BilFlagshipTheme.light(isArabic: lang == 'ar'),
    fontFamily: 'RobotoEvidence',
  );
  const fallback = ['NotoArabicEvidence'];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamilyFallback: fallback,
      ),
      toolbarTextStyle: base.appBarTheme.toolbarTextStyle?.copyWith(
        fontFamilyFallback: fallback,
      ),
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository,
  _Translation translation, {
  String lang = 'en',
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(428, 926);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityTranslationProvider.overrideWithValue(translation)],
      child: MaterialApp(
        locale: Locale(lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _productionEvidenceTheme(lang),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const Key('compact-feed-capture'),
            child: child,
          ),
        ),
        home: CommunityHubPage(
          repository: repository,
          entryWelcomeHandled: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://compact-feed.invalid',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());
  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact feed pins both tab rows and reveals metadata only on expansion $lang $scale',
        (tester) async {
          final repository = _Repository(client, arabic: lang == 'ar');
          final translation = _Translation();
          await _mount(
            tester,
            repository,
            translation,
            lang: lang,
            scale: scale,
          );
          expect(
            find.byKey(const Key('community-reference-stories')),
            findsNothing,
          );
          expect(find.text('Share an experience or win'), findsNothing);
          expect(
            find.byKey(const Key('community-create-post')),
            findsOneWidget,
          );
          final mainTab = find.byKey(const Key('community-hub-explore-tab'));
          final category = find.byKey(const Key('community-category-all'));
          final fab = find.byKey(const Key('community-create-post'));
          final mainRect = tester.getRect(mainTab),
              categoryRect = tester.getRect(category),
              fabRect = tester.getRect(fab);
          final dock = tester.getRect(
            find.byKey(const Key('bil-reference-navigation')),
          );
          expect(fabRect.right, closeTo(428 - 16, 1));
          expect(fabRect.bottom, lessThanOrEqualTo(dock.top - 15));
          final image = find.byKey(const Key('community-post-image-$_postId'));
          final title = find.byKey(const Key('community-post-reference-title'));
          final body = find.byKey(const Key('community-post-body-$_postId'));
          expect(
            tester.getBottomLeft(image).dy,
            lessThan(tester.getTopLeft(title).dy),
          );
          expect(
            tester.getBottomLeft(title).dy,
            lessThan(tester.getTopLeft(body).dy),
          );
          expect(tester.widget<Text>(body).maxLines, 2);
          expect(
            find.byKey(const Key('community-post-hashtags')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('community-translate-post-$_postId')),
            findsNothing,
          );
          expect(find.text(repository.first.poll!.question), findsOneWidget);
          expect(translation.calls, 0);
          if (scale == 1) await _capture(tester, '$lang-collapsed');
          final bodyY = tester.getTopLeft(body).dy;
          final scroll = find.byType(CustomScrollView).first;
          await tester.drag(scroll, const Offset(0, -130));
          await tester.pumpAndSettle();
          expect(tester.getRect(mainTab), mainRect);
          expect(tester.getRect(category), categoryRect);
          expect(tester.getRect(fab), fabRect);
          expect(tester.getTopLeft(body).dy, lessThan(bodyY));
          final expand = find.byKey(
            const Key('community-post-expand-$_postId'),
          );
          await tester.ensureVisible(expand);
          await tester.tap(expand);
          await tester.pumpAndSettle();
          expect(tester.widget<SelectableText>(body).data, repository.body);
          expect(
            find.byKey(const Key('community-post-hashtags')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('community-translate-post-$_postId')),
            findsOneWidget,
          );
          expect(
            translation.calls,
            0,
            reason: 'Expanding information never requests translation.',
          );
          expect(find.text(repository.first.poll!.question), findsOneWidget);
          if (scale == 1) {
            tester.widget<CustomScrollView>(scroll).controller!.jumpTo(0);
            await tester.pumpAndSettle();
            await _capture(tester, '$lang-expanded');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets('compact poll stays interactive through expansion and collapse', (
    tester,
  ) async {
    final repository = _Repository(client);
    await _mount(tester, repository, _Translation());
    final option = find.byKey(const Key('community-poll-option-walk'));
    await Scrollable.ensureVisible(tester.element(option), alignment: .5);
    await tester.pumpAndSettle();
    expect(option.hitTestable(), findsOneWidget);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(repository.votes, hasLength(1));
    expect(repository.votes.single.$1, _postId);
    expect(repository.votes.single.$2, ['walk']);
    final poll = find.byKey(const Key('community-poll-$_postId'));
    expect(find.descendant(of: poll, matching: find.text('1')), findsWidgets);
    final expand = find.byKey(const Key('community-post-expand-$_postId'));
    await Scrollable.ensureVisible(tester.element(expand), alignment: .5);
    await tester.pumpAndSettle();
    expect(expand.hitTestable(), findsOneWidget);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(expand), alignment: .5);
    await tester.pumpAndSettle();
    expect(expand.hitTestable(), findsOneWidget);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(repository.votes, hasLength(1));
    expect(find.descendant(of: poll, matching: find.text('1')), findsWidgets);
    expect(find.byKey(const Key('community-post-hashtags')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'category pull refresh preserves post and media elements with only the outer indicator',
    (tester) async {
      final repository = _Repository(client);
      final translation = _Translation();
      await _mount(tester, repository, translation);
      await tester.tap(find.byKey(const Key('community-category-nutrition')));
      await tester.pumpAndSettle();
      expect(repository.topicReads, 1);
      final body = find.byKey(const Key('community-post-body-$_postId'));
      final image = find.byKey(const Key('community-post-image-$_postId'));
      final imageElement = tester.element(image);
      final before = tester.getTopLeft(body);
      repository.pendingTopic = Completer<CommunityTopicPostBatch>();
      addTearDown(() {
        if (!repository.pendingTopic!.isCompleted)
          repository.pendingTopic!.complete(
            CommunityTopicPostBatch(posts: [repository.first], hasMore: false),
          );
      });
      final scroll = find.byType(CustomScrollView).first;
      final finger = await tester.startGesture(
        tester.getTopLeft(scroll) + const Offset(80, 100),
      );
      await finger.moveBy(const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.topicReads, 1);
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.topicReads, 2);
      expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
      expect(tester.getTopLeft(body), before);
      expect(identical(tester.element(image), imageElement), isTrue);
      expect(
        tester
            .getSize(find.byKey(const Key('community-category-refresh-slot')))
            .height,
        3,
      );
      repository.pendingTopic!.complete(
        CommunityTopicPostBatch(posts: [repository.first], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BilFeatureWelcomeStatus), findsNothing);
      expect(tester.getTopLeft(body), before);
      expect(identical(tester.element(image), imageElement), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
