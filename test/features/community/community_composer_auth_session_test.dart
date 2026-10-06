import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/domain/community_post_context.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_composer_auth_session_feed.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _draftA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _draftB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _codeValue = 'aabbccddaabbccddaabbccddaabbccdd';

class _ComposerAuthFixture {
  String owner = _ownerA;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://composer-auth.invalid',
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
            'email': 'composer-fixture@example.invalid',
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

  Future<void> signIn(String nextOwner) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'composer-fixture@example.invalid',
      password: 'synthetic-password',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(sessions[_ownerB]!);
    final first = client.auth.recoverSession(sessions[_ownerA]!);
    await Future.wait([second, first]);
  }
}

CommunityProfile _profile(String owner, {String name = 'Saved member'}) =>
    CommunityProfile(
      userId: owner,
      displayName: name,
      localeCode: 'en',
      discoverable: false,
      visibility: CommunityProfileVisibility.private,
      allowFriendRequests: false,
      allowFollows: false,
      allowMessagesFrom: CommunityMessagePermission.nobody,
    );

CommunityPublicCode _code() => CommunityPublicCode(
  code: _codeValue,
  uri: Uri.parse('bil://community/member/$_codeValue'),
  handle: 'member_qa',
);

CommunityPersistentDraft _draft(String owner) => CommunityPersistentDraft(
  draftId: owner == _ownerA ? _draftA : _draftB,
  title: owner == _ownerA ? 'A private title' : 'B private title',
  body: owner == _ownerA ? 'A private saved body' : 'B private saved body',
  topicSlugs: const [],
  mentions: const [],
  collaborators: const [],
  hashtags: const [],
  pollOptions: const [],
  pollAllowMultiple: false,
  createdAt: DateTime.utc(2026, 10, 6),
  updatedAt: DateTime.utc(2026, 10, 6),
  media: const [],
);

class _ComposerRepository extends CommunityRepository {
  _ComposerRepository(super.client);

  final profiles = <String, CommunityProfile>{};
  final trace = <String>[];
  final saved = <({String owner, CommunityDraftSaveInput input})>[];
  final published = <({String owner, String body, String? draftId})>[];
  final cancelled = <String>[];
  final created = <String>[];
  final codeOwners = <String>[];
  int profileReads = 0;
  bool failCode = false;
  bool failCreate = false;
  bool failPublish = false;
  Completer<CommunityProfile?>? nextProfile;
  Completer<CommunityPublicCode>? nextCode;
  Completer<void>? nextSave;
  Completer<void>? nextPublish;
  Completer<bool>? nextCancel;

  @override
  Future<List<CommunityDraftSummary>> listMyCommunityDrafts({
    DateTime? before,
    String? beforeId,
    int limit = 20,
  }) async {
    final draft = _draft(currentUserId);
    return [
      CommunityDraftSummary(
        draftId: draft.draftId,
        title: draft.title,
        body: draft.body,
        updatedAt: draft.updatedAt,
        mediaCount: 0,
      ),
    ];
  }

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImagePreview?> images})
  >
  loadMyCommunityDraftMosaicPreview(
    String draftId, {
    int maxImages = 4,
  }) async => (
    draft: _draft(currentUserId),
    images: const <CommunityPostImagePreview?>[],
  );

  @override
  Future<
    ({CommunityPersistentDraft draft, List<CommunityPostImageDraft> images})
  >
  loadMyCommunityDraft(String draftId) async =>
      (draft: _draft(currentUserId), images: const <CommunityPostImageDraft>[]);

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [];

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileReads++;
    trace.add('profile');
    final pending = nextProfile;
    nextProfile = null;
    return pending == null ? profiles[currentUserId] : await pending.future;
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeOwners.add(currentUserId);
    trace.add('code');
    final pending = nextCode;
    nextCode = null;
    if (pending != null) return pending.future;
    if (failCode) throw StateError('Synthetic code failure');
    return _code();
  }

  @override
  Future<void> createMyCommunityEntryProfile({
    required String displayName,
    required String localeCode,
    required String expectedOwnerId,
  }) async {
    expect(currentUserId, expectedOwnerId);
    if (failCreate) throw StateError('Synthetic profile failure');
    created.add(expectedOwnerId);
    trace.add('create');
    profiles[expectedOwnerId] = _profile(expectedOwnerId, name: displayName);
  }

  @override
  Future<String> saveMyCommunityDraft({
    required CommunityDraftSaveInput input,
    required List<CommunityPostImageDraft> images,
  }) async {
    saved.add((owner: currentUserId, input: input));
    trace.add('save');
    final pending = nextSave;
    nextSave = null;
    if (pending != null) await pending.future;
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
    published.add((
      owner: currentUserId,
      body: body,
      draftId: persistentDraftId,
    ));
    trace.add('publish');
    final pending = nextPublish;
    nextPublish = null;
    if (pending != null) await pending.future;
    if (failPublish) throw StateError('Synthetic publish failure');
  }

  @override
  Future<bool> cancelPendingPublishOperation() async {
    cancelled.add(currentUserId);
    final pending = nextCancel;
    nextCancel = null;
    return pending == null ? true : await pending.future;
  }
}

