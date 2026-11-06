import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_composer_persistence.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/domain/community_comment_threads.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/shared/widgets/bil_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community_profile_auth_session_fixture.dart';
part 'community_profile_card_owner_cases.dart';

void _profileTest(String description, WidgetTesterCallback body) {
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

Future<void> _mount(
  WidgetTester tester,
  _ProfileRepository repository, {
  String userId = _ownerA,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityMemberProfilePage(
        key: const ValueKey('stable-profile-route'),
        userId: userId,
        repository: repository,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _roundTrip(WidgetTester tester, _ProfileAuthFixture auth) async {
  final delivered = <({String? eventOwner, String? currentOwner})>[];
  final observation = auth.client.auth.onAuthStateChange.listen((state) {
    delivered.add((
      eventOwner: state.session?.user.id,
      currentOwner: auth.client.auth.currentUser?.id,
    ));
  });
  // Disposal belongs to the outer runner. A root-zone cancellation Future
  // must not strand the next fake-clock Flutter pump.
  addTearDown(observation.cancel);
  await auth.roundTrip();
  await tester.pump();
  expect(delivered, contains((eventOwner: _ownerB, currentOwner: _ownerA)));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _openDelete(WidgetTester tester) async {
  if (find.byTooltip('List view').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
  }
  expect(find.byTooltip('Grid view'), findsOneWidget);
  final menu = find.byType(PopupMenuButton<String>).first;
  await _tap(tester, menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
  expect(find.text('Delete post?'), findsOneWidget);
}

void main() {
  late _ProfileAuthFixture auth;
  late _ProfileRepository repository;
  setUp(() async {
    auth = _ProfileAuthFixture();
    await auth.signIn(_ownerB);
    await auth.signIn(_ownerA);
    repository = _ProfileRepository(auth.client);
  });
  tearDown(() async {
    await auth.client.dispose();
  });

  _cardOwnerTests(() => auth, () => repository);

  _profileTest('ordinary self-profile reads do not create social intent', (
    tester,
  ) async {
    await _mount(tester, repository);
    expect(find.text('Private A'), findsOneWidget);
    expect(find.byKey(const Key('community-self-drafts')), findsOneWidget);
    expect(repository.count('drafts'), 1);
    expect(repository.follows, 0);
    expect(repository.requests, 0);
    expect(repository.deletes, 0);
    expect(repository.calls.every((call) => call.owner == _ownerA), isTrue);
    expect(tester.takeException(), isNull);
  });

  _profileTest('actual A to B hides self-profile and private quick actions', (
    tester,
  ) async {
    await _mount(tester, repository);
    await auth.recover(_ownerB);
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsNothing);
    expect(find.byKey(const Key('community-self-drafts')), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
  });

  _profileTest('queued actual A B A invalidates the original profile visit', (
    tester,
  ) async {
    await _mount(tester, repository);
    await _roundTrip(tester, auth);
    await tester.pumpAndSettle();
    expect(auth.client.auth.currentUser!.id, _ownerA);
    expect(find.text('Private A'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
  });

  _profileTest('late old core cannot begin creator or private draft reads', (
    tester,
  ) async {
    final pending = Completer<CommunityProfileOverview>();
    repository.pendingOverview = pending;
    await _mount(tester, repository, settle: false);
    expect(repository.count('profile'), 1);
    await _roundTrip(tester, auth);
    pending.complete(_profile(_ownerA));
    await tester.pumpAndSettle();
    expect(repository.count('creator'), 0);
    expect(repository.count('drafts'), 0);
    expect(repository.count('cover'), 0);
    expect(repository.count('rewards'), 0);
    expect(find.text('Private A'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
  });

  _profileTest('target replacement reloads and discards old target result', (
    tester,
  ) async {
    final pending = Completer<CommunityProfileOverview>();
    repository.pendingOverview = pending;
    await _mount(tester, repository, settle: false);
    await _mount(tester, repository, userId: _member, settle: false);
    pending.complete(_profile(_ownerA));
    await tester.pumpAndSettle();
    expect(find.text('Public member'), findsOneWidget);
    expect(find.text('Private A'), findsNothing);
    expect(repository.count('profile'), 2);
    expect(repository.count('drafts'), 0);
    expect(
      repository.calls
          .where((call) => call.method == 'creator')
          .map((call) => call.target),
      [_member],
    );
  });

  _profileTest('repository replacement binds the new repository only', (
    tester,
  ) async {
    final pending = Completer<CommunityProfileOverview>();
    repository.pendingOverview = pending;
    final replacement = _ProfileRepository(auth.client, prefix: 'Replacement ');
    await _mount(tester, repository, settle: false);
    await _mount(tester, replacement, settle: false);
    pending.complete(_profile(_ownerA));
    await tester.pumpAndSettle();
    expect(find.text('Replacement Private A'), findsOneWidget);
    expect(find.text('Private A'), findsNothing);
    expect(repository.count('creator'), 0);
    expect(repository.count('drafts'), 0);
    expect(replacement.count('profile'), 1);
    expect(replacement.count('drafts'), 1);
  });

  for (final action in ['follow', 'friend']) {
    _profileTest('pending $action has no follow-up after actual A B A', (
      tester,
    ) async {
      await _mount(tester, repository, userId: _member);
      final pending = Completer<void>();
      if (action == 'follow') {
        repository.pendingFollow = pending;
      } else {
        repository.pendingFriend = pending;
      }
      await _tap(
        tester,
        action == 'follow'
            ? find.byKey(const Key('community-profile-follow-action'))
            : find.byKey(const Key('community-profile-friend-action')),
      );
      expect(repository.count(action), 1);
      await _roundTrip(tester, auth);
      pending.complete();
      await tester.pumpAndSettle();
      expect(repository.count('profile'), 1);
      expect(repository.count('creator'), 1);
      expect(find.text('Public member'), findsNothing);
      expect(find.text(_changedCopy), findsOneWidget);
    });
  }

  _profileTest('old delete confirmation cannot authorize a new owner', (
    tester,
  ) async {
    await _mount(tester, repository);
    await _openDelete(tester);
    final confirm = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'))
        .onPressed!;
    await _roundTrip(tester, auth);
    // A retained callback is possible when confirmation and auth are queued.
    // It may close the old modal, but must never start a repository mutation.
    if (find.text('Delete post?').evaluate().isNotEmpty) confirm();
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    expect(repository.count('delete'), 0);
    expect(find.text('Private A'), findsNothing);
  });

  _profileTest(
    'confirmed delete refreshes the server count without replacing the header',
    (tester) async {
      final deleting = _DeleteCountRepository(auth.client);
      await _mount(tester, deleting);
      expect(_visiblePostCount(tester), '1');
      final hero = tester.element(
        find.byKey(const Key('community-profile-hero')),
      );
      await _openDelete(tester);
      final pending = Completer<CommunityProfileOverview>();
      deleting.deleteProjection = pending;
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleting.deletes, 1);
      expect(find.text('Private A post'), findsNothing);
      expect(_visiblePostCount(tester), '1');
      expect(
        tester.element(find.byKey(const Key('community-profile-hero'))),
        same(hero),
      );
      pending.complete(_profile(_ownerA, postCount: 0));
      await tester.pumpAndSettle();
      expect(_visiblePostCount(tester), '0');
      expect(find.text('Private A post'), findsNothing);
      expect(
        tester.element(find.byKey(const Key('community-profile-hero'))),
        same(hero),
      );
      expect(deleting.count('profile'), 2);
      expect(tester.takeException(), isNull);
    },
  );

  _profileTest('delete failure keeps the existing post and verified count', (
    tester,
  ) async {
    final deleting = _DeleteCountRepository(auth.client)..failDelete = true;
    await _mount(tester, deleting);
    await _openDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Private A post'), findsOneWidget);
    expect(_visiblePostCount(tester), '1');
    expect(deleting.count('profile'), 1);
    expect(
      find.text('Could not complete that action safely. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  _profileTest(
    'projection failure cannot resurrect a confirmed deleted post or fabricate zero',
    (tester) async {
      final deleting = _DeleteCountRepository(auth.client)
        ..failProjection = true;
      await _mount(tester, deleting);
      await _openDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Private A post'), findsNothing);
      expect(find.text('Private A'), findsOneWidget);
      expect(_visiblePostCount(tester), '1');
      expect(
        find.text('Could not complete that action safely. Try again.'),
        findsOneWidget,
      );
      expect(find.text(_changedCopy), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _profileTest('late post-delete projection is fenced after actual A B A', (
    tester,
  ) async {
    final deleting = _DeleteCountRepository(auth.client);
    await _mount(tester, deleting);
    await _openDelete(tester);
    final pending = Completer<CommunityProfileOverview>();
    deleting.deleteProjection = pending;
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleting.count('profile'), 2);
    await _roundTrip(tester, auth);
    pending.complete(_profile(_ownerA, prefix: 'Retired ', postCount: 0));
    await tester.pumpAndSettle();
    expect(find.text('Retired Private A'), findsNothing);
    expect(find.text('Private A'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
    expect(deleting.deletes, 1);
    expect(tester.takeException(), isNull);
  });

  _profileTest(
    'older whole-profile refresh cannot restore the deleted post or old counter',
    (tester) async {
      final deleting = _DeleteCountRepository(auth.client);
      await _mount(tester, deleting);
      final older = Completer<CommunityProfileOverview>();
      deleting.pendingOverview = older;
      final refresh = tester
          .widget<BilRefreshIndicator>(find.byType(BilRefreshIndicator))
          .onRefresh();
      await tester.pump();
      await _openDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(_visiblePostCount(tester), '0');
      older.complete(_profile(_ownerA, prefix: 'Older ', postCount: 1));
      await refresh;
      await tester.pumpAndSettle();
      expect(_visiblePostCount(tester), '0');
      expect(find.text('Private A post'), findsNothing);
      expect(find.text('Older Private A'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _profileTest('newer profile request fences a late post-delete projection', (
    tester,
  ) async {
    final deleting = _DeleteCountRepository(auth.client);
    await _mount(tester, deleting);
    await _openDelete(tester);
    final pending = Completer<CommunityProfileOverview>();
    deleting.deleteProjection = pending;
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    final refresh = tester
        .widget<BilRefreshIndicator>(find.byType(BilRefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await refresh;
    expect(_visiblePostCount(tester), '0');
    pending.complete(_profile(_ownerA, prefix: 'Retired ', postCount: 1));
    await tester.pumpAndSettle();
    expect(_visiblePostCount(tester), '0');
    expect(find.text('Retired Private A'), findsNothing);
    expect(find.text('Private A post'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _profileTest('loaded connections are hidden after actual A B A', (
    tester,
  ) async {
    await _mount(tester, repository);
    await _tap(tester, find.text('Followers').first);
    await tester.pumpAndSettle();
    expect(find.text('A private connection'), findsOneWidget);
    await _roundTrip(tester, auth);
    await tester.pumpAndSettle();
    expect(find.text('A private connection'), findsNothing);
    expect(
      find.byKey(const Key('community-connection-follow-$_connection')),
      findsNothing,
    );
  });

  _profileTest(
    'late pagination cannot resurrect a deleted post and releases Load more',
    (tester) async {
      final deleting = _DeleteCountRepository(auth.client)..pageable = true;
      await _mount(tester, deleting);
      final oldPage = deleting.initialPage!;
      final pending = Completer<CommunityFeedBatch>();
      deleting.pendingPagination = pending;
      final more = find.byKey(const Key('community-profile-posts-load-more'));
      await tester.scrollUntilVisible(
        more,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pump();
      expect(deleting.count('pagination'), 1);
      // The footer is intentionally still loading. Pump bounded route animation
      // frames rather than waiting for that controlled request to finish.
      final menu = find.byType(PopupMenuButton<String>).first;
      await tester.ensureVisible(menu);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(menu);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete post?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(deleting.deleted, isTrue);
      expect(_visiblePostCount(tester), '0');
      expect(find.text('Private A post'), findsNothing);
      pending.complete(
        CommunityFeedBatch(
          posts: oldPage.posts,
          hasMore: false,
          nextBefore: DateTime.utc(2026, 1, 1),
          nextBeforeId: _postId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private A post'), findsNothing);
      expect(_visiblePostCount(tester), '0');
      // Its old cursor/hasMore=false must not replace the active page. Cleanup
      // belongs to the finished request even though its content was retired.
      expect(more, findsOneWidget);
      expect(tester.widget<TextButton>(more).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  _profileTest('late connections cannot restore an invalidated modal', (
    tester,
  ) async {
    await _mount(tester, repository);
    final pending = Completer<List<CommunityProfileConnection>>();
    repository.pendingConnections = pending;
    await _tap(tester, find.text('Followers').first);
    expect(repository.count('connections'), 1);
    await _roundTrip(tester, auth);
    pending.complete(repository.connectionRows);
    await tester.pumpAndSettle();
    expect(find.text('A private connection'), findsNothing);
    expect(repository.follows, 0);
    expect(tester.takeException(), isNull);
  });

  _profileTest('same-owner session recovery preserves the active profile', (
    tester,
  ) async {
    await _mount(tester, repository);
    await auth.recover(_ownerA);
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsOneWidget);
    expect(find.text(_changedCopy), findsNothing);
    expect(repository.count('profile'), 1);
  });

  _profileTest('sign out clears the profile before old controls can act', (
    tester,
  ) async {
    await _mount(tester, repository);
    await auth.client.auth.signOut(scope: SignOutScope.local);
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsNothing);
    expect(find.text(_changedCopy), findsOneWidget);
    expect(repository.follows, 0);
    expect(repository.requests, 0);
  });
}

String _visiblePostCount(WidgetTester tester) {
  final label = find.descendant(
    of: find.byKey(const Key('community-profile-hero')),
    matching: find.text('Posts'),
  );
  Element? metric;
  tester.element(label).visitAncestorElements((ancestor) {
    if (ancestor.widget is Column) {
      metric = ancestor;
      return false;
    }
    return true;
  });
  return ((metric!.widget as Column).children.first as Text).data!;
}

class _DeleteCountRepository extends _ProfileRepository {
  _DeleteCountRepository(super.client);

  bool deleted = false;
  bool failDelete = false;
  bool failProjection = false;
  Completer<CommunityProfileOverview>? deleteProjection;
  bool pageable = false;
  CommunityFeedBatch? initialPage;
  Completer<CommunityFeedBatch>? pendingPagination;

  @override
  Future<void> deletePost(String postId) async {
    record('delete', postId);
    deletes++;
    if (failDelete) throw StateError('Synthetic delete rejection');
    deleted = true;
  }

  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    if (!deleted) return super.loadProfileOverview(userId);
    record('profile', userId);
    final pending = deleteProjection;
    deleteProjection = null;
    if (pending != null) return pending.future;
    if (failProjection) {
      throw StateError('Synthetic post-delete projection outage');
    }
    return _profile(userId, postCount: 0);
  }

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (before != null && pendingPagination != null) {
      record('pagination', userId);
      final pending = pendingPagination!;
      pendingPagination = null;
      return pending.future;
    }
    if (!deleted) {
      final batch = await super.loadProfilePosts(
        userId: userId,
        before: before,
        beforeId: beforeId,
        limit: limit,
      );
      if (!pageable) return batch;
      return initialPage = CommunityFeedBatch(
        posts: batch.posts,
        hasMore: true,
        nextBefore: DateTime.utc(2026, 10, 3, 12),
        nextBeforeId: _postId,
      );
    }
    record('posts', userId);
    return CommunityFeedBatch(posts: const [], hasMore: false);
  }
}
