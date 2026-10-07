import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_post_context.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';
import 'community_entry_flow_test.dart'
    show EntryRepositoryFixture, ownerA, ownerB, profile;

class _EarnRepository extends EntryRepositoryFixture {
  _EarnRepository(super.client);
  String action = 'create_post';
  int claims = 0;
  final saves = <({String owner, CommunityDraftSaveInput input})>[];
  final publications = <({String owner, String body, String? title})>[];
  bool failSave = false;
  bool failPublish = false;
  Completer<String>? pendingSave;

  @override
  String get currentUserId => communitySocialClient.auth.currentUser!.id;
  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      const CommunityGoldBalance(balance: 50);
  @override
  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async => [];
  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [
    CommunityQuest(
      questKey: 'fixture_post',
      cadence: CommunityQuestCadence.daily,
      titleCopyKey: 'quest_valuable_post_title',
      subtitleCopyKey: 'quest_valuable_post_subtitle',
      actionKind: action,
      targetCount: 1,
      claimMode: CommunityQuestClaimMode.auto,
      goldReward: 0,
      xpReward: 0,
      periodKey: 'fixture',
      progress: 0,
      state: CommunityQuestState.go,
    ),
  ];
  @override
  Future<CommunityQuestClaimResult> claimCommunityQuest({
    required String questKey,
    required String periodKey,
  }) async {
    claims++;
    throw StateError('Opening an editor must not claim rewards');
  }

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => [];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => [];
  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async => [];
  @override
  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    saves.add((owner: currentUserId, input: input));
    if (failSave) throw StateError('Synthetic save failure');
    if (pendingSave != null) return pendingSave!.future;
    return input.draftId;
  }

  @override
  Future<void> publishRichPost(
    String body, {
    List<CommunityPostImageDraft> images = const [],
    List<String> topicSlugs = const [],
    String? circleSlug,
    CommunityPollDraft? poll,
    String? locationLabel,
    List<CommunityMentionCandidate> mentions = const [],
    String? title,
    List<String> hashtags = const [],
    List<CommunityMentionCandidate> collaborators = const [],
    String? persistentDraftId,
  }) async {
    publications.add((owner: currentUserId, body: body, title: title));
    if (failPublish) throw StateError('Synthetic publish failure');
  }
}

class _NoImages implements CommunityPostImagePickerContract {
  @override
  Future<CommunityPostImageDraft?> pick() async => null;
}

