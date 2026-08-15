import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _CommunityInteractionRepository extends CommunityRepository {
  _CommunityInteractionRepository()
    : super(
        SupabaseClient(
          'https://interaction.invalid',
          'interaction-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const currentId = '11111111-1111-4111-8111-111111111111';
  static const otherId = '22222222-2222-4222-8222-222222222222';
  static const friendshipId = '33333333-3333-4333-8333-333333333333';
  String friendshipStatus = 'pending';
  int responseCalls = 0;
  int profileSaves = 0;
  int profileLoads = 0;
  int loadFailuresRemaining = 0;
  bool failDeletion = false;
  int deletionRequests = 0;
  int friendRequests = 0;
  int searchCalls = 0;
  int searchFailuresRemaining = 0;
  int updatesFailuresRemaining = 0;
  bool inboxRead = false;
  bool failPublish = false;
  bool ownFeedPost = false;
  int publishCalls = 0;
  int deletePostCalls = 0;

  @override
  String get currentUserId => currentId;

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    if (updatesFailuresRemaining > 0) {
      updatesFailuresRemaining--;
      throw StateError('injected updates failure');
    }
    return [
      {
        'id': friendshipId,
        'requester_id': otherId,
        'addressee_id': currentId,
        'other_user_id': otherId,
        'status': friendshipStatus,
        'profile': {'display_name': 'BIL QA Partner', 'avatar_url': null},
      },
    ];
  }

  @override
  Future<void> respondToFriendship(String id, {required bool accept}) async {
    responseCalls++;
    friendshipStatus = accept ? 'accepted' : 'declined';
  }

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    profileLoads++;
    if (loadFailuresRemaining > 0) {
      loadFailuresRemaining--;
      throw StateError('injected profile load failure');
    }
    return const CommunityProfile(
      userId: currentId,
      displayName: 'BIL QA Member',
      localeCode: 'en',
      discoverable: true,
      bio: 'Non-personal test profile',
    );
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
    profileSaves++;
  }

  @override
  Future<void> requestAccountDeletion({String? reason}) async {
    deletionRequests++;
    if (failDeletion) {
      throw StateError('injected deletion failure');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    searchCalls++;
    if (searchFailuresRemaining > 0) {
      searchFailuresRemaining--;
      throw StateError('injected search failure');
    }
    return [
      {
        'user_id': otherId,
        'display_name': 'BIL QA Partner',
        'bio': 'Non-personal search result',
        'avatar_url': null,
      },
    ];
  }

  @override
  Future<void> requestFriend(String addresseeId) async {
    expect(addresseeId, otherId);
    friendRequests++;
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: '66666666-6666-4666-8666-666666666666',
      authorId: ownFeedPost ? currentId : otherId,
      authorName: ownFeedPost ? 'BIL QA Member' : 'BIL QA Partner',
      body: 'Non-personal test post',
      createdAt: DateTime.utc(2026, 8, 15),
    ),
  ];

  @override
  Future<void> publishPost(String body) async {
    publishCalls++;
    if (failPublish) throw StateError('injected publish failure');
  }

  @override
  Future<void> deletePost(String postId) async {
    deletePostCalls++;
  }

  Map<String, dynamic> _message(bool incoming) => {
    'id': incoming
        ? '44444444-4444-4444-8444-444444444444'
        : '55555555-5555-4555-8555-555555555555',
    'sender_id': incoming ? otherId : currentId,
    'recipient_id': incoming ? currentId : otherId,
    'body': incoming
        ? '[BIL-SUBJECT]Inbox subject\nInbox body'
        : '[BIL-SUBJECT]Sent subject\nSent body',
    'created_at': DateTime.utc(2026, 8, 15).toIso8601String(),
    'read_at': incoming && !inboxRead
        ? null
        : DateTime.utc(2026, 8, 15, 9).toIso8601String(),
    'profile': {'display_name': 'BIL QA Partner', 'avatar_url': null},
  };

  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => [
    _message(true),
  ];

  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [
    _message(false),
  ];
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  testWidgets('incoming friendship accept reloads the authoritative All tab', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository();
    await tester.pumpWidget(
      _app(CommunityConnectionsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();
    expect(repository.responseCalls, 1);
    expect(repository.friendshipStatus, 'accepted');
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Friend'), findsOneWidget);
  });

  testWidgets('profile save is dispatched once from the authenticated editor', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository();
    await tester.pumpWidget(_app(CommunityProfilePage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -560));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-profile-save')).first);
    await tester.pumpAndSettle();
    expect(repository.profileSaves, 1);
    expect(find.text('Community profile saved.'), findsOneWidget);
  });

  testWidgets('profile load failure exposes Retry and recovers', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository()
      ..loadFailuresRemaining = 1;
    await tester.pumpWidget(_app(CommunityProfilePage(repository: repository)));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load your community profile safely.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.profileLoads, 2);
    expect(find.text('BIL QA Member'), findsOneWidget);
  });

  testWidgets('deletion failure is explained and editor remains available', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository()..failDeletion = true;
    await tester.pumpWidget(_app(CommunityProfilePage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account and data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request deletion'));
    await tester.pumpAndSettle();
    expect(repository.deletionRequests, 1);
    expect(
      find.text('Could not request account deletion. Try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-profile-save')), findsOneWidget);
  });

  testWidgets(
    'messages exposes distinct repository-backed inbox and sent tabs',
    (tester) async {
      final repository = _CommunityInteractionRepository();
      await tester.pumpWidget(
        _app(CommunityMessagesPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox subject'), findsOneWidget);
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(find.text('Sent subject'), findsOneWidget);
      expect(find.text('Inbox subject'), findsNothing);
    },
  );

  testWidgets('people search dispatches one friend request', (tester) async {
    final repository = _CommunityInteractionRepository();
    await tester.pumpWidget(_app(CommunityPeoplePage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('community-people-search')),
      'BIL QA',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();
    expect(repository.friendRequests, 1);
    expect(find.text('Request sent.'), findsOneWidget);
  });

  testWidgets('people search failure retries the same query', (tester) async {
    final repository = _CommunityInteractionRepository()
      ..searchFailuresRemaining = 1;
    await tester.pumpWidget(_app(CommunityPeoplePage(repository: repository)));
    await tester.pumpAndSettle();
    expect(
      find.text('Search is unavailable right now. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.searchCalls, 2);
    expect(find.text('BIL QA Partner'), findsOneWidget);
  });

  testWidgets('community updates derive requests and unread messages', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository();
    await tester.pumpWidget(
      _app(CommunityNotificationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsOneWidget);
    expect(find.text('Unread messages'), findsOneWidget);
  });

  testWidgets('community updates failure exposes working Retry', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository()
      ..updatesFailuresRemaining = 1;
    await tester.pumpWidget(
      _app(CommunityNotificationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Community updates are unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsOneWidget);
  });

  testWidgets('community updates reload after returning from requests', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository()..inboxRead = true;
    final router = GoRouter(
      initialLocation: '/community/notifications',
      routes: [
        GoRoute(
          path: '/community/notifications',
          builder: (_, _) => CommunityNotificationsPage(repository: repository),
        ),
        GoRoute(
          path: '/community/connections',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  repository.friendshipStatus = 'accepted';
                  context.pop();
                },
                child: const Text('Accept fixture request'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsOneWidget);
    await tester.tap(find.text('Friend requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept fixture request'));
    await tester.pumpAndSettle();
    expect(find.text('No community updates'), findsOneWidget);
  });

  testWidgets('community action menu navigates to the selected route', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository();
    final router = GoRouter(
      initialLocation: '/community',
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, _) => CommunityHubPage(repository: repository),
        ),
        GoRoute(
          path: '/community/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile destination')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Community actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);
  });

  testWidgets('feed publish failure retains draft for retry', (tester) async {
    final repository = _CommunityInteractionRepository()..failPublish = true;
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft kept for retry');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 1);
    expect(find.text('Draft kept for retry'), findsOneWidget);
    expect(
      find.text('Could not publish now. Your text is kept so you can retry.'),
      findsOneWidget,
    );
  });

  testWidgets('feed owner deletion requires confirmation and dispatches once', (
    tester,
  ) async {
    final repository = _CommunityInteractionRepository()..ownFeedPost = true;
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key(
          'community-post-actions-66666666-6666-4666-8666-666666666666',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete post?'), findsOneWidget);
    expect(repository.deletePostCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletePostCalls, 1);
  });
}
