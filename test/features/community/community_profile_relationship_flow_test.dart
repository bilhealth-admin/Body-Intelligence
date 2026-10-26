import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _member = '22222222-2222-4222-8222-222222222222';
const _friendship = '33333333-3333-4333-8333-333333333333';
late SupabaseClient _client;

CommunityCreatorProfile _creatorData({int level = 1, int followers = 0}) =>
    CommunityCreatorProfile(
      userId: _member,
      contributor: false,
      approvedPosts: 0,
      followers: followers,
      likesReceived: 0,
      commentsReceived: 0,
      qualifiedReferrals: 0,
      communityXp: level == 1 ? 0 : 9000,
      communityLevel: level,
      currentLevelMinXp: level == 1 ? 0 : 9000,
      earnedBadgeCount: 0,
      totalBadgeCount: 0,
      badges: const [],
      certificationStatus: CommunityCreatorCertificationStatus.notCertified,
    );

class _RelationshipsRepository extends CommunityRepository {
  _RelationshipsRepository() : super(_client);

  String owner = _owner;
  bool self = false;
  bool allowFollow = true;
  bool allowFriend = true;
  bool following = false;
  bool failFollow = false;
  bool failFriend = false;
  bool failOverview = false;
  bool failCreator = false;
  Completer<void>? holdFollow;
  Completer<void>? holdFriend;
  Completer<CommunityCreatorProfile>? holdCreator;
  CommunityRelationshipStatus relationship = CommunityRelationshipStatus.none;
  int follows = 0, unfollows = 0, requests = 0, cancellations = 0;
  int accepts = 0, rejects = 0, removals = 0, overviewReads = 0;
  int connectionReads = 0;
  final calls = <String>[];
  List<Map<String, dynamic>>? connectionRows;

  @override
  String get currentUserId => owner;
  @override
  bool get useServerCommunityReferenceParity => false;
  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    overviewReads++;
    calls.add('overview');
    if (failOverview) throw StateError('Synthetic overview offline');
    return CommunityProfileOverview(
      userId: self ? _owner : _member,
      displayName: self ? 'My profile' : 'Other member',
      isSelf: self,
      relationship: relationship,
      allowFriendRequests: allowFriend,
      allowFollows: allowFollow,
      showFollowers: true,
      showFollowing: true,
      showFriends: true,
      showPosts: true,
      showMembershipTier: false,
      followerCount: self ? 0 : (following ? 1 : 0),
      followingCount: self && following ? 1 : 0,
      friendCount: relationship == CommunityRelationshipStatus.accepted ? 1 : 0,
      postCount: 0,
      viewerFollows: following,
      followsViewer: false,
    );
  }

  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => const CommunityFeedBatch(posts: [], hasMore: false);

  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(String id) async {
    calls.add('creator');
    final held = holdCreator;
    if (held != null) return await held.future;
    if (failCreator) throw StateError('Synthetic optional creator offline');
    return _creatorData(followers: following ? 1 : 0);
  }

  @override
  Future<void> follow(String id) async {
    follows++;
    calls.add('follow');
    await holdFollow?.future;
    if (failFollow) throw StateError('Synthetic mutation offline');
    following = true;
  }

  @override
  Future<void> unfollow(String id) async {
    unfollows++;
    calls.add('unfollow');
    if (failFollow) throw StateError('Synthetic mutation offline');
    following = false;
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String id) async {
    requests++;
    await holdFriend?.future;
    if (failFriend) throw StateError('Synthetic friendship offline');
    relationship = CommunityRelationshipStatus.pending;
    return CommunityFriendRequestStatus.pending;
  }

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    connectionReads++;
    return connectionRows ??
        [
          if (relationship != CommunityRelationshipStatus.none)
            {
              'id': _friendship,
              'other_user_id': _member,
              'requester_id':
                  relationship == CommunityRelationshipStatus.incoming
                  ? _member
                  : _owner,
              'addressee_id':
                  relationship == CommunityRelationshipStatus.incoming
                  ? _owner
                  : _member,
              'status': relationship == CommunityRelationshipStatus.accepted
                  ? 'accepted'
                  : 'pending',
              'profile': {'display_name': 'Other member', 'avatar_url': null},
            },
        ];
  }

  @override
  Future<List<CommunityProfileConnection>> loadProfileConnections({
    required String userId,
    required CommunityProfileConnectionKind kind,
    DateTime? before,
    String? beforeUserId,
    int limit = 30,
  }) async => [
    CommunityProfileConnection(
      userId: _member,
      displayName: 'Other member',
      relationship: CommunityRelationshipStatus.none,
      connectedAt: DateTime.utc(2026, 10, 1),
      viewerFollows: following,
      allowFollows: allowFollow,
    ),
  ];

  @override
  Future<void> cancelFriendRequest(String id) async {
    expect(id, _friendship);
    cancellations++;
    if (failFriend) throw StateError('Synthetic cancellation offline');
    relationship = CommunityRelationshipStatus.none;
  }

  @override
  Future<void> respondToFriendship(String id, {required bool accept}) async {
    expect(id, _friendship);
    if (accept) {
      accepts++;
    } else {
      rejects++;
    }
    if (failFriend) throw StateError('Synthetic response offline');
    relationship = accept
        ? CommunityRelationshipStatus.accepted
        : CommunityRelationshipStatus.none;
  }

  @override
  Future<void> removeFriendship(String id) async {
    expect(id, _friendship);
    removals++;
    if (failFriend) throw StateError('Synthetic removal offline');
    relationship = CommunityRelationshipStatus.none;
  }
}

