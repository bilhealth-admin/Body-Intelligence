import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_comment_threads.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_topics_auth_session_fixture.dart';

void _topicsTest(String description, WidgetTesterCallback body) {
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
  late _TopicAuthFixture auth;
  late _TopicRepository repository;
  setUp(() async {
    auth = _TopicAuthFixture();
    await auth.recover(_ownerA);
    repository = _TopicRepository(auth.client);
  });
  tearDown(() async => auth.client.dispose());

  for (final taxonomy in [false, true]) {
    for (final returnToA in [false, true]) {
      final transition = returnToA ? 'A B A' : 'A B';
      final origin = taxonomy ? 'taxonomy' : 'feed';
      _topicsTest(
        'actual $origin topic entry retires independently after $transition',
        (tester) async {
          auth.responseFeatured = true;
          repository.includeFeedPost = taxonomy;
          await _mountHub(tester, repository);
          expect(tester.takeException(), isNull);
          final baselineCounts = repository.count('counts');
          final pending = Completer<CommunityTopicPostBatch>();
          repository.pendingPage = pending;
          final control = taxonomy
              ? find.descendant(
                  of: find.byKey(const ValueKey(_postId)),
                  matching: find.text('Success Stories'),
                )
              : find.byKey(const Key('community-feed-topic-$_slug'));
          await tester.ensureVisible(control);
          await tester.tap(control);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(repository.count('first'), 1);
          expect(repository.calls.last.owner, _ownerA);
          await _changeOwner(tester, auth, returnToA: returnToA);
          pending.complete(repository.page());
          await tester.pumpAndSettle();
          expect(find.text('$_slug first post'), findsNothing);
          expect(find.text(_changedCopy), findsOneWidget);
          expect(repository.count('counts'), baselineCounts);
          expect(auth.count('bil_follow_community_topic_v1'), 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _topicsTest('opening topics reads the real SDK list without following', (
    tester,
  ) async {
    await _mountTopics(tester, repository);
    expect(find.text('Success Stories'), findsOneWidget);
    expect(auth.count('bil_list_community_topics_v1'), 1);
    expect(auth.count('bil_follow_community_topic_v1'), 0);
    expect(tester.takeException(), isNull);
  });

  _topicsTest(
    'topic Follow paints busy and sends only one authenticated request',
    (tester) async {
      final pending = Completer<void>();
      auth.pendingFollow = pending;
      await _mountTopics(tester, repository);
      final action = tester.widget<ButtonStyleButton>(_followButton).onPressed!;
      try {
        action();
        action();
        await tester.pump();
        expect(
          tester.widget<ButtonStyleButton>(_followButton).onPressed,
          isNull,
        );
        expect(auth.count('bil_follow_community_topic_v1'), 1);
        expect(auth.requests.last.owner, _ownerA);
      } finally {
        pending.complete();
        await tester.pumpAndSettle();
      }
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('18 followers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final returnToA in [false, true]) {
    final transition = returnToA ? 'A B A' : 'A B';

    _topicsTest('pending list cannot render after actual $transition', (
      tester,
    ) async {
      final pending = Completer<void>();
      auth.pendingList = pending;
      auth.responseSlug = 'old-topic-a';
      await _mountTopics(tester, repository, settle: false);
      await tester.pump();
      await _changeOwner(tester, auth, returnToA: returnToA);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('old-topic-a'), findsNothing);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(auth.count('bil_list_community_topics_v1'), 1);
      expect(auth.count('bil_follow_community_topic_v1'), 0);
      expect(tester.takeException(), isNull);
    });

    _topicsTest('captured Follow cannot send after actual $transition', (
      tester,
    ) async {
      await _mountTopics(tester, repository);
      final oldAction = tester
          .widget<ButtonStyleButton>(_followButton)
          .onPressed!;
      await _changeOwner(tester, auth, returnToA: returnToA);
      oldAction();
      await tester.pumpAndSettle();
      expect(auth.count('bil_follow_community_topic_v1'), 0);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    _topicsTest(
      'in-flight Follow cannot restore state after actual $transition',
      (tester) async {
        final pending = Completer<void>();
        auth.pendingFollow = pending;
        await _mountTopics(tester, repository);
        await tester.tap(_followButton);
        await tester.pump();
        await _changeOwner(tester, auth, returnToA: returnToA);
        pending.complete();
        await tester.pumpAndSettle();
        expect(auth.count('bil_follow_community_topic_v1'), 1);
        expect(auth.requests.last.owner, _ownerA);
        expect(find.text('Following'), findsNothing);
        expect(find.text('18 followers'), findsNothing);
        expect(find.text(_changedCopy), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final boundary in ['posts', 'counts']) {
      _topicsTest(
        'pending topic $boundary cannot continue after actual $transition',
        (tester) async {
          final page = Completer<CommunityTopicPostBatch>();
          final counts = Completer<Map<String, int>>();
          await _mountTopics(tester, repository);
          if (boundary == 'posts') {
            repository.pendingPage = page;
          } else {
            repository.pendingCounts = counts;
          }
          await _openTopic(tester, settle: false);
          await _changeOwner(tester, auth, returnToA: returnToA);
          if (boundary == 'posts') {
            page.complete(repository.page());
          } else {
            counts.complete({_postId: 37});
          }
          await tester.pumpAndSettle();
          expect(find.text('$_slug first post'), findsNothing);
          expect(
            find.byKey(const Key('community-profile-post-views-$_postId')),
            findsNothing,
          );
          expect(repository.count('counts'), boundary == 'posts' ? 0 : 1);
          expect(find.text(_changedCopy), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    _topicsTest('cached topic post cannot open after actual $transition', (
      tester,
    ) async {
      await _mountTopics(tester, repository);
      await _openTopic(tester);
      final oldAction = tester.widget<InkWell>(_postTile).onTap!;
      await _changeOwner(tester, auth, returnToA: returnToA);
      oldAction();
      await tester.pumpAndSettle();
      expect(repository.detailLoads, 0);
      expect(find.text('$_slug first post'), findsNothing);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final detail in [false, true]) {
      _topicsTest(
        'captured ${detail ? 'detail' : 'list'} composer cannot enter after actual $transition',
        (tester) async {
          final intents = <String>[];
          await _mountTopics(
            tester,
            repository,
            onCompose: (slug) async {
              intents.add('${repository.currentUserId}:$slug');
            },
          );
          VoidCallback oldAction;
          if (detail) {
            await _openTopic(tester);
            oldAction = tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .onPressed!;
          } else {
            oldAction = tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Start a post',
                  ),
                )
                .onPressed!;
          }
          await _changeOwner(tester, auth, returnToA: returnToA);
          oldAction();
          await tester.pumpAndSettle();
          expect(intents, isEmpty);
          expect(auth.count('bil_follow_community_topic_v1'), 0);
          expect(find.text(_changedCopy), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _topicsTest('older topic page cannot start metrics after actual ABA', (
    tester,
  ) async {
    repository.hasMore = true;
    await _mountTopics(tester, repository);
    await _openTopic(tester);
    final pending = Completer<CommunityTopicPostBatch>();
    repository.pendingPage = pending;
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Load more'));
    await tester.tap(find.widgetWithText(TextButton, 'Load more'));
    await tester.pump();
    await _changeOwner(tester, auth, returnToA: true);
    pending.complete(repository.page(older: true));
    await tester.pumpAndSettle();
    expect(repository.count('counts'), 1);
    expect(find.text('$_slug older post'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _topicsTest('list replacement rejects its old result and refresh callback', (
    tester,
  ) async {
    final pending = Completer<void>();
    auth.pendingList = pending;
    auth.responseSlug = 'retired-topic-a';
    await _mountTopics(tester, repository, settle: false);
    await tester.pump();
    final oldRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    auth.responseSlug = 'nutrition';
    final replacement = _TopicRepository(auth.client);
    await _mountTopics(tester, replacement, settle: false);
    pending.complete();
    await tester.pumpAndSettle();
    await oldRefresh();
    await tester.pumpAndSettle();
    expect(find.text('retired-topic-a'), findsNothing);
    expect(find.text('Food and Nutrition'), findsOneWidget);
    expect(auth.count('bil_list_community_topics_v1'), 2);
    expect(tester.takeException(), isNull);
  });

  for (final detail in [false, true]) {
    _topicsTest(
      '${detail ? 'detail' : 'list'} refresh does not return a Future from setState',
      (tester) async {
        await _mountTopics(tester, repository);
        if (detail) await _openTopic(tester);
        final refreshing = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await tester.pumpAndSettle();
        await refreshing;
        expect(tester.takeException(), isNull);
        expect(
          detail
              ? repository.count('first')
              : auth.count('bil_list_community_topics_v1'),
          2,
        );
      },
    );
  }

  _topicsTest(
    'composer continuation retains its original owner transport fence',
    (tester) async {
      final pending = Completer<void>();
      var entered = 0;
      await _mountTopics(
        tester,
        repository,
        onCompose: (slug) async {
          entered++;
          await pending.future;
          await repository.followCommunityTopic(slug: slug, follow: true);
        },
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Start a post',
        ),
      );
      await tester.pump();
      expect(entered, 1);
      await _changeOwner(tester, auth, returnToA: true);
      pending.complete();
      await tester.pumpAndSettle();
      expect(auth.count('bil_follow_community_topic_v1'), 0);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _topicsTest('SDK token refresh cannot forward topic Follow after ABA', (
    tester,
  ) async {
    await _mountTopics(tester, repository);
    await auth.client.auth.setInitialSession(
      jsonEncode(_session(_ownerA, expired: true)),
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    auth.refreshEntered = entered;
    auth.pendingRefresh = release;
    try {
      await tester.tap(_followButton);
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      await _changeOwner(tester, auth, returnToA: true);
    } finally {
      release.complete();
      await tester.pumpAndSettle();
    }
    expect(auth.count('bil_follow_community_topic_v1'), 0);
    expect(find.text(_changedCopy), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _topicsTest(
    'opened post detail retires cached text on actual account switch',
    (tester) async {
      await _mountTopics(tester, repository);
      await _openTopic(tester);
      await tester.tap(_postTile);
      await tester.pumpAndSettle();
      expect(repository.detailLoads, 1);
      expect(find.text('$_slug first post'), findsOneWidget);
      await _changeOwner(tester, auth, returnToA: false);
      await tester.pumpAndSettle();
      expect(find.text('$_slug first post'), findsNothing);
      expect(find.text(_changedCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _topicsTest('route exit prevents pending topic metrics and repaint', (
    tester,
  ) async {
    await _mountTopics(tester, repository);
    final pending = Completer<CommunityTopicPostBatch>();
    repository.pendingPage = pending;
    await _openTopic(tester, settle: false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Outside topics'))),
    );
    pending.complete(repository.page());
    await tester.pumpAndSettle();
    expect(repository.count('counts'), 0);
    expect(find.text('Outside topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _topicsTest(
    'Follow failure preserves prior state and supports genuine retry',
    (tester) async {
      await _mountTopics(tester, repository);
      auth.failFollow = true;
      await tester.tap(_followButton);
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsNothing);
      expect(find.text('17 followers'), findsOneWidget);
      expect(
        find.text('Could not update this topic. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ButtonStyleButton>(_followButton).onPressed,
        isNotNull,
      );
      auth.failFollow = false;
      await tester.tap(_followButton);
      await tester.pumpAndSettle();
      expect(auth.count('bil_follow_community_topic_v1'), 2);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('18 followers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  _topicsTest(
    'unauthenticated topics retain the existing honest server retry',
    (tester) async {
      await auth.client.auth.signOut(scope: SignOutScope.local);
      await _mountTopics(tester, repository);
      expect(auth.count('bil_list_community_topics_v1'), 1);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text(_changedCopy), findsNothing);
      expect(find.text('Premium'), findsNothing);
      expect(auth.count('bil_follow_community_topic_v1'), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
