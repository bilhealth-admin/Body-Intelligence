import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_review.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_comment_threads.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _capture = bool.fromEnvironment('BIL_CAPTURE_COMMUNITY_REVIEW');
const _postId = '33333333-3333-4333-8333-333333333333';
const _me = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _photoUrl = 'https://community-review.invalid/fixture-movement.png';
const _mealUrl = 'https://community-review.invalid/fixture-meal.png';
final _policy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

CommunityComment _comment(
  String id,
  int minute, {
  String? parent,
  String? body,
}) => CommunityComment(
  id: id,
  authorId: _other,
  body: body ?? 'Comment $id',
  parentId: parent,
  createdAt: DateTime.utc(2026, 9, 9, 8, minute),
  likeCount: 2,
  liked: false,
  authorName: 'BIL Training Partner',
);

class _ReviewRepository extends CommunityRepository {
  _ReviewRepository()
    : super(
        SupabaseClient(
          'https://community-review.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  List<CommunityComment> initial = [
    _comment('root', 0, body: 'A short walk is a lovely way to start the day.'),
    _comment(
      'reply',
      1,
      parent: 'root',
      body: 'خطوة صغيرة كل يوم، وأثر كبير مع الوقت.',
    ),
  ];
  List<CommunityPost>? feedRows;
  List<CommunityPost>? savedRows;
  bool withPhotos = false;
  String fixtureTag = 'en';
  int profileFailures = 0;
  final added = <CommunityComment>[];
  final cursors = <(DateTime?, String?)>[];
  final submittedIds = <String>[];
  final submittedParents = <String?>[];
  int failures = 0;
  int likes = 0;
  int friendLoads = 0;
  Completer<CommunityPostStats>? likeResult;
  Completer<List<CommunityComment>>? nextPage;
  Completer<CommunityFeedBatch>? olderFeed;
  List<CommunityComment>? refreshed;

  CommunityPost get post => CommunityPost(
    id: _postId,
    authorId: _other,
    authorName: fixtureTag == 'ar' ? 'شريك التمرين' : 'BIL Training Partner',
    body: withPhotos
        ? (fixtureTag == 'ar'
              ? 'وقت قصير للحركة، وأثر جميل لبقية اليوم. بدأت بروتين بسيط يناسبني، والأهم أن أستمر.\n#حركة_كل_يوم'
              : 'A little movement, a better day. Starting with a simple routine that works for me — consistency comes first.\n#EverydayMovement')
        : 'Small steps, real progress. A gentle walk and a home-cooked meal made today feel better.\n\nخطوة صغيرة اليوم تستحق أن نحتفل بها.',
    mediaUrl: withPhotos ? _photoUrl : null,
    mediaObjectPath: withPhotos ? 'qa/movement.png' : null,
    mediaMimeType: withPhotos ? 'image/png' : null,
    mediaBytes: withPhotos ? 1000 : null,
    mediaWidth: withPhotos ? 1200 : null,
    mediaHeight: withPhotos ? 1050 : null,
    createdAt: DateTime.utc(2026, 9, 9),
    likeCount: 12,
    commentCount: initial.length,
    authorHandle: 'training_partner',
    authorRelationship: CommunityRelationshipStatus.accepted,
  );
  CommunityPostStats get stats => CommunityPostStats(
    postId: _postId,
    likeCount: 12,
    liked: false,
    commentCount: initial.length + added.length,
  );

  @override
  String get currentUserId => _me;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfile?> loadMyProfile() async {
    if (profileFailures-- > 0) throw StateError('injected profile failure');
    return CommunityProfile(
      userId: _me,
      displayName: fixtureTag == 'ar' ? 'عضو BIL التجريبي' : 'BIL QA Member',
      localeCode: fixtureTag,
      discoverable: true,
      bio: fixtureTag == 'ar'
          ? 'أشارك خطواتي الصغيرة نحو يوم أفضل.'
          : 'Sharing small steps towards a better day.',
    );
  }

  @override
  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async => CommunityFeedBatch(
    posts: [
      CommunityPost(
        id: 'my-private-post',
        authorId: _me,
        authorName: fixtureTag == 'ar' ? 'عضو BIL التجريبي' : 'BIL QA Member',
        body: fixtureTag == 'ar'
            ? 'وجبة منزلية بسيطة بعد يوم حافل.'
            : 'A simple, home-cooked meal after a busy day.',
        createdAt: DateTime.utc(2026, 9, 9),
        mediaUrl: withPhotos ? _mealUrl : null,
        mediaObjectPath: withPhotos ? 'qa/meal.png' : null,
        mediaMimeType: withPhotos ? 'image/png' : null,
        mediaBytes: withPhotos ? 1000 : null,
        mediaWidth: withPhotos ? 1400 : null,
        mediaHeight: withPhotos ? 900 : null,
        moderationStatus: CommunityPostModerationStatus.pending,
      ),
    ],
    hasMore: false,
  );
  @override
  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async => CommunitySavedPostBatch(posts: savedRows ?? [], hasMore: false);
  @override
  Future<CommunitySavedState> setPostSaved(
    String postId, {
    required bool saved,
  }) async => CommunitySavedState(postId: postId, saved: saved);
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async =>
      CommunityPolicyState.accepted(_policy, acceptedVersion: _policy.version);
  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async =>
      feedRows ??
      [
        post,
        if (withPhotos)
          CommunityPost(
            id: 'qa-photo-post-2',
            authorId: _other,
            authorName: fixtureTag == 'ar'
                ? 'مطبخنا الصحي'
                : 'Everyday Kitchen',
            body: fixtureTag == 'ar'
                ? 'أحب الأطباق البسيطة المليئة بالألوان.'
                : 'Simple ingredients, plenty of colour.',
            createdAt: DateTime.utc(2026, 9, 8),
            mediaUrl: _mealUrl,
            mediaObjectPath: 'qa/meal.png',
            mediaMimeType: 'image/png',
            mediaBytes: 1000,
            mediaWidth: 1400,
            mediaHeight: 900,
            likeCount: 7,
            commentCount: 3,
          ),
      ];
  @override
  Future<CommunityFeedBatch> loadOlderFeed({
    required DateTime before,
    required String beforeId,
    int limit = 40,
  }) async => await olderFeed!.future;
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    friendLoads++;
    return [
      {
        'other_user_id': _other,
        'status': 'accepted',
        'profile': {'display_name': 'BIL Training Partner'},
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => [];
  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> postIds) async =>
      [stats];
  @override
  Future<CommunityPostStats> setPostLiked(
    String postId, {
    required bool liked,
  }) async {
    likes++;
    return likeResult == null ? stats : await likeResult!.future;
  }

  @override
  Future<List<CommunityComment>> loadPostComments(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async {
    cursors.add((after, afterId));
    if (after != null) return nextPage == null ? [] : await nextPage!.future;
    return refreshed ?? initial;
  }

  @override
  Future<CommunityComment> addPostComment({
    required String postId,
    required String body,
    required String clientId,
    String? parentId,
  }) async {
    submittedIds.add(clientId);
    submittedParents.add(parentId);
    if (failures > 0) {
      failures--;
      throw StateError('injected uncertain network failure');
    }
    final comment = _comment(
      clientId,
      300 + added.length,
      parent: parentId,
      body: body,
    );
    added.add(comment);
    return comment;
  }
}

Widget _app(
  _ReviewRepository repository, {
  String tag = 'en',
  double scale = 1,
  bool dark = false,
  Widget? home,
}) {
  final base = dark
      ? BilFlagshipTheme.dark(isArabic: tag == 'ar')
      : BilFlagshipTheme.light(isArabic: tag == 'ar');
  return MaterialApp(
    locale: BilLocalePolicy.localeFromTag(tag),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: _capture
        ? visualEvidenceTheme(
            base.copyWith(
              textTheme: base.textTheme.apply(
                fontFamilyFallback: const [
                  'RobotoEvidence',
                  'NotoArabicEvidence',
                ],
              ),
            ),
            fontFamily: 'RobotoEvidence',
          )
        : base,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(
        key: const Key('community-review-capture'),
        child: child!,
      ),
    ),
    home: home ?? CommunityHubPage(repository: repository),
  );
}

Future<void> _captureSurface(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('community-review-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/diagnostics/community_redesign_20260909/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// Seed the real NetworkImage cache with owned, local BIL artwork. No external
/// content or member data is fetched or inserted into the production database.
Future<void> _seedPhotos(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final entry in const {
      _photoUrl: 'assets/images/flagship/bil_movement_v1.png',
      _mealUrl: 'assets/images/flagship/bil_meal_discovery_v1.png',
    }.entries) {
      final codec = await ui.instantiateImageCodec(
        await File(entry.value).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      PaintingBinding.instance.imageCache.evict(NetworkImage(entry.key));
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(entry.key),
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: frame.image)),
        ),
      );
    }
  });
}

