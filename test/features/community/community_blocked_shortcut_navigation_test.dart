import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_blocked_members_sheet.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '00000000-0000-4000-8030-000000000001';
const _ownerB = '00000000-0000-4000-8030-000000000002';
const _member = '00000000-0000-4000-8030-000000000003';
const _memberName = 'Synthetic private blocked member';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'direct Blocked shortcut preserves Safety, existing unblock and return: $locale',
      (tester) async {
        final harness = await _mount(tester, locale: Locale(locale));
        await _openMenu(tester);
        expect(
          find.byKey(const Key('community-nav-/community/safety')),
          findsOneWidget,
        );
        final callback = tester
            .widget<ListTile>(
              find.byKey(const Key('community-blocked-members-shortcut')),
            )
            .onTap!;
        await tester.tap(
          find.byKey(const Key('community-blocked-members-shortcut')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CommunityBlockedMembersSheet), findsOneWidget);
        expect(find.text(_memberName), findsOneWidget);
        expect(harness.repository.blockedReads, [_ownerA]);
        // A queued menu click cannot pop the sheet that replaced the menu.
        callback();
        await tester.pumpAndSettle();
        expect(find.byType(CommunityBlockedMembersSheet), findsOneWidget);
        await tester.tap(find.byKey(const Key('community-unblock-$_member')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-unblock-confirm')));
        await tester.pumpAndSettle();
        expect(harness.repository.unblocks, [(_ownerA, _member)]);
        expect(find.text(_memberName), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('community-settings')), findsOneWidget);
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          '/community',
        );
        expect(harness.repository.feedReads, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final transition in ['A to B', 'A to B to A']) {
    testWidgets(
      'old Blocked shortcut cannot load private rows after $transition',
      (tester) async {
        final harness = await _mount(tester);
        await _openMenu(tester);
        final callback = tester
            .widget<ListTile>(
              find.byKey(const Key('community-blocked-members-shortcut')),
            )
            .onTap!;
        await harness.changeOwner(tester, transition);
        callback();
        await tester.pumpAndSettle();
        expect(find.byType(CommunityBlockedMembersSheet), findsNothing);
        expect(find.text(_memberName), findsNothing);
        expect(harness.repository.blockedReads, isEmpty);
        expect(harness.repository.unblocks, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'open blocked sheet retires rows and writes after $transition',
      (tester) async {
        final harness = await _mount(tester);
        await _openMenu(tester);
        await tester.tap(
          find.byKey(const Key('community-blocked-members-shortcut')),
        );
        await tester.pumpAndSettle();
        final unblock = tester
            .widget<OutlinedButton>(
              find.byKey(const Key('community-unblock-$_member')),
            )
            .onPressed!;
        await harness.changeOwner(tester, transition);
        unblock();
        await tester.pumpAndSettle();
        expect(find.text(_memberName), findsNothing);
        expect(
          find.byKey(const Key('community-unblock-confirm')),
          findsNothing,
        );
        expect(harness.repository.blockedReads, [_ownerA]);
        expect(harness.repository.unblocks, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'stale unblock confirmation cannot pop a covering replacement route',
    (tester) async {
      final harness = await _mount(tester);
      await _openMenu(tester);
      await tester.tap(
        find.byKey(const Key('community-blocked-members-shortcut')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-unblock-$_member')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('community-unblock-confirm'));
      final oldCallback = tester.widget<FilledButton>(confirm).onPressed!;
      final navigator = Navigator.of(
        tester.element(confirm),
        rootNavigator: true,
      );
      final replacement = MaterialPageRoute<bool>(
        builder: (_) => const Scaffold(body: Text('Replacement route')),
      );
      unawaited(navigator.push<bool>(replacement));
      await tester.pumpAndSettle();
      expect(replacement.isCurrent, isTrue);
      oldCallback();
      await tester.pumpAndSettle();
      expect(
        replacement.isCurrent,
        isTrue,
        reason: 'An old confirmation must not pop the replacement route.',
      );
      expect(find.text('Replacement route'), findsOneWidget);
      expect(harness.repository.unblocks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'stale unblock confirmation is inert after A to B to A retirement and route removal',
    (tester) async {
      final harness = await _mount(tester);
      await _openMenu(tester);
      await tester.tap(
        find.byKey(const Key('community-blocked-members-shortcut')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-unblock-$_member')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('community-unblock-confirm'));
      final oldCallback = tester.widget<FilledButton>(confirm).onPressed!;
      final dialog = ModalRoute.of(tester.element(confirm))!;
      final navigator = Navigator.of(
        tester.element(confirm),
        rootNavigator: true,
      );
      await harness.changeOwner(tester, 'A to B to A');
      expect(
        dialog.isActive,
        isFalse,
        reason: 'Owner retirement removes only the captured dialog.',
      );
      // External navigation may already have removed the retired dialog.
      if (dialog.isActive) navigator.removeRoute(dialog, false);
      await tester.pumpAndSettle();
      final replacement = MaterialPageRoute<bool>(
        builder: (_) =>
            const Scaffold(body: Text('Replacement after retirement')),
      );
      unawaited(navigator.push<bool>(replacement));
      await tester.pumpAndSettle();
      Object? callbackError;
      try {
        oldCallback();
      } on Object catch (error) {
        callbackError = error;
      }
      await tester.pumpAndSettle();
      expect(
        callbackError,
        isNull,
        reason: 'A retired confirmation must not read a deactivated context.',
      );
      expect(replacement.isCurrent, isTrue);
      expect(find.text('Replacement after retirement'), findsOneWidget);
      expect(harness.repository.unblocks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'owner retirement removes only the old unblock dialog below a replacement',
    (tester) async {
      final harness = await _mount(tester);
      await _openMenu(tester);
      await tester.tap(
        find.byKey(const Key('community-blocked-members-shortcut')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-unblock-$_member')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('community-unblock-confirm'));
      final oldCallback = tester.widget<FilledButton>(confirm).onPressed!;
      final dialog = ModalRoute.of(tester.element(confirm))!;
      final navigator = Navigator.of(
        tester.element(confirm),
        rootNavigator: true,
      );
      final replacement = MaterialPageRoute<bool>(
        builder: (_) =>
            const Scaffold(body: Text('Replacement during retirement')),
      );
      unawaited(navigator.push<bool>(replacement));
      await tester.pumpAndSettle();
      await harness.changeOwner(tester, 'A to B to A');
      expect(dialog.isActive, isFalse);
      expect(replacement.isCurrent, isTrue);
      oldCallback();
      await tester.pumpAndSettle();
      expect(replacement.isCurrent, isTrue);
      expect(find.text('Replacement during retirement'), findsOneWidget);
      expect(harness.repository.unblocks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a delayed blocked-list response cannot reappear after A to B to A',
    (tester) async {
      final harness = await _mount(tester);
      final pending = Completer<List<CommunityBlockedMember>>();
      harness.repository.pendingBlocked = pending;
      await _openMenu(tester);
      await tester.tap(
        find.byKey(const Key('community-blocked-members-shortcut')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await harness.changeOwner(tester, 'A to B to A');
      pending.complete([
        CommunityBlockedMember(
          id: _member,
          createdAt: DateTime.utc(2026, 11, 16),
          name: _memberName,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text(_memberName), findsNothing);
      expect(harness.repository.blockedReads, [_ownerA]);
      expect(harness.repository.unblocks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('community-settings')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('community-blocked-members-shortcut')),
    250,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('community-navigation-sheet')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final auth = (await tester.runAsync(() async {
    final fixture = _AuthFixture();
    await fixture.signIn(_ownerA);
    return fixture;
  }))!;
  final harness = _Harness(auth);
  addTearDown(auth.client.dispose);
  addTearDown(harness.router.dispose);
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: harness.router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

final class _Harness {
  _Harness(this.auth) {
    repository = _Repository(auth.client);
    router = GoRouter(
      initialLocation: '/community',
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, _) => CommunityHubPage(
            repository: repository,
            entryWelcomeHandled: true,
          ),
        ),
      ],
    );
  }
  final _AuthFixture auth;
  late final _Repository repository;
  late final GoRouter router;
  Future<void> changeOwner(WidgetTester tester, String transition) async {
    for (final owner
        in transition == 'A to B' ? [_ownerB] : [_ownerB, _ownerA]) {
      await tester.runAsync(() => auth.signIn(owner));
      await tester.pumpAndSettle();
    }
  }
}

final class _Repository extends CommunityRepository {
  _Repository(super.client);
  final blockedReads = <String>[];
  final unblocks = <(String, String)>[];
  Completer<List<CommunityBlockedMember>>? pendingBlocked;
  var blocked = true;
  var feedReads = 0;
  @override
  Future<List<CommunityBlockedMember>> loadBlockedMembers() async {
    blockedReads.add(currentUserId);
    if (pendingBlocked case final held?) return held.future;
    return blocked
        ? [
            CommunityBlockedMember(
              id: _member,
              createdAt: DateTime.utc(2026, 11, 16),
              name: _memberName,
            ),
          ]
        : [];
  }

  @override
  Future<void> unblockMember(String id) async {
    unblocks.add((currentUserId, id));
    blocked = false;
  }

  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: currentUserId,
    displayName: 'Synthetic account',
    localeCode: 'en',
    discoverable: false,
  );
  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      CommunityProfileOverview.fromProfile((await loadMyProfile())!);
  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];
  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [];
  @override
  Future<CommunityAttention> loadAttention() async =>
      const CommunityAttention();
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': 'en',
      'document_url': 'https://example.invalid/policy',
      'effective_at': '2026-09-08T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
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
  }) async {
    feedReads++;
    return const CommunityFeedModeBatch(
      posts: [],
      references: [],
      hasMore: false,
    );
  }
}

// Only synthetic Auth/RPC HTTP is used. No hosted backend or OS health store.
final class _AuthFixture {
  _AuthFixture() {
    client = SupabaseClient(
      'https://cloud-owner-choice.invalid',
      'fixture-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_handle)),
    );
  }

  late final SupabaseClient client;
  final writes = <(String, bool)>[];

  Future<void> signIn(String owner) async {
    await client.auth.signInWithPassword(
      email: '$owner@example.invalid',
      password: 'fixture',
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<http.Response> _handle(http.Request request) async {
    expect(request.url.host, 'cloud-owner-choice.invalid');
    final Object body;
    if (request.url.path == '/auth/v1/token') {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final owner = email.split('@').first;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture-refresh-token-$owner',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-20T00:00:00Z',
        },
      };
    } else if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
      final token = request.headers['Authorization']!.split(' ').last;
      final owner =
          (jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(token.split('.')[1]),
                      ),
                    ),
                  )
                  as Map)['sub']
              as String;
      final params = jsonDecode(request.body) as Map;
      expect(params['p_purpose'], 'cloud_sync');
      expect(params['p_policy_version'], '1');
      writes.add((owner, params['p_granted'] as bool));
      body = {'recorded': true};
    } else {
      throw StateError('Unexpected synthetic request: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
