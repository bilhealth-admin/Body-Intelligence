import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_welcome.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/features/community/services/community_entry_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = '11111111-1111-4111-8111-111111111111';
const ownerB = '22222222-2222-4222-8222-222222222222';
const codeValue = 'aabbccddaabbccddaabbccddaabbccdd';
final _entryClients = <String, SupabaseClient>{};
final _entryUiDisposers = <VoidCallback>[];

// Initialize and dispose Supabase's JSON worker in the real runner zone.
// A worker created under a widget fake clock can outlive that clock and hang
// disposal even when the individual widget assertions have already passed.
SupabaseClient createEntryTestClient() => SupabaseClient(
  'https://entry.invalid',
  'fixture-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

EntryRepositoryFixture _entryRepository({String? owner = ownerA}) =>
    EntryRepositoryFixture(_entryClients[owner ?? ownerA]!, owner: owner);

void _entryTest(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final dispose in _entryUiDisposers.reversed) {
        dispose();
      }
      _entryUiDisposers.clear();
    }
  });
}

CommunityPublicCode validCode() => CommunityPublicCode(
  code: codeValue,
  uri: Uri.parse('bil://community/member/$codeValue'),
  handle: 'member_qa',
);
CommunityProfile profile(String owner, {String name = 'Existing member'}) =>
    CommunityProfile(
      userId: owner,
      displayName: name,
      localeCode: 'en',
      discoverable: false,
      visibility: CommunityProfileVisibility.private,
      allowFriendRequests: false,
      allowFollows: false,
      allowMessagesFrom: CommunityMessagePermission.nobody,
      bio: 'Private optional details',
      avatarUrl: 'https://example.invalid/avatar',
    );

class EntryRepositoryFixture extends CommunityRepository {
  EntryRepositoryFixture(super.client, {this.owner = ownerA});
  String? owner;
  final profiles = <String, CommunityProfile>{};
  final writes = <({String owner, String name, String locale})>[];
  int reads = 0, codeReads = 0;
  bool failRead = false,
      failCreate = false,
      failCode = false,
      skipPersistence = false;
  CommunityPublicCode? suppliedCode;
  Future<CommunityProfile?>? pendingRead;
  Future<void>? pendingCreate;
  Future<CommunityPublicCode>? pendingCode;
  void Function()? onCreate;
  @override
  String get currentUserId =>
      owner ?? (throw const AuthException('Signed out'));
  @override
  Future<CommunityProfile?> loadMyProfile() async {
    reads++;
    if (failRead) throw StateError('Synthetic read failure');
    final pending = pendingRead;
    if (pending != null) return await pending;
    return profiles[currentUserId];
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeReads++;
    if (failCode) throw StateError('Synthetic code failure');
    final pending = pendingCode;
    if (pending != null) return await pending;
    return suppliedCode ?? validCode();
  }

  @override
  Future<void> createMyCommunityEntryProfile({
    required String displayName,
    required String localeCode,
    required String expectedOwnerId,
  }) async {
    if (currentUserId != expectedOwnerId) {
      throw const CommunityEntryOwnerChanged();
    }
    writes.add((owner: expectedOwnerId, name: displayName, locale: localeCode));
    if (pendingCreate != null) await pendingCreate;
    if (currentUserId != expectedOwnerId) {
      throw const CommunityEntryOwnerChanged();
    }
    if (failCreate) throw StateError('Synthetic create failure');
    onCreate?.call();
    if (!skipPersistence) {
      profiles.putIfAbsent(
        expectedOwnerId,
        () => profile(expectedOwnerId, name: displayName),
      );
    }
  }
}

