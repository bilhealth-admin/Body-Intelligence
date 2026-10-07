import 'dart:async';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/community_rewards_rpc_fixture.dart';

final _claim = find.byKey(const Key('community-quest-claim-qa_profile_quest'));
final _changed = find.byKey(const Key('community-rewards-owner-changed'));
final _balance = find.byKey(const Key('community-gold-balance'));

void main() {
  late RewardsRpcFixture fixture;
  setUp(() async {
    fixture = RewardsRpcFixture();
    await fixture.prepare();
  });
  tearDown(() => fixture.client.dispose());

  Future<GoRouter> mount(
    WidgetTester tester, {
    ValueNotifier<CommunityRepository?>? selected,
    bool settle = true,
  }) async {
    final repository = selected ?? ValueNotifier(fixture.repository);
    if (selected == null) addTearDown(repository.dispose);
    final router = GoRouter(
      initialLocation: '/community/rewards',
      routes: [
        GoRoute(
          path: '/community/rewards',
          builder: (_, _) => ValueListenableBuilder<CommunityRepository?>(
            valueListenable: repository,
            builder: (_, value, _) => CommunityRewardsPage(
              key: const Key('stable-rewards-visit'),
              repository: value,
            ),
          ),
        ),
        GoRoute(
          path: '/community/compose',
          builder: (_, _) => const Scaffold(body: Text('Composer target')),
        ),
        GoRoute(
          path: '/community/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile target')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard target')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    if (settle) await tester.pumpAndSettle();
    return router;
  }

  void ownerTest(String name, WidgetTesterCallback test) {
    testWidgets(name, (tester) async {
      try {
        await test(tester);
      } finally {
        final release = fixture.release;
        if (release != null && !release.isCompleted) release.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  Future<void> switchOwner(WidgetTester tester, bool roundTrip) async {
    if (roundTrip) {
      await fixture.roundTrip();
    } else {
      await fixture.recover(rewardsOwnerB);
    }
    await tester.pump();
  }

  for (final roundTrip in [false, true]) {
    ownerTest('loaded Rewards retire on owner transition ABA=$roundTrip', (
      tester,
    ) async {
      final router = await mount(tester);
      expect(find.text('7001'), findsOneWidget);
      final staleClaim = tester.widget<FilledButton>(_claim).onPressed!;
      await switchOwner(tester, roundTrip);
      expect(_changed, findsOneWidget);
      expect(_balance, findsNothing);
      staleClaim();
      await tester.pumpAndSettle();
      expect(fixture.count(rewardsClaimRpc), 0);
      expect(fixture.count(rewardsBalanceRpc), 1);
      await tester.tap(find.byKey(const Key('community-safe-return')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    });

    for (final fail in [false, true]) {
      ownerTest(
        'late Rewards balance ABA=$roundTrip failure=$fail never renders old data',
        (tester) async {
          fixture.holdMethod = rewardsBalanceRpc;
          fixture.release = Completer<void>();
          await mount(tester, settle: false);
          await tester.pump();
          expect(fixture.entered.isCompleted, isTrue);
          await switchOwner(tester, roundTrip);
          fixture.failResponse = fail;
          fixture.release!.complete();
          await tester.pumpAndSettle();
          expect(_changed, findsOneWidget);
          expect(_balance, findsNothing);
          expect(find.text('7001'), findsNothing);
          expect(find.text('8002'), findsNothing);
          expect(fixture.count(rewardsBalanceRpc), 1);
          expect(
            fixture.requests.every((row) => row.owner == rewardsOwnerA),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    ownerTest('late claim ABA=$roundTrip cannot toast or reload another visit', (
      tester,
    ) async {
      await mount(tester);
      fixture.holdMethod = rewardsClaimRpc;
      fixture.release = Completer<void>();
      await tester.tap(_claim);
      await tester.pump();
      expect(fixture.count(rewardsClaimRpc), 1);
      await switchOwner(tester, roundTrip);
      fixture.release!.complete();
      await tester.pumpAndSettle();
      expect(_changed, findsOneWidget);
      expect(_balance, findsNothing);
      expect(find.text('Reward claimed.'), findsNothing);
      expect(
        find.text('Could not claim this reward safely. Try again.'),
        findsNothing,
      );
      expect(fixture.count(rewardsBalanceRpc), 1);
      expect(
        fixture.requests.every((row) => row.owner == rewardsOwnerA),
        isTrue,
      );
      // The server committed for A; cancelling UI must not grant/reverse again.
      expect(fixture.balances[rewardsOwnerA], 7026);
      expect(fixture.balances[rewardsOwnerB], 8002);
    });
  }

  ownerTest(
    'same owner refresh preserves the in-flight claim and authoritative readback',
    (tester) async {
      await mount(tester);
      fixture.holdMethod = rewardsClaimRpc;
      fixture.release = Completer<void>();
      await tester.tap(_claim);
      await tester.pump();
      await fixture.recover(rewardsOwnerA);
      fixture.release!.complete();
      await tester.pumpAndSettle();
      expect(_changed, findsNothing);
      expect(find.text('7026'), findsOneWidget);
      expect(find.text('Claimed'), findsOneWidget);
      expect(fixture.count(rewardsClaimRpc), 1);
      expect(fixture.count(rewardsBalanceRpc), 2);
    },
  );

  ownerTest(
    'repository replacement and removal cannot revive an old reward visit',
    (tester) async {
      final selected = ValueNotifier<CommunityRepository?>(fixture.repository);
      addTearDown(selected.dispose);
      await mount(tester, selected: selected);
      selected.value = null;
      await tester.pumpAndSettle();
      selected.value = fixture.repository;
      await tester.pumpAndSettle();
      expect(_changed, findsOneWidget);
      expect(_balance, findsNothing);
      expect(fixture.count(rewardsBalanceRpc), 1);
      expect(fixture.count(rewardsClaimRpc), 0);
    },
  );

  ownerTest(
    'late pagination cannot restore retired history or issue another page',
    (tester) async {
      fixture.historyHasMore = true;
      await mount(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      final more = find.text('Load more');
      await tester.scrollUntilVisible(
        more,
        400,
        maxScrolls: 50,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();
      fixture.holdMethod = rewardsHistoryRpc;
      fixture.release = Completer<void>();
      await tester.tap(more);
      await tester.pump();
      expect(fixture.count(rewardsHistoryRpc), 2);
      await fixture.roundTrip();
      await tester.pump();
      fixture.release!.complete();
      await tester.pumpAndSettle();
      expect(_changed, findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(_balance, findsNothing);
      expect(fixture.count(rewardsHistoryRpc), 2);
      expect(
        fixture.requests.every((row) => row.owner == rewardsOwnerA),
        isTrue,
      );
    },
  );

  ownerTest(
    'closing Rewards while claim is pending cannot show an unrelated toast',
    (tester) async {
      final router = await mount(tester);
      fixture.holdMethod = rewardsClaimRpc;
      fixture.release = Completer<void>();
      await tester.tap(_claim);
      await tester.pump();
      router.go('/dashboard');
      await tester.pumpAndSettle();
      fixture.release!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Dashboard target'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(fixture.count(rewardsBalanceRpc), 1);
      expect(tester.takeException(), isNull);
    },
  );

  ownerTest('stale Earn and Go callbacks cannot navigate for a later account', (
    tester,
  ) async {
    fixture.goQuest = true;
    final router = await mount(tester);
    final go = find.widgetWithText(FilledButton, 'Go');
    final staleGo = tester.widget<FilledButton>(go).onPressed!;
    final create = find.byKey(const Key('community-earn-create-post'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    final staleCreate = tester.widget<TextButton>(create).onPressed!;
    await fixture.roundTrip();
    await tester.pump();
    staleGo();
    staleCreate();
    await tester.pumpAndSettle();
    expect(_changed, findsOneWidget);
    expect(find.text('Composer target'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/community/rewards',
    );
    expect(fixture.count(rewardsClaimRpc), 0);
    expect(fixture.count(rewardsBalanceRpc), 1);
  });

  ownerTest(
    'same account signing out and back in still retires the old visit',
    (tester) async {
      await mount(tester);
      await fixture.client.auth.signOut();
      await fixture.recover(rewardsOwnerA);
      await tester.pumpAndSettle();
      expect(_changed, findsOneWidget);
      expect(_balance, findsNothing);
      expect(fixture.count(rewardsBalanceRpc), 1);
      expect(fixture.count(rewardsClaimRpc), 0);
    },
  );

  ownerTest('a fresh signed-out visit cannot read rewards or expose a claim', (
    tester,
  ) async {
    await fixture.client.auth.signOut();
    await mount(tester);
    expect(find.text('Sign in required'), findsOneWidget);
    expect(_changed, findsNothing);
    expect(_balance, findsNothing);
    expect(_claim, findsNothing);
    expect(fixture.requests, isEmpty);
  });

  ownerTest('same-owner repository replacement requires a fresh page', (
    tester,
  ) async {
    final selected = ValueNotifier<CommunityRepository?>(fixture.repository);
    addTearDown(selected.dispose);
    await mount(tester, selected: selected);
    selected.value = CommunityRepository(fixture.client);
    await tester.pumpAndSettle();
    expect(_changed, findsOneWidget);
    expect(_balance, findsNothing);
    expect(fixture.count(rewardsBalanceRpc), 1);
    expect(fixture.count(rewardsClaimRpc), 0);
  });

  for (final method in [
    rewardsBalanceRpc,
    rewardsHistoryRpc,
    rewardsQuestsRpc,
    rewardsClaimRpc,
  ]) {
    test('repository fences late $method response across A-B-A', () async {
      fixture.holdMethod = method;
      fixture.release = Completer<void>();
      final Future<Object> result = switch (method) {
        rewardsBalanceRpc => fixture.repository.loadGoldBalance(),
        rewardsHistoryRpc => fixture.repository.loadGoldHistory(),
        rewardsQuestsRpc => fixture.repository.loadCommunityQuests(),
        _ => fixture.repository.claimCommunityQuest(
          questKey: 'qa_profile_quest',
          periodKey: 'once',
        ),
      };
      final expectation = expectLater(
        result,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      await fixture.entered.future;
      await fixture.roundTrip();
      fixture.release!.complete();
      await expectation;
      expect(fixture.count(method), 1);
      expect(fixture.requests.single.owner, rewardsOwnerA);
    });
  }
}