Future<void> _openComments(WidgetTester tester) async {
  final target = find.byKey(const Key('community-post-comments-$_postId'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _moreComments(WidgetTester tester) async {
  final target = find.byKey(const Key('community-comments-load-more'));
  await tester.scrollUntilVisible(
    target,
    450,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('community-post-detail-list')),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 80,
  );
  await tester.tap(target);
}

void main() {
  if (_capture) setUpAll(loadVisualEvidenceFont);

  test('discovery copy resolves exactly in all 25 release locales', () {
    expect(
      CommunityReviewCopy.translations.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    for (final row in CommunityReviewCopy.translations.entries) {
      expect(row.value.length, CommunityReviewCopy.keys.length);
      for (var i = 0; i < row.value.length; i++) {
        expect(row.value[i].trim(), isNotEmpty);
        expect(
          RuntimeCopy.resolve(CommunityReviewCopy.keys[i], row.key),
          row.value[i],
        );
        expect(
          communityTextForLanguage(
            row.key,
            CommunityReviewCopy.keys[i],
            row.value[i],
          ),
          row.value[i],
        );
      }
    }
  });

  test('thread display groups replies without mutating transport order', () {
    final rows = [
      _comment('a', 0),
      _comment('b', 1),
      _comment('reply-a', 2, parent: 'a'),
      _comment('reply-b', 3, parent: 'b'),
    ];
    expect(communityCommentsInThreadOrder(rows).map((c) => c.id), [
      'a',
      'reply-a',
      'b',
      'reply-b',
    ]);
    expect(rows.map((c) => c.id), ['a', 'b', 'reply-a', 'reply-b']);
    expect(communityCommentsInThreadOrder([...rows, rows.last]).length, 4);
  });

  test('community status labels resolve in every production locale', () {
    expect(
      CommunityReviewCopy.statusTranslations.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    for (final entry in CommunityReviewCopy.statusTranslations.entries) {
      expect(entry.value.length, CommunityReviewCopy.statusKeys.length);
      for (var i = 0; i < entry.value.length; i++) {
        final source = CommunityReviewCopy.statusKeys[i];
        expect(RuntimeCopy.resolve(source, entry.key), entry.value[i]);
        expect(
          communityTextForLanguage(entry.key, source, source),
          entry.value[i],
        );
        if (entry.key != 'en') expect(entry.value[i], isNot(source));
      }
    }
  });

  test('page-boundary replies remain visible and join the arriving parent', () {
    final reply = _comment('reply', 0, parent: 'root');
    expect(communityCommentsInThreadOrder([reply]).single, reply);
    expect(
      communityCommentsInThreadOrder([
        reply,
        _comment('root', 0),
      ]).map((c) => c.id),
      ['root', 'reply'],
    );
  });

  test('dashboard workout tile retains the existing verified library route', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
    ).readAsStringSync();
    expect(source, contains("'/wellness/workouts/routines'"));
    expect(source, contains("'assets/images/flagship/bil_movement_v1.png'"));
    expect(source, isNot(contains("'/community/connections'")));
    expect(
      File('assets/images/flagship/bil_movement_v1.png').existsSync(),
      isTrue,
    );
    expect(
      source.indexOf("'/wellness/workouts/routines'"),
      lessThan(source.indexOf('if (AppEnvironment.communityConfigured)')),
    );
  });

  for (final tag in BilLocalePolicy.productionTags) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('community reading, replies and friends: $tag at $scale', (
        tester,
      ) async {
        final previousShadows = debugDisableShadows;
        try {
          if (_capture) {
            debugDisableShadows = false;
            tester.view.physicalSize = const Size(391, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
          }
          await tester.binding.setSurfaceSize(const Size(391, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repository = _ReviewRepository()..fixtureTag = tag;
          if (_capture && (tag == 'ar' || tag == 'en') && scale == 1) {
            repository.withPhotos = true;
            await _seedPhotos(tester);
          }
          await tester.pumpWidget(_app(repository, tag: tag, scale: scale));
          await tester.pumpAndSettle();
          final context = tester.element(
            find.byKey(const Key('community-public-feed')),
          );
          expect(MediaQuery.textScalerOf(context).scale(10), 10 * scale);
          expect(
            Directionality.of(context),
            BilLocalePolicy.isRtlTag(tag)
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          expect(find.byKey(const Key('community-settings')), findsOneWidget);
          expect(find.byType(TabBar), findsNothing);
          expect(
            tester.widget<AppBar>(find.byType(AppBar)).actions,
            hasLength(1),
          );
          expect(tester.takeException(), isNull);
          if ((tag == 'ar' || tag == 'en') && scale == 1) {
            await _captureSurface(tester, '${tag}_feed');
          }
          await _openComments(tester);
          final reply = find.byKey(const Key('community-comment-reply-root'));
          await tester.scrollUntilVisible(
            reply,
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('community-post-detail-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          if ((tag == 'ar' || tag == 'en') && scale == 1) {
            await _captureSurface(tester, '${tag}_comments');
          }
          await tester.tap(reply);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('community-comment-composer')),
            'شكراً لك — thank you',
          );
          await tester.tap(find.byKey(const Key('community-comment-submit')));
          await tester.pumpAndSettle();
          expect(repository.submittedParents.single, 'root');
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('community-settings')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('community-my-bil-code')),
            findsOneWidget,
          );
          if ((tag == 'ar' || tag == 'en') && scale == 1) {
            await _captureSurface(tester, '${tag}_settings');
          }
          await tester.tap(find.byKey(const Key('community-nav-friends')));
          await tester.pumpAndSettle();
          expect(find.text('accepted'), findsNothing);
          expect(
            find.byKey(const Key('community-friends-manage')),
            findsOneWidget,
          );
          expect(tester.testTextInput.isVisible, isFalse);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('community-settings')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('community-nav-account')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('community-saved-posts')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('community-edit-profile')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if ((tag == 'ar' || tag == 'en') && scale == 1) {
            await _captureSurface(tester, '${tag}_member');
          }
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }

  testWidgets('new comments never advance the server pagination cursor', (
    tester,
  ) async {
    final repository = _ReviewRepository()
      ..initial = List.generate(30, (i) => _comment('server-$i', i));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _openComments(tester);
    await tester.enterText(
      find.byKey(const Key('community-comment-composer')),
      'New after page one',
    );
    await tester.tap(find.byKey(const Key('community-comment-submit')));
    await tester.pumpAndSettle();
    await _moreComments(tester);
    await tester.pumpAndSettle();
    expect(repository.cursors.last, (
      DateTime.utc(2026, 9, 9, 8, 29),
      'server-29',
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late comment pages cannot resurrect rows after refresh', (
    tester,
  ) async {
    final repository = _ReviewRepository()
      ..initial = List.generate(30, (i) => _comment('server-$i', i))
      ..nextPage = Completer<List<CommunityComment>>();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _openComments(tester);
    await _moreComments(tester);
    await tester.pump();
    repository.refreshed = [_comment('fresh', 100)];
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator).last,
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    repository.nextPage!.complete([_comment('stale', 60)]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-comment-body-stale')), findsNothing);
    expect(
      find.byKey(const Key('community-comment-body-fresh')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edited failed comments get a new id; unchanged retries keep theirs',
    (tester) async {
      final repository = _ReviewRepository()..failures = 2;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _openComments(tester);
      await tester.enterText(
        find.byKey(const Key('community-comment-composer')),
        'Original draft',
      );
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      expect(repository.submittedIds[0], repository.submittedIds[1]);
      await tester.enterText(
        find.byKey(const Key('community-comment-composer')),
        'Edited draft',
      );
      await tester.tap(find.byKey(const Key('community-comment-submit')));
      await tester.pumpAndSettle();
      expect(
        repository.submittedIds.last,
        isNot(repository.submittedIds.first),
      );
    },
  );

  testWidgets(
    'in-flight like taps are single-flight and failure retains the real count',
    (tester) async {
      final repository = _ReviewRepository()
        ..likeResult = Completer<CommunityPostStats>();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('community-post-like-$_postId'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(repository.likes, 1);
      repository.likeResult!.completeError(StateError('injected failure'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: button, matching: find.text('12')),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing a saved post cannot deliver its late reaction into the next post',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ReviewRepository()
        ..likeResult = Completer<CommunityPostStats>();
      repository.savedRows = [
        repository.post,
        CommunityPost(
          id: 'next-saved',
          authorId: _other,
          authorName: 'Next member',
          body: 'Next saved post',
          createdAt: DateTime.utc(2026, 9, 8),
          likeCount: 88,
          saved: true,
        ),
      ];
      await tester.pumpWidget(
        _app(repository, home: CommunitySavedPostsPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-post-like-$_postId')));
      // The first fixture starts unsaved. Save it, then remove it while its
      // distinct like response is still pending.
      await tester.tap(find.byKey(const Key('community-post-save-$_postId')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-post-save-$_postId')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('community-post-like-$_postId')),
        findsNothing,
      );
      repository.likeResult!.complete(
        CommunityPostStats(
          postId: _postId,
          likeCount: 23,
          liked: true,
          commentCount: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('community-post-like-next-saved')),
          matching: find.text('88'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route entry clears previous keyboard focus but rebuilds preserve typing',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextField(focusNode: focus),
                  TextButton(
                    onPressed: () => pushCommunityPage<void>(
                      context,
                      const Scaffold(body: TextField(key: Key('new-field'))),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.enterText(
        find.byKey(const Key('new-field')),
        'Keep my focus',
      );
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Keep my focus'), findsOneWidget);
    },
  );

  testWidgets(
    'share sheet is anchored, single-flight, and recovers from platform failure',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final request = Completer<String>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return request.future;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(_app(_ReviewRepository()));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('community-post-share-$_postId'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(calls.length, 1);
      final args = calls.single.arguments as Map;
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
      request.completeError(PlatformException(code: 'unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not complete that action safely. Try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an older feed response cannot overwrite a newer refresh', (
    tester,
  ) async {
    final repository = _ReviewRepository()
      ..olderFeed = Completer<CommunityFeedBatch>();
    CommunityPost post(String id) => CommunityPost(
      id: id,
      authorId: _other,
      body: 'Post $id',
      createdAt: DateTime.utc(2026, 9, 9),
    );
    repository.feedRows = List.generate(40, (i) => post('feed-$i'));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final more = find.byKey(const Key('community-feed-load-more'));
    await tester.scrollUntilVisible(
      more,
      650,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('community-feed-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 100,
    );
    await tester.tap(more);
    await tester.pump();
    repository.feedRows = [post('fresh')];
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
    repository.olderFeed!.complete(
      CommunityFeedBatch(posts: [post('stale')], hasMore: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Post stale'), findsNothing);
    expect(find.text('Post fresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one settings control opens all tools without stacking sheets', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ReviewRepository()));
    await tester.pumpAndSettle();
    final settings = tester.widget<IconButton>(
      find.byKey(const Key('community-settings')),
    );
    settings.onPressed!();
    settings.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-navigation-sheet')), findsOneWidget);
    expect(find.byKey(const Key('community-nav-friends')), findsOneWidget);
    expect(find.byKey(const Key('community-my-bil-code')), findsOneWidget);
    expect(find.byKey(const Key('community-saved-posts')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('community-navigation-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-public-feed')), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'post photos open a zoomable viewer and return to the same feed position',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(391, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _seedPhotos(tester);
      await tester.pumpWidget(_app(_ReviewRepository()..withPhotos = true));
      await tester.pumpAndSettle();
      final photo = find.byKey(const Key('community-post-image-$_postId'));
      final before = tester.getTopLeft(photo);
      await tester.tap(photo);
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const Key('community-photo-viewer')),
      );
      expect(viewer.maxScale, 4);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(photo), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark community preserves its reading and action contrast', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ReviewRepository(), dark: true));
    await tester.pumpAndSettle();
    final context = tester.element(
      find.byKey(const Key('community-create-post')),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      Theme.of(context).colorScheme.surface,
    );
    expect(tester.takeException(), isNull);
  });
}