final _body = find.byKey(const Key('community-post-composer'));
final _save = find.byKey(const Key('community-post-save-draft'));
final _publish = find.byKey(const Key('community-post-publish'));
final _editor = find.byKey(const Key('community-post-editor-page'));
final _earnCreate = find.byKey(const Key('community-earn-create-post'));

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['BIL_EARN_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  late SupabaseClient client;
  late _EarnRepository repo;
  final sessions = <String, String>{};
  String nextOwner = ownerA;
  Future<void> signIn(String owner) async {
    nextOwner = owner;
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'synthetic',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  setUpAll(() async {
    if (Platform.environment['BIL_EARN_CAPTURE_DIR'] != null) {
      await loadVisualEvidenceFont();
    }
  });
  setUp(() async {
    client = SupabaseClient(
      'https://earn-fixture.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('{}', 200);
        }
        if (request.url.path != '/auth/v1/token') {
          throw StateError('Unexpected network call ${request.url.path}');
        }
        final payload = base64Url
            .encode(
              utf8.encode(jsonEncode({'sub': nextOwner, 'exp': 4102444800})),
            )
            .replaceAll('=', '');
        return http.Response(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
            'refresh_token': 'synthetic',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': nextOwner,
              'email': 'fixture@example.invalid',
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
      }),
    );
    await signIn(ownerB);
    await signIn(ownerA);
    repo = _EarnRepository(client)..profiles[ownerA] = profile(ownerA);
  });
  tearDown(() => client.dispose());

  Future<({GoRouter router, GlobalKey boundary})> mount(
    WidgetTester tester, {
    String locale = 'en',
    bool dark = false,
    double scale = 1,
    bool gate = true,
    String initial = '/community/rewards',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/community/rewards',
          builder: (_, _) =>
              CommunitySurface(child: CommunityRewardsPage(repository: repo)),
        ),
        GoRoute(
          path: '/community/compose',
          builder: (_, state) {
            final page = CommunitySurface(
              child: CommunityComposePage(
                repository: repo,
                imagePicker: _NoImages(),
                fromEarn: state.uri.queryParameters['origin'] == 'earn',
              ),
            );
            return gate
                ? CommunityEntryGate(
                    repository: repo,
                    syncPhoto: () async => false,
                    child: page,
                  )
                : page;
          },
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);
    var theme = dark
        ? BilFlagshipTheme.dark(isArabic: locale == 'ar')
        : BilFlagshipTheme.light(isArabic: locale == 'ar');
    if (Platform.environment['BIL_EARN_CAPTURE_DIR'] != null) {
      theme = visualEvidenceTheme(
        theme,
        fontFamily: locale == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: theme,
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => RepaintBoundary(
            key: boundary,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, boundary: boundary);
  }

  void earnTest(String label, WidgetTesterCallback body) {
    testWidgets(label, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  for (final action in ['valuable_post', 'create_post', 'community_post']) {
    earnTest('Earn $action opens the existing editor, not a reward mutation', (
      tester,
    ) async {
      repo.action = action;
      await mount(tester);
      expect(find.text('50'), findsOneWidget);
      await _tap(tester, find.text('Go'));
      expect(_editor, findsOneWidget);
      // Imperative push keeps the browser URL unchanged by default. Inspect
      // the mounted route instead, including the reward-intent query.
      expect(
        GoRouterState.of(tester.element(_editor)).uri.toString(),
        '/community/compose?origin=earn',
      );
      expect(
        find.byKey(const Key('community-ai-reward-notice')),
        findsOneWidget,
      );
      expect(repo.codeReads, 1);
      expect(repo.writes, isEmpty);
      expect(repo.publications, isEmpty);
      expect(repo.saves, isEmpty);
      expect(repo.claims, 0);
      expect(tester.widget<TextField>(_body).controller!.text, isEmpty);
    });
  }

  earnTest('Earn profile and code gate cannot publish or grant on creation', (
    tester,
  ) async {
    repo.profiles.clear();
    repo.failCode = true;
    await mount(tester);
    await _tap(tester, _earnCreate);
    expect(_editor, findsNothing);
    final name = find.byKey(const Key('community-entry-name'));
    await tester.enterText(name, 'New member');
    await _tap(tester, find.byKey(const Key('community-entry-save')));
    expect(_editor, findsNothing);
    expect(repo.writes, hasLength(1));
    expect(repo.publications, isEmpty);
    repo.failCode = false;
    await _tap(tester, find.byKey(const Key('community-entry-save')));
    expect(_editor, findsOneWidget);
    expect(repo.writes, hasLength(1));
    expect(repo.publications, isEmpty);
    expect(repo.claims, 0);
  });

  earnTest('Earn save failure keeps input; retry saves a draft, not a post', (
    tester,
  ) async {
    await mount(tester);
    await _tap(tester, _earnCreate);
    await tester.enterText(_body, 'Private text retained through failure');
    repo.failSave = true;
    await _tap(tester, _save);
    expect(repo.saves, hasLength(1));
    expect(
      tester.widget<TextField>(_body).controller!.text,
      'Private text retained through failure',
    );
    repo.failSave = false;
    await _tap(tester, _save);
    expect(repo.saves, hasLength(2));
    expect(repo.saves.last.input.draftId, repo.saves.first.input.draftId);
    expect(repo.saves.last.input.body, 'Private text retained through failure');
    expect(repo.publications, isEmpty);
    expect(repo.claims, 0);
    expect(_editor, findsOneWidget);
  });

  earnTest('Earn Publish stays explicit and retains content through retry', (
    tester,
  ) async {
    final value = await mount(tester);
    await _tap(tester, _earnCreate);
    final title = find.byKey(const Key('community-composer-title'));
    await tester.enterText(title, 'Reviewed by the author');
    await tester.enterText(_body, 'My original Community post');
    expect(repo.publications, isEmpty);
    repo.failPublish = true;
    await _tap(tester, _publish);
    expect(repo.publications, hasLength(1));
    expect(
      tester.widget<TextField>(_body).controller!.text,
      'My original Community post',
    );
    repo.failPublish = false;
    await _tap(tester, _publish);
    expect(repo.publications, hasLength(2));
    expect(repo.publications.first, repo.publications.last);
    expect(
      value.router.routeInformationProvider.value.uri.path,
      '/community/rewards',
    );
    expect(repo.claims, 0);
    expect(find.text('50'), findsOneWidget);
  });

  earnTest('Earn opening is single-flight and back performs no write', (
    tester,
  ) async {
    final value = await mount(tester);
    await tester.ensureVisible(_earnCreate);
    await tester.pumpAndSettle();
    await tester.tap(_earnCreate);
    await tester.tap(_earnCreate);
    await tester.pumpAndSettle();
    expect(_editor, findsOneWidget);
    await _tap(tester, find.byKey(const Key('community-post-editor-close')));
    expect(
      value.router.routeInformationProvider.value.uri.path,
      '/community/rewards',
    );
    expect(repo.writes, isEmpty);
    expect(repo.saves, isEmpty);
    expect(repo.publications, isEmpty);
    expect(repo.claims, 0);
  });

  earnTest('direct Earn editor cancels a pending old-owner save after A-B-A', (
    tester,
  ) async {
    await mount(tester, gate: false, initial: '/community/compose?origin=earn');
    await tester.enterText(_body, 'Only account A owns this text');
    final pending = Completer<String>();
    repo.pendingSave = pending;
    await tester.tap(_save);
    await tester.pump();
    expect(repo.saves, hasLength(1));
    final second = client.auth.recoverSession(sessions[ownerB]!);
    final first = client.auth.recoverSession(sessions[ownerA]!);
    await Future.wait([second, first]);
    await tester.pump();
    pending.complete(repo.saves.single.input.draftId);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-post-owner-changed')),
      findsOneWidget,
    );
    expect(_editor, findsNothing);
    expect(repo.saves.single.owner, ownerA);
    expect(repo.publications, isEmpty);
    expect(repo.claims, 0);
  });

  earnTest('repository removal cannot revive old input on later reuse', (
    tester,
  ) async {
    _EarnRepository? selected = repo;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, change) {
            update = change;
            return CommunityComposePage(
              repository: selected,
              imagePicker: _NoImages(),
              fromEarn: true,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_body, 'Never transfer this private input');
    update(() => selected = null);
    await tester.pumpAndSettle();
    update(() => selected = repo);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-compose-entry-unavailable')),
      findsOneWidget,
    );
    expect(_editor, findsNothing);
    expect(find.text('Never transfer this private input'), findsNothing);
    expect(repo.saves, isEmpty);
    expect(repo.publications, isEmpty);
  });

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        earnTest('Earn real Flutter $language dark=$dark text=$scale', (
          tester,
        ) async {
          final value = await mount(
            tester,
            locale: language,
            dark: dark,
            scale: scale,
          );
          // At large text sizes the lazy list has not built the final CTA.
          // Scroll the actual vertical list until that child exists.
          await tester.scrollUntilVisible(
            _earnCreate,
            180,
            scrollable: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final suffix =
              '$language-${dark ? 'dark' : 'light'}-${scale.toInt()}';
          await _capture(tester, value.boundary, 'earn-$suffix');
          await _tap(tester, _earnCreate);
          expect(_editor, findsOneWidget);
          expect(
            find.byKey(const Key('community-ai-reward-notice')),
            findsOneWidget,
          );
          await _capture(tester, value.boundary, 'composer-$suffix');
          await tester.ensureVisible(_body);
          await tester.pumpAndSettle();
          await tester.enterText(
            _body,
            language == 'ar'
                ? 'مسودة خاصة لا تُنشر تلقائيًا'
                : 'A private draft, never auto-published',
          );
          await tester.ensureVisible(_save);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(repo.publications, isEmpty);
          expect(repo.claims, 0);
          expect(repo.saves, isEmpty);
        });
      }
    }
  }
}
