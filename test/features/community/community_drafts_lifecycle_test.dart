import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _draftA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _draftB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
typedef _LoadedDraft = ({
  CommunityPersistentDraft draft,
  List<CommunityPostImageDraft> images,
});

class _DraftAuthFixture {
  _DraftAuthFixture(this.owner);

  String owner;
  late final client = SupabaseClient(
    'https://draft-lifecycle.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      Object body;
      if (request.url.path == '/auth/v1/token') {
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
            .replaceAll('=', '');
        body = {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'email': 'draft-fixture@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-06T00:00:00Z',
          },
        };
      } else if (request.url.path == '/auth/v1/logout') {
        body = {};
      } else {
        throw StateError('Unexpected external request: ${request.url.path}');
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'draft-fixture@example.invalid',
      password: 'synthetic-password',
    );
  }
}

CommunityDraftSummary _summary(String owner) => CommunityDraftSummary(
  draftId: owner == _ownerA ? _draftA : _draftB,
  title: owner == _ownerA ? 'First private draft' : 'Second private draft',
  body: owner == _ownerA ? 'First saved body' : 'Second saved body',
  updatedAt: DateTime.utc(2026, 10, 6),
  mediaCount: 0,
);

_LoadedDraft _loaded(String owner) {
  final summary = _summary(owner);
  return (
    draft: CommunityPersistentDraft(
      draftId: summary.draftId,
      title: summary.title,
      body: summary.body,
      topicSlugs: const [],
      mentions: const [],
      collaborators: const [],
      hashtags: const [],
      pollOptions: const [],
      pollAllowMultiple: false,
      createdAt: summary.updatedAt,
      updatedAt: summary.updatedAt,
      media: const [],
    ),
    images: const [],
  );
}

class _DraftRepository extends CommunityRepository {
  _DraftRepository(super.client);

  final rows = <String, List<CommunityDraftSummary>>{
    _ownerA: [_summary(_ownerA)],
    _ownerB: [_summary(_ownerB)],
  };
  final listOwners = <String>[];
  final loadedIds = <String>[];
  final deletedIds = <String>[];
  int profileReads = 0;
  bool failList = false;
  bool failLoad = false;
  bool failDelete = false;
  Completer<List<CommunityDraftSummary>>? pendingList;
  Completer<_LoadedDraft>? pendingLoad;
  Completer<void>? pendingDelete;

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    final owner = currentUserId;
    listOwners.add(owner);
    final pending = pendingList;
    if (pending != null) return pending.future;
    if (failList) throw StateError('Synthetic list failure');
    return List.of(rows[owner] ?? []);
  }

  @override
  Future<_LoadedDraft> loadMyCommunityDraft(String draftId) async {
    final owner = currentUserId;
    loadedIds.add(draftId);
    final pending = pendingLoad;
    if (pending != null) return pending.future;
    if (failLoad) throw StateError('Synthetic load failure');
    return _loaded(owner);
  }

  @override
  Future<({CommunityPersistentDraft draft, CommunityPostImageDraft? image})>
  loadMyCommunityDraftPreview(String draftId) async =>
      (draft: _loaded(currentUserId).draft, image: null);

  @override
  Future<void> deleteMyCommunityDraft(String draftId) async {
    final owner = currentUserId;
    deletedIds.add(draftId);
    final pending = pendingDelete;
    if (pending != null) await pending.future;
    if (failDelete) throw StateError('Synthetic delete failure');
    rows[owner]?.removeWhere((draft) => draft.draftId == draftId);
  }

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    return null;
  }

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [];
}

class _DraftPageFixture {
  _DraftPageFixture(this.repository);
  _DraftRepository repository;
  late StateSetter update;

  Widget get app => MaterialApp(
    home: StatefulBuilder(
      builder: (_, setState) {
        update = setState;
        return CommunityDraftsPage(repository: repository);
      },
    ),
  );
}

void _draftTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<_DraftPageFixture> _mount(
  WidgetTester tester,
  _DraftRepository repository,
) async {
  final fixture = _DraftPageFixture(repository);
  await tester.pumpWidget(fixture.app);
  await tester.pump();
  return fixture;
}

Finder _draft(String id) => find.byKey(Key('community-draft-$id'));
Future<void> _deleteDraft(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('community-draft-actions-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('community-draft-delete-$id')));
  await tester.pumpAndSettle();
}

Finder get _editor => find.byKey(const Key('community-post-editor-page'));
String _editorBody(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('community-post-composer')))
    .controller!
    .text;

