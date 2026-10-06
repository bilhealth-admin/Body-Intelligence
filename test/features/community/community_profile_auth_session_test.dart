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
  await tester.tap(find.byTooltip('List view'));
  await tester.pumpAndSettle();
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
            : find.widgetWithText(FilledButton, 'Add Friend'),
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
