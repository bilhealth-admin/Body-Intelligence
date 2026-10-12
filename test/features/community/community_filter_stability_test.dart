import 'dart:async';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

final policy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

class Repository extends CommunityRepository {
  Repository(super.client);
  int policyReads = 0, profileReads = 0, topicReads = 0;
  CommunityPolicyState state = CommunityPolicyState.accepted(
    policy,
    acceptedVersion: policy.version,
  );
  final requests = <(CommunityFeedMode, Completer<CommunityFeedModeBatch>)>[];
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  bool get useServerCommunityReferenceParity => false;
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async {
    profileReads++;
    return null;
  }

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async {
    topicReads++;
    return [];
  }

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    policyReads++;
    return state;
  }

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedCachedFirst({
    required CommunityFeedMode mode,
    required String locale,
    required bool Function() current,
    required void Function(CommunityFeedModeBatch) onRefresh,
    required void Function() onRefreshing,
    required void Function(Object) onRefreshError,
    int limit = 40,
  }) {
    final c = Completer<CommunityFeedModeBatch>();
    requests.add((mode, c));
    return c.future;
  }

  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => [];
  void complete(int index, String body, {int count = 1}) {
    requests[index].$2.complete(
      CommunityFeedModeBatch(
        posts: body.isEmpty
            ? []
            : List.generate(
                count,
                (i) => CommunityPost(
                  id: 'post-$index-$i',
                  authorId: currentUserId,
                  body: '$body $i',
                  createdAt: DateTime.utc(2026),
                ),
              ),
        hasMore: false,
        references: const [],
      ),
    );
  }
}

