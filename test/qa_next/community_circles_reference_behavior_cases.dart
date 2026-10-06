part of 'community_circles_reference_capture_test.dart';

void _circleBehaviorCases(
  _CircleVisualRepository Function() repositoryForTest,
  SupabaseClient Function() clientForTest,
) {
  _circlesTest(
    'search and membership tabs only filter authoritative loaded rows',
    (tester) async {
      final repository = repositoryForTest();
      await _mountCircles(tester, repository);
      final search = find.byKey(const Key('community-circles-search'));
      await tester.enterText(search, 'running');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-circle-row-running')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-circle-row-strength')),
        findsNothing,
      );
      await _tapCircle(tester, find.byKey(const Key('community-circles-mine')));
      expect(find.text('Requested'), findsOneWidget);
      await tester.enterText(search, 'no loaded match');
      await tester.pumpAndSettle();
      expect(find.text('No circles match your search.'), findsOneWidget);
      await _tapCircle(
        tester,
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Clear search',
        ),
      );
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        find.byKey(const Key('community-circle-row-healthy-eating')),
        findsOneWidget,
      );
      expect(repository.lists, 1);
      expect(repository.joins, 0);
      expect(repository.leaves, 0);
    },
  );

  _circlesTest('returned copy keys select text and unknown keys stay honest', (
    tester,
  ) async {
    final repository = repositoryForTest();
    repository.rows = [
      _circleRecord(
        'healthy-eating',
        titleKey: 'community_circle_running',
        descriptionKey: 'unmapped_description',
        rulesKey: 'unmapped_rules',
      ),
      _circleRecord('strength', titleKey: 'unmapped_title'),
    ];
    await _mountCircles(tester, repository);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Healthy Eating'), findsNothing);
    expect(find.text('strength'), findsOneWidget);
    expect(find.text('Strength'), findsNothing);
    await _tapCircle(
      tester,
      find.byKey(const Key('community-circle-row-healthy-eating')),
    );
    expect(find.text('Description unavailable.'), findsOneWidget);
    expect(find.text('Circle rules are unavailable.'), findsOneWidget);
    expect(repository.feeds, 1);
    expect(repository.metrics, 1);
  });

  _circlesTest('invite and banned rows never pretend to join', (tester) async {
    final repository = repositoryForTest();
    repository.rows = [
      _circleRecord('sleep', policy: CommunityCircleJoinPolicy.invite),
      _circleRecord(
        'running',
        membership: CommunityCircleMembershipStatus.banned,
      ),
    ];
    await _mountCircles(tester, repository);
    expect(find.text('Invitation required'), findsOneWidget);
    expect(find.text('Membership unavailable'), findsOneWidget);
    for (final slug in ['sleep', 'running']) {
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(Key('community-circle-membership-$slug')),
            )
            .onPressed,
        isNull,
      );
    }
    await _tapCircle(tester, find.byKey(const Key('community-circles-mine')));
    expect(find.text('You have not joined a circle yet.'), findsOneWidget);
    expect(repository.joins, 0);
    expect(repository.leaves, 0);
    expect(repository.lists, 1);
  });

  _circlesTest(
    'join disables duplicates and renders server pending readback instead of acknowledgment',
    (tester) async {
      final repository = repositoryForTest();
      repository.rows = [_circleRecord('10k-steps', members: 17)];
      repository.membershipWait = Completer<void>();
      repository.membershipReadback = [
        _circleRecord(
          '10k-steps',
          members: 23,
          membership: CommunityCircleMembershipStatus.pending,
        ),
      ];
      await _mountCircles(tester, repository);
      final target = find.byKey(
        const Key('community-circle-membership-10k-steps'),
      );
      await tester.tap(target);
      await tester.pump();
      expect(repository.joins, 1);
      expect(repository.lists, 1);
      expect(tester.widget<OutlinedButton>(target).onPressed, isNull);
      expect(find.text('Joined'), findsNothing);
      expect(find.text('17 members'), findsOneWidget);
      repository.membershipWait!.complete();
      await tester.pumpAndSettle();
      expect(repository.lists, 2);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('23 members'), findsOneWidget);
      expect(find.text('Joined'), findsNothing);
      expect(repository.joins, 1);
      expect(tester.widget<OutlinedButton>(target).onPressed, isNotNull);
    },
  );

  for (final pending in [false, true]) {
    _circlesTest(
      '${pending ? 'pending cancellation' : 'leaving joined circle'} requires explicit menu intent',
      (tester) async {
        final repository = repositoryForTest();
        repository.rows = [
          _circleRecord(
            'healthy-eating',
            membership: pending
                ? CommunityCircleMembershipStatus.pending
                : CommunityCircleMembershipStatus.active,
          ),
        ];
        repository.membershipReadback = [_circleRecord('healthy-eating')];
        await _mountCircles(tester, repository);
        final membership = find.byKey(
          const Key('community-circle-membership-healthy-eating'),
        );
        await _tapCircle(tester, membership);
        expect(repository.leaves, 0);
        final leave = find.byKey(
          const Key('community-circle-leave-healthy-eating'),
        );
        expect(find.text(pending ? 'Cancel request' : 'Leave'), findsOneWidget);
        Navigator.of(tester.element(leave)).pop();
        await tester.pumpAndSettle();
        expect(repository.leaves, 0);
        await _tapCircle(tester, membership);
        await _tapCircle(tester, leave);
        expect(repository.leaves, 1);
        expect(repository.joins, 0);
        expect(repository.lists, 2);
        expect(find.text('Join'), findsOneWidget);
        await _tapCircle(
          tester,
          find.byKey(const Key('community-circles-mine')),
        );
        expect(find.text('You have not joined a circle yet.'), findsOneWidget);
      },
    );
  }

  _circlesTest(
    'failed membership readback retries the list without duplicate mutation and preserves query',
    (tester) async {
      final repository = repositoryForTest();
      repository.rows = [_circleRecord('10k-steps')];
      repository.membershipReadback = [
        _circleRecord(
          '10k-steps',
          membership: CommunityCircleMembershipStatus.active,
        ),
      ];
      await _mountCircles(tester, repository);
      final search = find.byKey(const Key('community-circles-search'));
      await tester.enterText(search, '10k');
      await tester.pumpAndSettle();
      repository.failList = true;
      await _tapCircle(
        tester,
        find.byKey(const Key('community-circle-membership-10k-steps')),
      );
      expect(repository.joins, 1);
      expect(repository.lists, 2);
      expect(find.byKey(const Key('community-circles-retry')), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(repository.lists, 2);
      expect(repository.joins, 1);
      repository.failList = false;
      await _tapCircle(
        tester,
        find.byKey(const Key('community-circles-retry')),
      );
      expect(repository.lists, 3);
      expect(repository.joins, 1);
      expect(find.text('Joined'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '10k');
      expect(tester.takeException(), isNull);
    },
  );

  _circlesTest('a membership menu cannot act after repository replacement', (
    tester,
  ) async {
    final repository = repositoryForTest();
    final host = await _mountCircles(tester, repository);
    await _tapCircle(
      tester,
      find.byKey(const Key('community-circle-membership-healthy-eating')),
    );
    final oldTap = tester
        .widget<ListTile>(
          find.byKey(const Key('community-circle-leave-healthy-eating')),
        )
        .onTap!;
    final replacement = _CircleVisualRepository(clientForTest());
    host.repository.value = replacement;
    await tester.pumpAndSettle();
    expect(find.text(_circleChanged), findsOneWidget);
    oldTap();
    await tester.pumpAndSettle();
    expect(repository.leaves, 0);
    expect(replacement.leaves, 0);
    expect(replacement.lists, 1);
  });

  _circlesTest(
    'a captured clear button cannot erase a later repository query',
    (tester) async {
      final repository = repositoryForTest();
      final host = await _mountCircles(tester, repository);
      final search = find.byKey(const Key('community-circles-search'));
      await tester.enterText(search, 'old query');
      await tester.pumpAndSettle();
      final oldClear = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Clear search',
            ),
          )
          .onPressed!;
      final replacement = _CircleVisualRepository(clientForTest());
      host.repository.value = replacement;
      await tester.pumpAndSettle();
      await tester.enterText(search, 'strength');
      await tester.pumpAndSettle();
      oldClear();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'strength');
      expect(
        find.byKey(const Key('community-circle-row-strength')),
        findsOneWidget,
      );
      expect(replacement.lists, 1);
    },
  );

  _circlesTest(
    'nested detail and its captured composer close with the parent repository visit',
    (tester) async {
      final repository = repositoryForTest();
      final host = await _mountCircles(tester, repository);
      await _tapCircle(
        tester,
        find.byKey(const Key('community-circle-row-healthy-eating')),
      );
      final oldCompose = tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!;
      final replacement = _CircleVisualRepository(clientForTest());
      host.repository.value = replacement;
      await tester.pumpAndSettle();
      expect(find.text(_circleChanged), findsOneWidget);
      expect(find.text('Approved healthy-eating post 1'), findsNothing);
      oldCompose();
      await tester.pumpAndSettle();
      expect(repository.composed, isEmpty);
      expect(replacement.composed, isEmpty);
      expect(replacement.feeds, 0);
    },
  );

  _circlesTest(
    'Circle composer receives the actual slug only after an explicit action',
    (tester) async {
      final repository = repositoryForTest();
      await _mountCircles(tester, repository);
      await _tapCircle(
        tester,
        find.byKey(const Key('community-circle-row-healthy-eating')),
      );
      expect(repository.composed, isEmpty);
      await _tapCircle(tester, find.byType(FloatingActionButton));
      expect(repository.composed, ['healthy-eating']);
      expect(repository.joins, 0);
      expect(repository.leaves, 0);
      expect(repository.lists, 1);
    },
  );

  _circlesTest(
    'cold Circles return button reaches the real safe dashboard route',
    (tester) async {
      final repository = repositoryForTest();
      final host = await _mountCircles(tester, repository);
      await _tapCircle(tester, find.byKey(const Key('community-safe-return')));
      expect(find.text('Dashboard route boundary'), findsOneWidget);
      expect(host.router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(repository.composed, isEmpty);
    },
  );
}