final _follow = find.byKey(const Key('community-profile-follow-action'));
final _friend = find.byKey(const Key('community-profile-friend-action'));

Future<void> _mount(
  WidgetTester tester,
  _RelationshipsRepository repo, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: CommunityMemberProfilePage(
        userId: repo.self ? _owner : _member,
        repository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectFollowers(String count) {
  final metric = find
      .ancestor(of: find.text('Followers'), matching: find.byType(InkWell))
      .first;
  expect(
    find.descendant(of: metric, matching: find.text(count)),
    findsOneWidget,
  );
}

void main() {
  setUp(() {
    _client = SupabaseClient(
      'https://relationships.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => _client.dispose());
  testWidgets(
    'one profile button follows and unfollows using server readback',
    (tester) async {
      final repo = _RelationshipsRepository();
      await _mount(tester, repo);
      _expectFollowers('0');
      await _tap(tester, _follow);
      expect(repo.follows, 1);
      expect(
        find.descendant(of: _follow, matching: find.text('Unfollow')),
        findsOneWidget,
      );
      expect(
        repo.calls.indexOf('overview', 1),
        greaterThan(repo.calls.indexOf('follow')),
      );
      _expectFollowers('1');
      await _tap(tester, _follow);
      expect(repo.unfollows, 1);
      expect(
        find.descendant(of: _follow, matching: find.text('Follow')),
        findsOneWidget,
      );
      expect(repo.relationship, CommunityRelationshipStatus.none);
      expect(repo.requests, 0);
      _expectFollowers('0');
    },
  );

  testWidgets('optional creator failure cannot hide verified follow success', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()..failCreator = true;
    await _mount(tester, repo);
    await _tap(tester, _follow);
    expect(repo.follows, 1);
    expect(
      find.descendant(of: _follow, matching: find.text('Unfollow')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    await _tap(tester, _follow);
    expect(repo.unfollows, 1);
  });

  testWidgets(
    'held creator cannot disable Unfollow or overwrite its later metadata',
    (tester) async {
      final repo = _RelationshipsRepository();
      await _mount(tester, repo);
      final held = Completer<CommunityCreatorProfile>();
      repo.holdCreator = held;
      try {
        await Scrollable.ensureVisible(tester.element(_follow), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(_follow);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repo.follows, 1);
        expect(repo.overviewReads, 2);
        expect(repo.calls.where((call) => call == 'creator').length, 1);
        expect(held.isCompleted, isFalse);
        expect(tester.widget<OutlinedButton>(_follow).onPressed, isNotNull);
        expect(
          find.descendant(of: _follow, matching: find.text('Unfollow')),
          findsOneWidget,
        );
        _expectFollowers('1');

        repo.holdCreator = null;
        await tester.tap(_follow);
        await tester.pumpAndSettle();
        expect(repo.unfollows, 1);
        _expectFollowers('0');
        held.complete(_creatorData(level: 9, followers: 1));
        await tester.pumpAndSettle();
        final panel = find.byKey(const Key('community-creator-panel'));
        expect(
          find.descendant(of: panel, matching: find.text('Lv 1')),
          findsOneWidget,
        );
        expect(find.text('Lv 9'), findsNothing);
        expect(
          find.descendant(of: _follow, matching: find.text('Follow')),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        if (!held.isCompleted) {
          held.complete(_creatorData(level: 9, followers: 1));
        }
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'held creator from an old owner cannot replace a new owners follow metadata',
    (tester) async {
      final old = _RelationshipsRepository();
      await _mount(tester, old);
      final held = Completer<CommunityCreatorProfile>();
      old.holdCreator = held;
      try {
        await Scrollable.ensureVisible(tester.element(_follow), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(_follow);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.widget<OutlinedButton>(_follow).onPressed, isNotNull);
        expect(old.overviewReads, 2);
        final next = _RelationshipsRepository()
          ..owner = '44444444-4444-4444-8444-444444444444';
        await _mount(tester, next);
        await _tap(tester, _follow);
        expect(next.follows, 1);
        expect(next.overviewReads, 2);
        held.complete(_creatorData(level: 9, followers: 1));
        await tester.pumpAndSettle();
        final panel = find.byKey(const Key('community-creator-panel'));
        expect(
          find.descendant(of: panel, matching: find.text('Lv 1')),
          findsOneWidget,
        );
        expect(find.text('Lv 9'), findsNothing);
        expect(
          find.descendant(of: _follow, matching: find.text('Unfollow')),
          findsOneWidget,
        );
        expect(old.overviewReads, 2);
        _expectFollowers('1');
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        if (!held.isCompleted) {
          held.complete(_creatorData(level: 9, followers: 1));
        }
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('held creator error remains optional after verified follow', (
    tester,
  ) async {
    final repo = _RelationshipsRepository();
    await _mount(tester, repo);
    final held = Completer<CommunityCreatorProfile>();
    repo.holdCreator = held;
    try {
      await Scrollable.ensureVisible(tester.element(_follow), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(_follow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.overviewReads, 2);
      expect(tester.widget<OutlinedButton>(_follow).onPressed, isNotNull);
      held.completeError(StateError('Synthetic late creator failure'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _follow, matching: find.text('Unfollow')),
        findsOneWidget,
      );
      _expectFollowers('1');
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      repo.holdCreator = null;
      await _tap(tester, _follow);
      expect(repo.unfollows, 1);
      _expectFollowers('0');
    } finally {
      if (!held.isCompleted) held.complete(_creatorData());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'pending mutation disables repeated follow and preserves readback',
    (tester) async {
      final repo = _RelationshipsRepository()..holdFollow = Completer<void>();
      await _mount(tester, repo);
      await Scrollable.ensureVisible(tester.element(_follow), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(_follow);
      await tester.pump();
      await tester.tap(_follow);
      await tester.pump();
      expect(repo.follows, 1);
      expect(repo.overviewReads, 1);
      repo.holdFollow!.complete();
      await tester.pumpAndSettle();
      expect(repo.overviewReads, 2);
      expect(
        find.descendant(of: _follow, matching: find.text('Unfollow')),
        findsOneWidget,
      );
    },
  );

  testWidgets('offline failure preserves Follow and permits retry', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()..failFollow = true;
    await _mount(tester, repo);
    await _tap(tester, _follow);
    expect(
      find.descendant(of: _follow, matching: find.text('Follow')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    repo.failFollow = false;
    await _tap(tester, _follow);
    expect(repo.follows, 2);
    expect(
      find.descendant(of: _follow, matching: find.text('Unfollow')),
      findsOneWidget,
    );
  });

  testWidgets('Add Friend becomes cancellable pending on the same profile', (
    tester,
  ) async {
    final repo = _RelationshipsRepository();
    await _mount(tester, repo);
    await _tap(tester, _friend);
    expect(repo.requests, 1);
    expect(find.text('Request pending'), findsOneWidget);
    expect(
      find.byKey(const Key('community-profile-cancel-request')),
      findsOneWidget,
    );
    await _tap(
      tester,
      find.byKey(const Key('community-profile-cancel-request')),
    );
    expect(repo.cancellations, 1);
    expect(find.text('Add Friend'), findsOneWidget);
    expect(repo.follows + repo.unfollows, 0);
  });

  for (final accept in [true, false]) {
    testWidgets(
      'incoming request can be ${accept ? 'accepted' : 'rejected'} in profile',
      (tester) async {
        final repo = _RelationshipsRepository()
          ..relationship = CommunityRelationshipStatus.incoming;
        await _mount(tester, repo);
        await _tap(tester, _friend);
        await _tap(
          tester,
          find.byKey(
            Key('community-profile-${accept ? 'accept' : 'reject'}-request'),
          ),
        );
        expect(repo.accepts, accept ? 1 : 0);
        expect(repo.rejects, accept ? 0 : 1);
        expect(
          repo.relationship,
          accept
              ? CommunityRelationshipStatus.accepted
              : CommunityRelationshipStatus.none,
        );
        expect(repo.follows + repo.unfollows, 0);
      },
    );
  }

  testWidgets('accepted friendship exposes Remove and cancel changes nothing', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..relationship = CommunityRelationshipStatus.accepted;
    await _mount(tester, repo);
    expect(find.text('1 Friends'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Friends'), findsOneWidget);
    await _tap(tester, _friend);
    await _tap(
      tester,
      find.byKey(const Key('community-profile-relationship-cancel')),
    );
    expect(repo.removals, 0);
    await _tap(tester, _friend);
    await _tap(
      tester,
      find.byKey(const Key('community-profile-remove-friend')),
    );
    expect(repo.removals, 1);
    expect(find.text('Add Friend'), findsOneWidget);
  });

  testWidgets('profile privacy suppresses new follow and friend requests', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..allowFollow = false
      ..allowFriend = false;
    await _mount(tester, repo);
    expect(_follow, findsNothing);
    expect(_friend, findsNothing);
  });

  testWidgets('existing follow can be removed after new follows are disabled', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..allowFollow = false
      ..following = true;
    await _mount(tester, repo);
    await _tap(tester, _follow);
    expect(repo.unfollows, 1);
    expect(_follow, findsNothing);
  });

  testWidgets('self profile never exposes social mutations', (tester) async {
    final repo = _RelationshipsRepository()..self = true;
    await _mount(tester, repo);
    expect(_follow, findsNothing);
    expect(_friend, findsNothing);
  });

  testWidgets('unrelated friendship rows cannot authorize cancellation', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..relationship = CommunityRelationshipStatus.pending
      ..connectionRows = [
        {
          'id': _friendship,
          'other_user_id': _member,
          'requester_id': _member,
          'addressee_id': '44444444-4444-4444-8444-444444444444',
          'status': 'pending',
        },
      ];
    await _mount(tester, repo);
    await _tap(
      tester,
      find.byKey(const Key('community-profile-cancel-request')),
    );
    expect(repo.cancellations, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('owner change during friendship confirmation cannot remove', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..relationship = CommunityRelationshipStatus.accepted;
    await _mount(tester, repo);
    await _tap(tester, _friend);
    repo.owner = '44444444-4444-4444-8444-444444444444';
    await tester.tap(find.byKey(const Key('community-profile-remove-friend')));
    await tester.pumpAndSettle();
    expect(repo.removals, 0);
    expect(repo.overviewReads, 1);
  });

  testWidgets('owner change during follow prevents readback for next owner', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()..holdFollow = Completer<void>();
    await _mount(tester, repo);
    await Scrollable.ensureVisible(tester.element(_follow), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(_follow);
    await tester.pump();
    repo.owner = '44444444-4444-4444-8444-444444444444';
    // This synthetic repository has no real auth stream. Rebuild the visit to
    // deliver its changed owner before completing the old operation.
    await _mount(tester, repo);
    repo.holdFollow!.complete();
    await tester.pumpAndSettle();
    expect(repo.overviewReads, 1);
    expect(repo.calls.where((call) => call == 'creator'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'duplicate Add Friend is disabled until the request is read back',
    (tester) async {
      final repo = _RelationshipsRepository()..holdFriend = Completer<void>();
      await _mount(tester, repo);
      await Scrollable.ensureVisible(tester.element(_friend), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(_friend);
      await tester.pump();
      await tester.tap(_friend);
      await tester.pump();
      expect(repo.requests, 1);
      repo.holdFriend!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Request pending'), findsOneWidget);
      expect(repo.overviewReads, 2);
    },
  );

  testWidgets('failed cancellation keeps pending state and allows retry', (
    tester,
  ) async {
    final repo = _RelationshipsRepository()
      ..relationship = CommunityRelationshipStatus.pending
      ..failFriend = true;
    await _mount(tester, repo);
    final cancel = find.byKey(const Key('community-profile-cancel-request'));
    await _tap(tester, cancel);
    expect(find.text('Request pending'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    repo.failFriend = false;
    await _tap(tester, cancel);
    expect(repo.cancellations, 2);
    expect(find.text('Add Friend'), findsOneWidget);
  });

  testWidgets('failed readback never invents follow success', (tester) async {
    final repo = _RelationshipsRepository();
    await _mount(tester, repo);
    repo.failOverview = true;
    await _tap(tester, _follow);
    expect(repo.follows, 1);
    expect(
      find.descendant(of: _follow, matching: find.text('Follow')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'connections opens the other member profile and reloads on return',
    (tester) async {
      final repo = _RelationshipsRepository()
        ..relationship = CommunityRelationshipStatus.accepted;
      String? opened;
      final router = GoRouter(
        initialLocation: '/connections',
        routes: [
          GoRoute(
            path: '/connections',
            builder: (_, _) => CommunityConnectionsPage(repository: repo),
          ),
          GoRoute(
            path: '/community/profile/:id',
            builder: (_, state) {
              opened = state.pathParameters['id'];
              return const Scaffold(body: Text('Opened member profile'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('community-connection-profile-$_member')),
      );
      await tester.pumpAndSettle();
      expect(opened, _member);
      expect(opened, isNot(_owner));
      router.pop();
      await tester.pumpAndSettle();
      expect(repo.connectionReads, 2);
    },
  );

  testWidgets(
    'following from a follower list refreshes the owning profile count',
    (tester) async {
      final repo = _RelationshipsRepository()..self = true;
      await _mount(tester, repo);
      await _tap(tester, find.text('Followers'));
      final action = find.byKey(
        const Key('community-connection-follow-$_member'),
      );
      await _tap(tester, action);
      expect(repo.follows, 1);
      expect(
        find.descendant(of: action, matching: find.text('Unfollow')),
        findsOneWidget,
      );
      Navigator.of(tester.element(action)).pop();
      await tester.pumpAndSettle();
      expect(repo.overviewReads, 2);
      final metric = find
          .ancestor(of: find.text('Following'), matching: find.byType(InkWell))
          .first;
      expect(
        find.descendant(of: metric, matching: find.text('1')),
        findsOneWidget,
      );
      _expectFollowers('0');
    },
  );

  testWidgets(
    'Arabic dark profile keeps follow and friendship actions usable at large text',
    (tester) async {
      final repo = _RelationshipsRepository();
      await _mount(
        tester,
        repo,
        locale: const Locale('ar'),
        brightness: Brightness.dark,
        textScale: 2,
      );
      await _tap(tester, _follow);
      expect(
        find.descendant(of: _follow, matching: find.text('إلغاء المتابعة')),
        findsOneWidget,
      );
      await _tap(tester, _friend);
      expect(find.text('الطلب قيد الانتظار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