Widget app(
  Repository repo, {
  String lang = 'en',
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool back = false,
}) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: const [
    Locale('en'),
    Locale('ar'),
    Locale('de'),
    Locale('fr'),
  ],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: visualEvidenceTheme(
    ThemeData(useMaterial3: true, brightness: brightness),
    fontFamily: lang == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(key: const Key('stability-capture'), child: child!),
  ),
  home: back
      ? Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityHubPage(repository: repo),
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        )
      : CommunityHubPage(repository: repo),
);
void main() {
  setUpAll(loadVisualEvidenceFont);
  late SupabaseClient client;
  late Repository repo;
  setUp(() {
    client = SupabaseClient(
      'https://test.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repo = Repository(client);
  });
  tearDown(() async {
    for (final r in repo.requests) {
      if (!r.$2.isCompleted) {
        r.$2.complete(
          const CommunityFeedModeBatch(
            posts: [],
            hasMore: false,
            references: [],
          ),
        );
      }
    }
    await client.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    String lang = 'en',
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool back = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      app(repo, lang: lang, scale: scale, brightness: brightness, back: back),
    );
    if (back) {
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'accepted policy/header stay mounted; filters never borrow old posts/errors; inverse responses',
    (tester) async {
      await mount(tester);
      repo.complete(0, 'EXPLORE fixture');
      await tester.pump();
      await tester.pump();
      final header = find.byKey(const Key('community-create-post'));
      final y = tester.getTopLeft(header).dy;
      expect(
        find.byKey(const Key('community-policy-notice-loading')),
        findsNothing,
      );
      await captureClosureFrames(
        tester,
        find.byKey(const Key('stability-capture')),
        'community-switch-after',
        step: 'explore',
        frames: 2,
      );
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      expect(find.text('EXPLORE fixture 0'), findsNothing);
      expect(
        find.byKey(const Key('community-policy-notice-loading')),
        findsNothing,
      );
      expect(tester.getTopLeft(header).dy, y);
      await captureClosureSurface(
        tester,
        find.byKey(const Key('stability-capture')),
        'community-after-first-pending-frame',
      );
      expect(
        find.text('Follow members to see their approved posts here.'),
        findsNothing,
      );
      await captureClosureFrames(
        tester,
        find.byKey(const Key('stability-capture')),
        'community-switch-after',
        step: 'following-pending',
        frames: 3,
      );
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      repo.complete(2, 'CURRENT fixture');
      await tester.pump();
      await tester.pump();
      repo.complete(1, 'LATE following');
      await tester.pump();
      await tester.pump();
      expect(find.text('CURRENT fixture 0'), findsOneWidget);
      expect(find.text('LATE following 0'), findsNothing);
      expect(repo.policyReads, 1);
      expect(repo.profileReads, 1);
      expect(repo.topicReads, 1);
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      repo.requests[3].$2.completeError(StateError('synthetic filter failure'));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('community-policy-notice-loading')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      expect(find.textContaining('synthetic'), findsNothing);
      expect(tester.getTopLeft(header).dy, y);
      repo.complete(4, '');
      await tester.pump();
      await tester.pump();
      for (final r in repo.requests) {
        if (!r.$2.isCompleted) {
          r.$2.complete(
            const CommunityFeedModeBatch(
              posts: [],
              hasMore: false,
              references: [],
            ),
          );
        }
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Circles return reuses visit reads; explicit publishing rechecks changed policy',
    (tester) async {
      await mount(tester);
      repo.complete(0, '');
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-circles-tab')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      expect(
        find.byKey(const Key('community-policy-notice-loading')),
        findsNothing,
      );
      expect(repo.policyReads, 1);
      expect(repo.profileReads, 1);
      expect(repo.topicReads, 1);
      repo.state = const CommunityPolicyState.unavailable();
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();
      expect(repo.policyReads, greaterThan(1));
      expect(find.byKey(const Key('community-post-editor-page')), findsNothing);
      for (final r in repo.requests) {
        if (!r.$2.isCompleted) {
          r.$2.complete(
            const CommunityFeedModeBatch(
              posts: [],
              hasMore: false,
              references: [],
            ),
          );
        }
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'per-filter scroll survives held responses, rapid toggles, and Circles without retaining four feeds',
    (tester) async {
      await mount(tester);
      repo.complete(0, 'EXPLORE', count: 20);
      await tester.pump();
      await tester.pump();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position().jumpTo(700);
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      expect(find.text('EXPLORE 0'), findsNothing);
      repo.complete(1, 'FOLLOWING', count: 20);
      await tester.pump();
      await tester.pump();
      position().jumpTo(400);
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      repo.complete(2, 'EXPLORE', count: 20);
      await tester.pump();
      await tester.pump();
      expect(position().pixels, 700);
      await tester.tap(find.byKey(const Key('community-hub-following-tab')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      repo.complete(3, 'LATE', count: 20);
      await tester.pump();
      repo.complete(4, 'EXPLORE', count: 20);
      await tester.pump();
      await tester.pump();
      expect(position().pixels, 700);
      await tester.tap(find.byKey(const Key('community-hub-circles-tab')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-hub-explore-tab')));
      await tester.pump();
      repo.complete(5, 'EXPLORE', count: 20);
      await tester.pump();
      await tester.pump();
      expect(position().pixels, 700);
      expect(repo.profileReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'For You and Friends use real actions menu without rereading shared profile',
    (tester) async {
      await mount(tester);
      repo.complete(0, '');
      await tester.pump();
      await tester.pump();
      for (final mode in ['for_you', 'friends']) {
        await tester.tap(find.byKey(const Key('community-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-feed-mode-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('community-feed-mode-$mode')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(repo.requests.last.$1.wireValue, mode);
        expect(repo.profileReads, 1);
        expect(
          find.byKey(const Key('community-policy-notice-loading')),
          findsNothing,
        );
        repo.complete(repo.requests.length - 1, '');
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  for (final lang in ['ar', 'en', 'de', 'fr']) {
    for (final width in [320.0, 360.0, 390.0, 430.0, 834.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final back in [false, true]) {
          testWidgets('complete title $lang $width $scale back=$back', (
            tester,
          ) async {
            await mount(
              tester,
              width: width,
              lang: lang,
              scale: scale,
              back: back,
              brightness: back ? Brightness.dark : Brightness.light,
            );
            final text = find.byKey(const Key('community-full-title'));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final widget = tester.widget<Text>(text);
            expect(widget.overflow, isNot(TextOverflow.ellipsis));
            expect(paragraph.didExceedMaxLines, isFalse);
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            for (final name in [
              'community-search',
              'community-updates',
              'community-settings',
            ]) {
              final button = find.byKey(Key(name));
              final br = tester.getRect(button);
              expect(br.overlaps(rect), isFalse);
              expect(br.width + 1e-9, greaterThanOrEqualTo(48));
              expect(br.height + 1e-9, greaterThanOrEqualTo(48));
              expect(find.byKey(Key(name)).hitTestable(), findsOneWidget);
            }
            if (lang == 'ar' && width == 320 && scale == 2) {
              await captureClosureSurface(
                tester,
                find.byKey(const Key('stability-capture')),
                'community-title-ar-320-2x-back-$back',
              );
            }
            for (final r in repo.requests) {
              if (!r.$2.isCompleted) {
                r.$2.complete(
                  const CommunityFeedModeBatch(
                    posts: [],
                    hasMore: false,
                    references: [],
                  ),
                );
              }
            }
            await tester.pump();
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