class EntryWidgetFixture {
  EntryWidgetFixture(this.repository);
  EntryRepositoryFixture repository;
  late StateSetter update;
  GoRouter? router;
  Future<bool> Function()? syncPhoto;
  bool welcome = false;
  Widget app({Locale locale = const Locale('en'), double scale = 1}) {
    router = GoRouter(
      initialLocation: '/community?fixture=preserved',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/community',
          builder: (_, state) => StatefulBuilder(
            builder: (_, change) {
              update = change;
              return CommunityEntryGate(
                repository: repository,
                showWelcome: welcome,
                syncPhoto: syncPhoto,
                child: Scaffold(
                  body: Text('Member destination ${state.uri.query}'),
                ),
              );
            },
          ),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
  }
}

Future<EntryWidgetFixture> mountEntry(
  WidgetTester tester, {
  EntryRepositoryFixture? repository,
  EntryWidgetFixture? fixture,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final value = fixture ?? EntryWidgetFixture(repository ?? _entryRepository());
  _entryUiDisposers.add(() {
    value.router?.dispose();
  });
  await tester.pumpWidget(value.app(locale: locale, scale: scale));
  await tester.pump();
  return value;
}

Future<void> submitEntry(WidgetTester tester, String name) async {
  final field = find.byKey(const Key('community-entry-name'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, name);
  final save = find.byKey(const Key('community-entry-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  expect(save.hitTestable(), findsOneWidget);
  await tester.tap(save);
  await tester.pump();
}

void main() {
  setUp(() {
    _entryUiDisposers.clear();
    for (final owner in [ownerA, ownerB]) {
      _entryClients[owner] = createEntryTestClient();
    }
  });
  tearDown(() async {
    for (final client in _entryClients.values) {
      await client.dispose();
    }
    _entryClients.clear();
  });

  test('checking missing profile never writes or provisions a code', () async {
    final r = _entryRepository();
    expect(await CommunityEntryCoordinator(r).check(), isNull);
    expect(r.writes, isEmpty);
    expect(r.codeReads, 0);
  });
  test(
    'existing private profile and public code are preserved without writes',
    () async {
      final r = _entryRepository()..profiles[ownerA] = profile(ownerA);
      final c = CommunityEntryCoordinator(r);
      final receipt = await c.save(
        displayName: 'New unwanted name',
        localeCode: 'ar',
      );
      expect(receipt.profile, same(r.profiles[ownerA]));
      expect(receipt.profile.visibility, CommunityProfileVisibility.private);
      expect(receipt.profile.allowFriendRequests, false);
      expect(r.writes, isEmpty);
      expect(r.codeReads, 1);
    },
  );
  test('name-only save reads persisted profile and validated code', () async {
    final r = _entryRepository();
    final receipt = await CommunityEntryCoordinator(
      r,
    ).save(displayName: '  Alex  ', localeCode: 'en');
    expect(r.writes.single, (owner: ownerA, name: 'Alex', locale: 'en'));
    expect(receipt.profile.displayName, 'Alex');
    expect(receipt.code.code, codeValue);
    expect(r.reads, 2);
  });
  test('double save shares the same in-flight future and one insert', () async {
    final wait = Completer<void>();
    final r = _entryRepository()..pendingCreate = wait.future;
    final c = CommunityEntryCoordinator(r);
    final one = c.save(displayName: 'Alex', localeCode: 'en');
    final two = c.save(displayName: 'Alex', localeCode: 'en');
    expect(identical(one, two), true);
    wait.complete();
    await Future.wait([one, two]);
    expect(r.writes.length, 1);
  });
  test(
    'code failure after saved profile retries without an overwrite',
    () async {
      final r = _entryRepository()..failCode = true;
      final c = CommunityEntryCoordinator(r);
      await expectLater(
        c.save(displayName: 'Alex', localeCode: 'en'),
        throwsStateError,
      );
      r.failCode = false;
      await c.save(displayName: 'Alex', localeCode: 'en');
      expect(r.writes.length, 1);
      expect(r.codeReads, 2);
    },
  );
  test('unconfirmed save cannot create a successful entry receipt', () async {
    final r = _entryRepository()..skipPersistence = true;
    await expectLater(
      CommunityEntryCoordinator(r).save(displayName: 'Alex', localeCode: 'en'),
      throwsStateError,
    );
    expect(r.codeReads, 0);
  });
  test(
    'profile created concurrently retains authoritative privacy and name',
    () async {
      final r = _entryRepository();
      r.onCreate = () =>
          r.profiles[ownerA] = profile(ownerA, name: 'Saved elsewhere');
      final result = await CommunityEntryCoordinator(
        r,
      ).save(displayName: 'Alex', localeCode: 'ar');
      expect(result.profile.displayName, 'Saved elsewhere');
      expect(result.profile.visibility, CommunityProfileVisibility.private);
    },
  );
  test(
    'switching accounts during check does not request another owner code',
    () async {
      final wait = Completer<CommunityProfile?>();
      final r = _entryRepository()..pendingRead = wait.future;
      final result = CommunityEntryCoordinator(r).check();
      final failure = expectLater(
        result,
        throwsA(isA<CommunityEntryOwnerChanged>()),
      );
      r.owner = ownerB;
      wait.complete(profile(ownerA));
      await failure;
      expect(r.codeReads, 0);
    },
  );
  test(
    'switching accounts during code retrieval invalidates receipt',
    () async {
      final wait = Completer<CommunityPublicCode>();
      final r = _entryRepository()
        ..profiles[ownerA] = profile(ownerA)
        ..pendingCode = wait.future;
      final result = CommunityEntryCoordinator(r).check();
      final failure = expectLater(
        result,
        throwsA(isA<CommunityEntryOwnerChanged>()),
      );
      await Future<void>.delayed(Duration.zero);
      r.owner = ownerB;
      wait.complete(validCode());
      await failure;
    },
  );
  test('malformed code cannot pass entry even with a valid profile', () async {
    final r = _entryRepository()
      ..profiles[ownerA] = profile(ownerA)
      ..suppliedCode = CommunityPublicCode(
        code: codeValue,
        uri: Uri.parse('https://attacker.invalid'),
        handle: 'member_qa',
      );
    await expectLater(
      CommunityEntryCoordinator(r).check(),
      throwsFormatException,
    );
  });
  for (final invalid in ['', ' ', 'A', List.filled(61, 'a').join()]) {
    test(
      'invalid name is not sent to repository (${invalid.length})',
      () async {
        final r = _entryRepository();
        await expectLater(
          CommunityEntryCoordinator(
            r,
          ).save(displayName: invalid, localeCode: 'en'),
          throwsFormatException,
        );
        expect(r.writes, isEmpty);
      },
    );
  }
  _entryTest(
    'entry shows one name field, no fabricated code or extra requirements',
    (tester) async {
      final f = await mountEntry(tester);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CommunityEntryWelcome), findsOneWidget);
      expect(find.textContaining('Member destination'), findsNothing);
      expect(f.repository.writes, isEmpty);
      expect(f.repository.codeReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  _entryTest(
    'branded welcome precedes form and no member content loads behind it',
    (tester) async {
      final f = EntryWidgetFixture(_entryRepository())..welcome = true;
      await mountEntry(tester, fixture: f);
      expect(find.byType(CommunityWelcome), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityWelcome), findsNothing);
      expect(find.byType(CommunityEntryWelcome), findsOneWidget);
      expect(f.repository.writes, isEmpty);
    },
  );
  _entryTest('saved profile and code release original deep-link destination', (
    tester,
  ) async {
    final f = await mountEntry(tester);
    await tester.pumpAndSettle();
    await submitEntry(tester, 'Alex');
    await tester.pumpAndSettle();
    expect(find.text('Member destination fixture=preserved'), findsOneWidget);
    expect(f.repository.writes.length, 1);
    expect(find.byType(CommunityEntryWelcome), findsNothing);
    expect(tester.takeException(), isNull);
  });
  _entryTest('existing member enters without rewriting identity', (
    tester,
  ) async {
    final r = _entryRepository()..profiles[ownerA] = profile(ownerA);
    await mountEntry(tester, repository: r);
    await tester.pumpAndSettle();
    expect(find.textContaining('Member destination'), findsOneWidget);
    expect(r.writes, isEmpty);
  });
  _entryTest('failed check offers retry and never a creation shortcut', (
    tester,
  ) async {
    final r = _entryRepository()..failRead = true;
    await mountEntry(tester, repository: r);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-entry-retry')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(r.writes, isEmpty);
    r.failRead = false;
    await tester.tap(find.byKey(const Key('community-entry-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
  _entryTest('save failure preserves name and repeated submission is safe', (
    tester,
  ) async {
    final r = _entryRepository()..failCode = true;
    await mountEntry(tester, repository: r);
    await tester.pumpAndSettle();
    await submitEntry(tester, 'Alex');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-entry-error')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Alex',
    );
    r.failCode = false;
    await submitEntry(tester, 'Alex');
    await tester.pumpAndSettle();
    expect(find.textContaining('Member destination'), findsOneWidget);
    expect(r.writes.length, 1);
  });
  _entryTest(
    'optional photo failure does not hold entry or delete the saved profile',
    (tester) async {
      final wait = Completer<bool>();
      final f = EntryWidgetFixture(_entryRepository())
        ..syncPhoto = () => wait.future;
      await mountEntry(tester, fixture: f);
      await tester.pumpAndSettle();
      await submitEntry(tester, 'Alex');
      await tester.pumpAndSettle();
      expect(find.textContaining('Member destination'), findsOneWidget);
      wait.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(f.repository.profiles[ownerA], isNotNull);
    },
  );
  _entryTest('cold entry can always go back even while saving', (tester) async {
    final wait = Completer<void>();
    final r = _entryRepository()..pendingCreate = wait.future;
    await mountEntry(tester, repository: r);
    await tester.pumpAndSettle();
    await submitEntry(tester, 'Alex');
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    wait.complete();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  _entryTest(
    'old late profile cannot release content for new repository owner',
    (tester) async {
      final wait = Completer<CommunityProfile?>();
      final a = _entryRepository()..pendingRead = wait.future;
      final b = _entryRepository(owner: ownerB);
      final f = await mountEntry(tester, repository: a);
      f.update(() => f.repository = b);
      await tester.pumpAndSettle();
      wait.complete(profile(ownerA));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityEntryWelcome), findsOneWidget);
      expect(find.textContaining('Member destination'), findsNothing);
    },
  );
  _entryTest(
    'invalid name is retained without silently clipping 61 characters',
    (tester) async {
      final f = await mountEntry(tester);
      await tester.pumpAndSettle();
      final name = List.filled(61, 'a').join();
      await submitEntry(tester, name);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        name,
      );
      expect(f.repository.writes, isEmpty);
      expect(find.byKey(const Key('community-entry-error')), findsOneWidget);
    },
  );
  test('every shipping locale has complete authored onboarding copy', () {
    expect(
      CommunityEntryCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    for (final tag in BilLocalePolicy.productionTags) {
      expect(
        CommunityEntryCopy.rows[tag],
        hasLength(CommunityEntryCopyKey.values.length),
      );
      for (final key in CommunityEntryCopyKey.values) {
        final value = CommunityEntryCopy.resolve(tag, key);
        expect(value.trim(), isNotEmpty);
        if (tag != 'en') {
          expect(value, isNot(CommunityEntryCopy.resolve('en', key)));
        }
      }
    }
  });
  for (final tag in BilLocalePolicy.productionTags) {
    _entryTest('name-only entry remains usable at 200% and narrow width $tag', (
      tester,
    ) async {
      await mountEntry(
        tester,
        locale: BilLocalePolicy.localeFromTag(tag),
        scale: 2,
        size: const Size(320, 720),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('community-entry-save'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