void main() {
  late _DraftAuthFixture authA;
  late _DraftAuthFixture authB;
  late _DraftRepository repository;
  late _DraftRepository secondRepository;

  // Supabase JSON worker construction and shutdown use the real runner zone.
  // Widget callbacks unmount their UI before this outer teardown closes clients.
  setUp(() async {
    authA = _DraftAuthFixture(_ownerA);
    authB = _DraftAuthFixture(_ownerB);
    await authA.signIn();
    await authB.signIn();
    repository = _DraftRepository(authA.client);
    secondRepository = _DraftRepository(authB.client);
  });
  tearDown(() async {
    await authA.client.dispose();
    await authB.client.dispose();
  });

  _draftTest(
    'cold direct Drafts returns safely while a draft load is pending',
    (tester) async {
      final pending = Completer<_LoadedDraft>();
      repository.pendingLoad = pending;
      final router = GoRouter(
        initialLocation: '/community/drafts',
        routes: [
          GoRoute(
            path: '/community/drafts',
            builder: (_, _) => CommunityDraftsPage(repository: repository),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Safe dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.canPop(), false);
      await tester.tap(_draft(_draftA));
      await tester.pump();
      await tester.tap(find.byKey(const Key('community-safe-return')));
      await tester.pumpAndSettle();
      expect(find.text('Safe dashboard'), findsOneWidget);
      expect(find.byKey(const Key('community-drafts-page')), findsNothing);

      pending.complete(_loaded(_ownerA));
      await tester.pumpAndSettle();
      expect(find.text('Safe dashboard'), findsOneWidget);
      expect(_editor, findsNothing);
      expect(repository.loadedIds, [_draftA]);
      expect(tester.takeException(), isNull);
    },
  );

  _draftTest('failed private list retries without a profile prerequisite', (
    tester,
  ) async {
    repository.failList = true;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(_draft(_draftA), findsNothing);

    repository.failList = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_draft(_draftA), findsOneWidget);
    expect(repository.listOwners, [_ownerA, _ownerA]);
    expect(repository.profileReads, 0);
    expect(tester.takeException(), isNull);
  });

  _draftTest('failed load keeps its row and retry opens the persisted body', (
    tester,
  ) async {
    repository.failLoad = true;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(_draft(_draftA));
    await tester.pumpAndSettle();
    expect(_editor, findsNothing);
    expect(_draft(_draftA), findsOneWidget);
    expect(find.text('Could not open this draft. Try again.'), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(_draft(_draftA));
    await tester.pumpAndSettle();
    expect(_editor, findsOneWidget);
    expect(_editorBody(tester), 'First saved body');
    expect(repository.loadedIds, [_draftA, _draftA]);
    await tester.tap(find.byKey(const Key('community-post-editor-close')));
    await tester.pumpAndSettle();
    expect(_draft(_draftA), findsOneWidget);
    expect(repository.listOwners, [_ownerA, _ownerA]);
    expect(tester.takeException(), isNull);
  });

  _draftTest(
    'failed delete retains its row; success refreshes server readback',
    (tester) async {
      repository.failDelete = true;
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      await _deleteDraft(tester, _draftA);
      expect(_draft(_draftA), findsOneWidget);
      expect(repository.listOwners, [_ownerA]);

      repository.failDelete = false;
      await _deleteDraft(tester, _draftA);
      expect(_draft(_draftA), findsNothing);
      expect(find.text('No saved drafts yet'), findsOneWidget);
      expect(repository.deletedIds, [_draftA, _draftA]);
      expect(repository.listOwners, [_ownerA, _ownerA]);
      expect(tester.takeException(), isNull);
    },
  );

  _draftTest(
    'replacing repository cancels an old open without blocking the new one',
    (tester) async {
      final oldLoad = Completer<_LoadedDraft>();
      repository.pendingLoad = oldLoad;
      final page = await _mount(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(_draft(_draftA));
      await tester.tap(_draft(_draftA));
      await tester.pump();
      expect(repository.loadedIds, [_draftA]);

      page.update(() => page.repository = secondRepository);
      await tester.pumpAndSettle();
      expect(_draft(_draftA), findsNothing);
      expect(_draft(_draftB), findsOneWidget);
      await tester.tap(_draft(_draftB));
      await tester.pumpAndSettle();
      expect(_editorBody(tester), 'Second saved body');

      oldLoad.complete(_loaded(_ownerA));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const Key('community-post-editor-page'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(_editorBody(tester), 'Second saved body');
      expect(secondRepository.loadedIds, [_draftB]);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _draftTest('real auth switch on the same repository cancels the prior open', (
    tester,
  ) async {
    final oldLoad = Completer<_LoadedDraft>();
    repository.pendingLoad = oldLoad;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(_draft(_draftA));
    await tester.pump();

    repository.pendingLoad = null;
    authA.owner = _ownerB;
    await tester.runAsync(authA.signIn);
    await tester.pumpAndSettle();
    expect(_draft(_draftA), findsNothing);
    expect(_draft(_draftB), findsOneWidget);
    expect(repository.listOwners, [_ownerA, _ownerB]);
    oldLoad.complete(_loaded(_ownerA));
    await tester.pumpAndSettle();
    expect(_editor, findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(_draft(_draftB));
    await tester.pumpAndSettle();
    expect(_editorBody(tester), 'Second saved body');
    expect(repository.loadedIds, [_draftA, _draftB]);
    expect(tester.takeException(), isNull);
  });

  _draftTest('same-account token refresh preserves the private list', (
    tester,
  ) async {
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.runAsync(() => authA.client.auth.refreshSession());
    await tester.pumpAndSettle();
    expect(repository.listOwners, [_ownerA]);
    expect(_draft(_draftA), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _draftTest(
    'returning to the first account cannot revive its cancelled open',
    (tester) async {
      final oldLoad = Completer<_LoadedDraft>();
      repository.pendingLoad = oldLoad;
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(_draft(_draftA));
      await tester.pump();

      await tester.runAsync(() async {
        authA.owner = _ownerB;
        await authA.signIn();
        authA.owner = _ownerA;
        await authA.signIn();
      });
      await tester.pumpAndSettle();
      expect(_draft(_draftA), findsOneWidget);
      oldLoad.complete(_loaded(_ownerA));
      await tester.pumpAndSettle();
      expect(_editor, findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      repository.pendingLoad = null;
      await tester.tap(_draft(_draftA));
      await tester.pumpAndSettle();
      expect(_editorBody(tester), 'First saved body');
      expect(repository.loadedIds, [_draftA, _draftA]);
      expect(tester.takeException(), isNull);
    },
  );

  _draftTest('logout clears private rows and suppresses a late load error', (
    tester,
  ) async {
    final oldLoad = Completer<_LoadedDraft>();
    repository.pendingLoad = oldLoad;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(_draft(_draftA));
    await tester.pump();
    await tester.runAsync(
      () => authA.client.auth.signOut(scope: SignOutScope.local),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to open your private drafts.'), findsOneWidget);
    expect(_draft(_draftA), findsNothing);

    oldLoad.completeError(StateError('Synthetic old-account load error'));
    await tester.pumpAndSettle();
    expect(_editor, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.listOwners, [_ownerA]);
    expect(tester.takeException(), isNull);
  });

  _draftTest('late old list cannot replace new account private rows', (
    tester,
  ) async {
    final oldList = Completer<List<CommunityDraftSummary>>();
    repository.pendingList = oldList;
    await _mount(tester, repository);
    expect(_draft(_draftA), findsNothing);
    repository.pendingList = null;
    authA.owner = _ownerB;
    await tester.runAsync(authA.signIn);
    await tester.pumpAndSettle();
    expect(_draft(_draftB), findsOneWidget);

    oldList.complete([_summary(_ownerA)]);
    await tester.pumpAndSettle();
    expect(_draft(_draftA), findsNothing);
    expect(_draft(_draftB), findsOneWidget);
    expect(repository.listOwners, [_ownerA, _ownerB]);
    expect(tester.takeException(), isNull);
  });

  _draftTest('old deletion completion cannot refresh the next account', (
    tester,
  ) async {
    final oldDelete = Completer<void>();
    repository.pendingDelete = oldDelete;
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await _deleteDraft(tester, _draftA);
    authA.owner = _ownerB;
    await tester.runAsync(authA.signIn);
    await tester.pumpAndSettle();
    expect(_draft(_draftB), findsOneWidget);

    oldDelete.complete();
    await tester.pumpAndSettle();
    expect(_draft(_draftB), findsOneWidget);
    expect(repository.deletedIds, [_draftA]);
    expect(repository.listOwners, [_ownerA, _ownerB]);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _draftTest('bulk delete confirmation cannot authorize another account', (
    tester,
  ) async {
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-drafts-select')));
    await tester.pump();
    await tester.tap(_draft(_draftA));
    await tester.pump();
    await tester.tap(find.byKey(const Key('community-drafts-delete-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 drafts?'), findsOneWidget);

    authA.owner = _ownerB;
    await tester.runAsync(authA.signIn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(_draft(_draftA), findsNothing);
    expect(_draft(_draftB), findsOneWidget);
    expect(repository.deletedIds, isEmpty);
    expect(repository.listOwners, [_ownerA, _ownerB]);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
