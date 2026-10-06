import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_circles_auth_session_fixture.dart';

void _circleTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

void main() {
  late _CircleAuthFixture auth;
  late _CircleRepository repository;
  setUp(() async {
    auth = _CircleAuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _CircleRepository(auth.client);
  });
  tearDown(() async => auth.client.dispose());

  _circleTest('opening circles does not create membership or posting intent', (
    tester,
  ) async {
    await _mountList(tester, repository);
    expect(find.text('Healthy Eating'), findsOneWidget);
    expect(repository.count('list'), 1);
    expect(auth.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final returnToA in [false, true]) {
    final transition = returnToA ? 'A B A' : 'A B';
    _circleTest('pending list cannot render after actual $transition', (
      tester,
    ) async {
      final pending = Completer<List<CommunityCircle>>();
      repository.pendingList = pending;
      await _mountList(tester, repository, settle: false);
      await _changeOwner(tester, auth, returnToA);
      pending.complete([_circle('old-circle-a')]);
      await tester.pumpAndSettle();
      expect(find.text('old-circle-a'), findsNothing);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(repository.count('list'), 1);
      expect(auth.requests, isEmpty);
    });

    for (final boundary in ['posts', 'counts']) {
      _circleTest(
        'pending $boundary cannot continue after actual $transition',
        (tester) async {
          final page = Completer<CommunityCirclePostBatch>();
          final counts = Completer<Map<String, int>>();
          if (boundary == 'posts') {
            repository.pendingPage = page;
          } else {
            repository.pendingCounts = counts;
          }
          await _mountCircle(tester, repository, settle: false);
          await tester.pump();
          await _changeOwner(tester, auth, returnToA);
          if (boundary == 'posts') {
            page.complete(repository.page('healthy-eating'));
          } else {
            counts.complete({_postId: 37});
          }
          await tester.pumpAndSettle();
          expect(find.text('healthy-eating first post'), findsNothing);
          expect(find.text(_changedCopy), findsOneWidget);
          expect(repository.count('counts'), boundary == 'posts' ? 0 : 1);
          expect(auth.requests, isEmpty);
        },
      );
    }

    for (final leaving in [false, true]) {
      _circleTest(
        'in-flight ${leaving ? 'leave' : 'join'} starts no refresh after actual $transition',
        (tester) async {
          repository.circles = [
            _circle(
              'healthy-eating',
              membership: leaving
                  ? CommunityCircleMembershipStatus.active
                  : null,
            ),
          ];
          final pending = Completer<void>();
          auth.pendingMembership = pending;
          await _mountList(tester, repository);
          await tester.tap(
            find.byKey(const Key('community-circle-membership-healthy-eating')),
          );
          if (leaving) {
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const Key('community-circle-leave-healthy-eating')),
            );
          }
          await tester.pump();
          await _changeOwner(tester, auth, returnToA);
          pending.complete();
          await tester.pumpAndSettle();
          expect(auth.requests, [
            (
              method: leaving
                  ? 'bil_leave_community_circle_v1'
                  : 'bil_join_community_circle_v1',
              owner: _ownerA,
              slug: 'healthy-eating',
            ),
          ]);
          expect(repository.count('list'), 1);
          expect(find.text(_changedCopy), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _circleTest('list repository replacement owns its first result', (
    tester,
  ) async {
    final pending = Completer<List<CommunityCircle>>();
    repository.pendingList = pending;
    await _mountList(tester, repository, settle: false);
    final replacement = _CircleRepository(auth.client)
      ..circles = [_circle('strength')];
    await _mountList(tester, replacement, settle: false);
    pending.complete([_circle('old-circle-a')]);
    await tester.pumpAndSettle();
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('old-circle-a'), findsNothing);
    expect(replacement.count('list'), 1);
    expect(repository.count('list'), 1);
  });

  _circleTest('detail repository replacement cancels old optional metrics', (
    tester,
  ) async {
    final pending = Completer<CommunityCirclePostBatch>();
    repository.pendingPage = pending;
    await _mountCircle(tester, repository, settle: false);
    final replacement = _CircleRepository(auth.client, prefix: 'New ');
    await _mountCircle(tester, replacement, settle: false);
    pending.complete(repository.page('healthy-eating'));
    await tester.pumpAndSettle();
    expect(find.text('New healthy-eating first post'), findsOneWidget);
    expect(find.text('healthy-eating first post'), findsNothing);
    expect(repository.count('counts'), 0);
    expect(replacement.count('counts'), 1);
  });

  _circleTest('detail circle replacement keeps the new target and cursor', (
    tester,
  ) async {
    final pending = Completer<CommunityCirclePostBatch>();
    repository.pendingPage = pending;
    await _mountCircle(tester, repository, settle: false);
    await _mountCircle(tester, repository, slug: 'sleep', settle: false);
    pending.complete(repository.page('healthy-eating'));
    await tester.pumpAndSettle();
    expect(find.text('sleep first post'), findsOneWidget);
    expect(find.text('healthy-eating first post'), findsNothing);
    expect(
      repository.calls
          .where((call) => call.method == 'first')
          .map((call) => call.target),
      ['healthy-eating', 'sleep'],
    );
    expect(repository.count('counts'), 1);
  });

  _circleTest('older circle page cannot start metrics after actual ABA', (
    tester,
  ) async {
    repository.hasMore = true;
    await _mountCircle(tester, repository);
    final pending = Completer<CommunityCirclePostBatch>();
    repository.pendingPage = pending;
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Load more'));
    await tester.tap(find.widgetWithText(TextButton, 'Load more'));
    await tester.pump();
    await _roundTrip(tester, auth);
    pending.complete(repository.page('healthy-eating', older: true));
    await tester.pumpAndSettle();
    expect(repository.count('counts'), 1);
    expect(find.text('healthy-eating older post'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  _circleTest('membership busy state paints before the real request returns', (
    tester,
  ) async {
    final pending = Completer<void>();
    auth.pendingMembership = pending;
    await _mountList(tester, repository);
    final button = find.byKey(
      const Key('community-circle-membership-healthy-eating'),
    );
    try {
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
      expect(auth.requests, hasLength(1));
    } finally {
      pending.complete();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  _circleTest('list refresh does not return a Future from setState', (
    tester,
  ) async {
    await _mountList(tester, repository);
    final refreshing = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refreshing;
    expect(tester.takeException(), isNull);
    expect(repository.count('list'), 2);
  });

  _circleTest('captured list composer action cannot start for a new account', (
    tester,
  ) async {
    repository.circles = [
      _circle(
        'healthy-eating',
        membership: CommunityCircleMembershipStatus.active,
      ),
    ];
    final intents = <String>[];
    await _mountList(
      tester,
      repository,
      onCompose: (slug) async {
        intents.add('${repository.currentUserId}:$slug');
      },
    );
    final oldAction = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Post in circle',
          ),
        )
        .onPressed!;
    await auth.recover(_ownerB);
    await tester.pumpAndSettle();
    oldAction();
    await tester.pumpAndSettle();
    expect(intents, isEmpty);
    expect(auth.requests, isEmpty);
  });

  _circleTest('captured detail composer action cannot switch circle silently', (
    tester,
  ) async {
    final intents = <String>[];
    Future<void> compose(String slug) async => intents.add(slug);
    await _mountCircle(tester, repository, onCompose: compose);
    final oldAction = tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .onPressed!;
    await _mountCircle(tester, repository, slug: 'sleep', onCompose: compose);
    oldAction();
    await tester.pumpAndSettle();
    expect(intents, isEmpty);
  });

  _circleTest(
    'composer continuation retains the circle owner transport fence',
    (tester) async {
      final pending = Completer<void>();
      var entered = 0;
      await _mountCircle(
        tester,
        repository,
        onCompose: (slug) async {
          entered++;
          await pending.future;
          await repository.joinCommunityCircle(slug);
        },
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(entered, 1);
      await _roundTrip(tester, auth);
      pending.complete();
      await tester.pumpAndSettle();
      expect(auth.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  _circleTest('route exit cancels late circle counts and membership refresh', (
    tester,
  ) async {
    final pending = Completer<CommunityCirclePostBatch>();
    repository.pendingPage = pending;
    await _mountCircle(tester, repository, settle: false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Outside circles'))),
    );
    pending.complete(repository.page('healthy-eating'));
    await tester.pumpAndSettle();
    expect(repository.count('counts'), 0);
    expect(find.text('Outside circles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final detail in [false, true]) {
    _circleTest(
      'captured ${detail ? 'detail' : 'list'} refresh cannot restart after repository replacement',
      (tester) async {
        if (detail) {
          await _mountCircle(tester, repository);
        } else {
          await _mountList(tester, repository);
        }
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh;
        final replacement = _CircleRepository(auth.client);
        if (detail) {
          await _mountCircle(tester, replacement);
        } else {
          await _mountList(tester, replacement);
        }
        await refresh();
        await tester.pumpAndSettle();
        expect(repository.count(detail ? 'first' : 'list'), 1);
        expect(replacement.count(detail ? 'first' : 'list'), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
