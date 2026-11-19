import 'dart:async';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository extends CommunityRepository {
  _Repository({this.owner = '00000000-0000-4000-8000-000000000001'})
    : super(
        SupabaseClient(
          'https://qr-privacy.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final String owner;
  bool discoverable = true, requests = true, readFails = false;
  CommunityProfileVisibility visibility = CommunityProfileVisibility.friends;
  Completer<CommunityProfile?>? held;
  int reads = 0, writes = 0, rotations = 0;
  @override
  String get currentUserId => owner;
  CommunityProfile profile() => CommunityProfile(
    userId: owner,
    displayName: 'Synthetic member',
    localeCode: 'en',
    discoverable: discoverable,
    allowFriendRequests: requests,
    visibility: visibility,
  );
  @override
  Future<CommunityProfile?> loadMyProfile() async {
    reads++;
    if (readFails) throw StateError('synthetic unavailable');
    return held == null ? profile() : held!.future;
  }

  @override
  Future<void> saveMyProfile({
    required String displayName,
    required String localeCode,
    required bool discoverable,
    String? bio,
    CommunityProfileVisibility visibility = CommunityProfileVisibility.friends,
    bool allowFriendRequests = true,
    bool allowFollows = false,
    CommunityMessagePermission allowMessagesFrom =
        CommunityMessagePermission.friends,
  }) async {
    writes++;
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async =>
      CommunityPublicCode.fromJson({
        'code': '0123456789abcdef0123456789abcdef',
        'uri': 'bil://community/member/0123456789abcdef0123456789abcdef',
        'handle': owner.endsWith('2') ? 'member_b' : 'member_a',
      });
  @override
  Future<CommunityPublicCode> rotatePublicCode() async {
    rotations++;
    return loadPublicCode();
  }
}

Future<_Repository> _newRepository(
  WidgetTester tester, {
  String owner = '00000000-0000-4000-8000-000000000001',
}) async => (await tester.runAsync(() async => _Repository(owner: owner)))!;

Future<void> _mount(WidgetTester tester, _Repository repository) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(home: CommunityBilCodePage(repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final condition in ['undiscoverable', 'requests-off', 'private']) {
    testWidgets(
      '$condition own code explains privacy without changing settings',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = (await _newRepository(tester));
        if (condition == 'undiscoverable') repository.discoverable = false;
        if (condition == 'requests-off') repository.requests = false;
        if (condition == 'private') {
          repository.visibility = CommunityProfileVisibility.private;
        }
        await _mount(tester, repository);
        expect(
          find.byKey(const Key('community-code-privacy-blocked')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('community-bil-code-qr')), findsOneWidget);
        expect(
          find.byKey(const Key('community-code-review-privacy')),
          findsOneWidget,
        );
        expect(repository.writes, 0);
        expect(repository.rotations, 0);
        expect(repository.discoverable, condition != 'undiscoverable');
        expect(repository.requests, condition != 'requests-off');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => repository.communitySocialClient.dispose());
      },
    );
  }
  testWidgets(
    'discoverable friends-only profile keeps a working code without a false privacy warning',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = (await _newRepository(tester));
      await _mount(tester, repository);
      expect(
        find.byKey(const Key('community-code-privacy-blocked')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('community-code-privacy-unknown')),
        findsNothing,
      );
      expect(find.byKey(const Key('community-bil-code-qr')), findsOneWidget);
      expect(repository.reads, 1);
      expect(repository.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => repository.communitySocialClient.dispose());
    },
  );
  testWidgets(
    'unknown privacy never claims the code is expired or switches discovery on',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = (await _newRepository(tester))..readFails = true;
      await _mount(tester, repository);
      expect(
        find.byKey(const Key('community-code-privacy-unknown')),
        findsOneWidget,
      );
      expect(find.textContaining('expired'), findsNothing);
      expect(repository.writes, 0);
      expect(repository.rotations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => repository.communitySocialClient.dispose());
    },
  );
  testWidgets('late privacy guidance never shifts the displayed optical code', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final held = Completer<CommunityProfile?>();
    final repository = (await _newRepository(tester))
      ..discoverable = false
      ..held = held;
    await _mount(tester, repository);
    final qr = find.byKey(const Key('community-bil-code-qr'));
    final before = tester.getRect(qr);
    held.complete(repository.profile());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-code-privacy-blocked')),
      findsOneWidget,
    );
    expect(tester.getRect(qr), before);
    expect(repository.writes, 0);
    expect(repository.rotations, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => repository.communitySocialClient.dispose());
  });
  testWidgets(
    'review action uses the existing profile route and rereads saved privacy on return',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = (await _newRepository(tester))..discoverable = false;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => CommunityBilCodePage(repository: repository),
          ),
          GoRoute(
            path: '/community/profile',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  repository.discoverable = true;
                  context.pop();
                },
                child: const Text('Saved elsewhere'),
              ),
            ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-code-review-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('Saved elsewhere'), findsOneWidget);
      expect(
        repository.discoverable,
        isFalse,
        reason: 'Opening settings must not toggle privacy.',
      );
      await tester.tap(find.text('Saved elsewhere'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-code-privacy-blocked')),
        findsNothing,
      );
      expect(repository.reads, 2);
      expect(repository.writes, 0);
      expect(repository.rotations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.runAsync(() => repository.communitySocialClient.dispose());
    },
  );
  testWidgets('late privacy data from retired A cannot label the B code', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final held = Completer<CommunityProfile?>();
    final a = (await _newRepository(tester))
      ..discoverable = false
      ..held = held;
    final b = (await _newRepository(
      tester,
      owner: '00000000-0000-4000-8000-000000000002',
    ));
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(home: CommunityBilCodePage(repository: a)),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: CommunityBilCodePage(repository: b)),
    );
    await tester.pumpAndSettle();
    held.complete(a.profile());
    await tester.pumpAndSettle();
    expect(find.text('@member_b'), findsOneWidget);
    expect(
      find.byKey(const Key('community-code-privacy-blocked')),
      findsNothing,
    );
    expect(a.writes + b.writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => a.communitySocialClient.dispose());
    await tester.runAsync(() => b.communitySocialClient.dispose());
  });
}