Finder get _editor => find.byKey(const Key('community-post-editor-page'));
Finder get _body => find.byKey(const Key('community-post-composer'));
Finder get _publish => find.byKey(const Key('community-post-publish'));
Finder get _save => find.byKey(const Key('community-post-save-draft'));
Finder get _entryName => find.byKey(const Key('community-entry-name'));
Finder get _ownerChanged =>
    find.byKey(const Key('community-post-owner-changed'));

void _composerTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _mountDraft(
  WidgetTester tester,
  _ComposerRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/community/drafts',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
      GoRoute(
        path: '/community/drafts',
        builder: (_, _) => CommunityDraftsPage(repository: repository),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('community-draft-continue-$_draftA')));
  await tester.pumpAndSettle();
  expect(_editor, findsOneWidget);
  expect(
    tester.widget<TextField>(_body).controller!.text,
    'A private saved body',
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _roundTrip(WidgetTester tester, _ComposerAuthFixture auth) async {
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final observation = auth.client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: auth.client.auth.currentUser?.id,
    ));
  });
  // Stream cancellation may complete in the root zone. Dispose in the outer
  // runner rather than stranding the next Flutter fake-clock pump.
  addTearDown(observation.cancel);
  await auth.roundTrip();
  await tester.pump();
  expect(delivered, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
}

void main() {
  late _ComposerAuthFixture auth;
  late _ComposerRepository repository;
  setUp(() async {
    auth = _ComposerAuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _ComposerRepository(auth.client);
  });
  tearDown(() async {
    await auth.client.dispose();
  });

  _feedComposerOwnerTests(() => auth);

  _composerTest(
    'private draft updates do not require or create public identity',
    (tester) async {
      await _mountDraft(tester, repository);
      await tester.enterText(_body, 'Private changes kept for later');
      await _tap(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.saved.single.owner, _ownerA);
      expect(repository.saved.single.input.draftId, _draftA);
      expect(
        repository.saved.single.input.body,
        'Private changes kept for later',
      );
      expect(repository.profileReads, 0);
      expect(repository.created, isEmpty);
      expect(repository.codeOwners, isEmpty);
      expect(repository.published, isEmpty);
      expect(_editor, findsOneWidget);
    },
  );

  _composerTest(
    'private draft Publish requires R5 and a second explicit Publish',
    (tester) async {
      await _mountDraft(tester, repository);
      await tester.enterText(_body, 'Ready only after identity proof');
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(_entryName, findsOneWidget);
      expect(repository.created, isEmpty);
      expect(repository.published, isEmpty);
      await tester.enterText(_entryName, 'New member');
      await _tap(tester, find.byKey(const Key('community-entry-save')));
      await tester.pumpAndSettle();
      expect(repository.created, [_ownerA]);
      expect(repository.profiles[_ownerA]!.displayName, 'New member');
      expect(repository.codeOwners, [_ownerA]);
      expect(repository.published, isEmpty);
      expect(_editor, findsOneWidget);
      expect(
        tester.widget<TextField>(_body).controller!.text,
        'Ready only after identity proof',
      );
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published.single, (
        owner: _ownerA,
        body: 'Ready only after identity proof',
        draftId: _draftA,
      ));
      expect(
        repository.trace.indexOf('code'),
        lessThan(repository.trace.indexOf('publish')),
      );
      expect(_editor, findsNothing);
    },
  );

  _composerTest('onboarding failure and back retain the private editor input', (
    tester,
  ) async {
    repository.failCreate = true;
    await _mountDraft(tester, repository);
    await tester.enterText(_body, 'Do not lose this private revision');
    await _tap(tester, _publish);
    await tester.pumpAndSettle();
    await tester.enterText(_entryName, 'Unconfirmed member');
    await _tap(tester, find.byKey(const Key('community-entry-save')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_entryName).controller!.text,
      'Unconfirmed member',
    );
    expect(repository.published, isEmpty);
    expect(repository.codeOwners, isEmpty);
    Navigator.of(tester.element(_entryName)).pop();
    await tester.pumpAndSettle();
    expect(_editor, findsOneWidget);
    expect(
      tester.widget<TextField>(_body).controller!.text,
      'Do not lose this private revision',
    );
    expect(repository.created, isEmpty);
  });

  _composerTest(
    'existing profile still needs valid code and failed proof preserves retry',
    (tester) async {
      repository.profiles[_ownerA] = _profile(_ownerA);
      repository.failCode = true;
      await _mountDraft(tester, repository);
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published, isEmpty);
      expect(repository.created, isEmpty);
      expect(
        find.byKey(const Key('community-cancel-pending-publish')),
        findsNothing,
      );
      expect(repository.cancelled, isEmpty);
      expect(
        tester.widget<TextField>(_body).controller!.text,
        'A private saved body',
      );
      repository.failCode = false;
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published.single.owner, _ownerA);
      expect(repository.codeOwners, [_ownerA, _ownerA]);
    },
  );

  for (final roundTrip in [false, true]) {
    _composerTest(
      'open editor invalidates real ${roundTrip ? 'A B A' : 'A B'} account change',
      (tester) async {
        repository.profiles[_ownerA] = _profile(_ownerA);
        await _mountDraft(tester, repository);
        final staleSave = tester.widget<OutlinedButton>(_save).onPressed!;
        final stalePublish = tester.widget<FilledButton>(_publish).onPressed!;
        if (roundTrip) {
          await _roundTrip(tester, auth);
        } else {
          await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
          await tester.pump();
        }
        expect(_ownerChanged, findsOneWidget);
        expect(_body, findsNothing);
        staleSave();
        stalePublish();
        await tester.pumpAndSettle();
        expect(repository.saved, isEmpty);
        expect(repository.published, isEmpty);
        expect(repository.profileReads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _composerTest(
    'queued account round trip cancels pending entry profile proof',
    (tester) async {
      final pending = Completer<CommunityProfile?>();
      await _mountDraft(tester, repository);
      repository.nextProfile = pending;
      await _tap(tester, _publish);
      expect(repository.profileReads, 1);
      await _roundTrip(tester, auth);
      pending.complete(_profile(_ownerA));
      await tester.pumpAndSettle();
      expect(repository.codeOwners, isEmpty);
      expect(repository.published, isEmpty);
      expect(_ownerChanged, findsOneWidget);
    },
  );

  _composerTest(
    'queued account round trip cancels late code before publication',
    (tester) async {
      repository.profiles[_ownerA] = _profile(_ownerA);
      final pending = Completer<CommunityPublicCode>();
      await _mountDraft(tester, repository);
      repository.nextCode = pending;
      await _tap(tester, _publish);
      expect(repository.codeOwners, [_ownerA]);
      await _roundTrip(tester, auth);
      pending.complete(_code());
      await tester.pumpAndSettle();
      expect(repository.published, isEmpty);
      expect(_ownerChanged, findsOneWidget);
    },
  );

  _composerTest('late private save error cannot affect a new account', (
    tester,
  ) async {
    final pending = Completer<void>();
    await _mountDraft(tester, repository);
    repository.nextSave = pending;
    await _tap(tester, _save);
    expect(repository.saved.single.owner, _ownerA);
    await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
    await tester.pump();
    pending.completeError(StateError('Late old save failure'));
    await tester.pumpAndSettle();
    expect(_ownerChanged, findsOneWidget);
    expect(
      find.text('Could not save this draft. Nothing was published.'),
      findsNothing,
    );
    expect(find.text('Draft saved securely.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _composerTest('late publication cannot close the new account screen', (
    tester,
  ) async {
    repository.profiles[_ownerA] = _profile(_ownerA);
    final pending = Completer<void>();
    await _mountDraft(tester, repository);
    repository.nextPublish = pending;
    await _tap(tester, _publish);
    expect(repository.published.single.owner, _ownerA);
    await auth.client.auth.recoverSession(auth.sessions[_ownerB]!);
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(_ownerChanged, findsOneWidget);
    expect(repository.published, hasLength(1));
    expect(find.text('B private title'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _composerTest(
    'same-owner token refresh preserves input and normal publishing',
    (tester) async {
      repository.profiles[_ownerA] = _profile(_ownerA);
      await _mountDraft(tester, repository);
      await tester.enterText(_body, 'Same owner revised content');
      await tester.runAsync(() => auth.client.auth.refreshSession());
      await tester.pumpAndSettle();
      expect(_ownerChanged, findsNothing);
      expect(
        tester.widget<TextField>(_body).controller!.text,
        'Same owner revised content',
      );
      await _tap(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.saved.single.input.body, 'Same owner revised content');
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published.single.body, 'Same owner revised content');
      expect(repository.created, isEmpty);
    },
  );

  _composerTest(
    'stale pending-operation cancellation never targets the new owner',
    (tester) async {
      repository.profiles[_ownerA] = _profile(_ownerA);
      repository.failPublish = true;
      await _mountDraft(tester, repository);
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      final staleCancel = tester
          .widget<TextButton>(
            find.byKey(const Key('community-cancel-pending-publish')),
          )
          .onPressed!;
      await _roundTrip(tester, auth);
      staleCancel();
      await tester.pumpAndSettle();
      expect(repository.cancelled, isEmpty);
      expect(_ownerChanged, findsOneWidget);
    },
  );

  _composerTest(
    'overflow keeps every code point and blocks both write actions',
    (tester) async {
      final body = '${'a' * 1198}👩‍💻';
      expect(body.runes.length, 1201);
      await _mountDraft(tester, repository);
      await tester.enterText(_body, body);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_body).controller!.text, body);
      expect(find.text('1201 / 1200'), findsOneWidget);
      expect(
        tester.widget<TextField>(_body).decoration!.errorText,
        'Keep the text within 1200 characters. Your text is kept.',
      );
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      await _tap(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.published, isEmpty);
      expect(repository.saved, isEmpty);
      expect(repository.profileReads, 0);
      expect(repository.codeOwners, isEmpty);
      expect(tester.widget<TextField>(_body).controller!.text, body);

      final corrected = 'a' * 1200;
      await tester.enterText(_body, corrected);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_body).decoration!.errorText, isNull);
      await _tap(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.saved.single.input.body, corrected);
      expect(repository.published, isEmpty);
      expect(repository.profileReads, 0);
    },
  );

  _composerTest(
    '1200 astral code points survive a failed publish and exact retry',
    (tester) async {
      repository.profiles[_ownerA] = _profile(_ownerA);
      repository.failPublish = true;
      final body = '😀' * 1200;
      expect(body.length, 2400);
      expect(body.runes.length, 1200);
      await _mountDraft(tester, repository);
      await tester.enterText(_body, body);
      await tester.pumpAndSettle();
      expect(find.text('1200 / 1200'), findsOneWidget);
      expect(tester.widget<TextField>(_body).decoration!.errorText, isNull);
      await _tap(tester, _save);
      await tester.pumpAndSettle();
      expect(repository.saved.single.input.body, body);
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published.single.body, body);
      expect(_editor, findsOneWidget);
      expect(tester.widget<TextField>(_body).controller!.text, body);
      expect(
        find.text('Could not publish now. Your text is kept so you can retry.'),
        findsOneWidget,
      );

      repository.failPublish = false;
      await _tap(tester, _publish);
      await tester.pumpAndSettle();
      expect(repository.published, hasLength(2));
      expect(
        repository.published.every(
          (value) =>
              value.owner == _ownerA &&
              value.body == body &&
              value.draftId == _draftA,
        ),
        isTrue,
      );
      expect(repository.cancelled, isEmpty);
      expect(repository.created, isEmpty);
      expect(_editor, findsNothing);
    },
  );
}
