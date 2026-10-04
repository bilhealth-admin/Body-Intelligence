import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NotificationRepository extends CommunityRepository {
  _NotificationRepository({this.path = '/community/connections'})
    : super(
        SupabaseClient(
          'https://notification-fixture.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final String path;
  final writes = <Completer<int>>[];
  final markedIds = <List<String>>[];

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  @override
  Future<CommunityAttention> loadAttention() async =>
      const CommunityAttention(communityUpdates: 1);

  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    int limit = 30,
  }) async => [
    CommunityNotification(
      id: '99999999-9999-4999-8999-999999999999',
      kind: CommunityNotificationKind.friendAccepted,
      actorId: '22222222-2222-4222-8222-222222222222',
      actorDisplayName: 'Peer',
      createdAt: DateTime.utc(2026, 10, 3),
      entityKind: 'friendship',
      entityId: '33333333-3333-4333-8333-333333333333',
      copyKey: 'friend_accepted_v1',
      deepLinkPath: path,
    ),
  ];

  @override
  Future<int> markCommunityNotificationsSeen(List<String> ids) {
    markedIds.add(List<String>.of(ids));
    return writes.removeAt(0).future;
  }
}

Future<GoRouter> _pumpNotifications(
  WidgetTester tester,
  _NotificationRepository repository, {
  required String language,
}) async {
  final router = GoRouter(
    initialLocation: '/community/notifications',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Outside activity')),
      ),
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => CommunityNotificationsPage(repository: repository),
      ),
      GoRoute(
        path: '/community/connections',
        builder: (_, _) =>
            const Scaffold(body: Text('Connections destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: Locale(language),
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
  expect(
    find.byKey(const Key('community-activity-filter-updates')),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
  return router;
}

Finder _acceptanceRow(String language) => find.widgetWithText(
  ListTile,
  language == 'ar'
      ? 'Peer قبل طلب صداقتك'
      : 'Peer accepted your friend request',
);

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('seen failure is handled and retry succeeds in $language', (
      tester,
    ) async {
      final repository = _NotificationRepository();
      final failedWrite = Completer<int>();
      final retriedWrite = Completer<int>();
      repository.writes.addAll([failedWrite, retriedWrite]);
      await _pumpNotifications(tester, repository, language: language);

      await tester.tap(_acceptanceRow(language));
      await tester.pump();
      expect(repository.markedIds, hasLength(1));
      failedWrite.completeError(StateError('synthetic transport failure'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('synthetic transport failure'), findsNothing);
      expect(_acceptanceRow(language), findsOneWidget);
      expect(find.text('Connections destination'), findsNothing);

      await tester.tap(_acceptanceRow(language));
      await tester.pump();
      expect(repository.markedIds, hasLength(2));
      expect(repository.markedIds.first, repository.markedIds.last);
      retriedWrite.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('Connections destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid repeated tap has one in-flight seen write', (tester) async {
    final repository = _NotificationRepository();
    final write = Completer<int>();
    repository.writes.add(write);
    final router = await _pumpNotifications(tester, repository, language: 'en');

    await tester.tap(_acceptanceRow('en'));
    await tester.tap(_acceptanceRow('en'));
    await tester.pump();
    expect(repository.markedIds, hasLength(1));
    write.complete(1);
    await tester.pumpAndSettle();
    expect(find.text('Connections destination'), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.pop();
    await tester.pumpAndSettle();
    expect(_acceptanceRow('en'), findsOneWidget);
    expect(find.text('Connections destination'), findsNothing);
  });

  testWidgets('late failed seen write is safe after leaving the route', (
    tester,
  ) async {
    final repository = _NotificationRepository();
    final write = Completer<int>();
    repository.writes.add(write);
    final router = await _pumpNotifications(tester, repository, language: 'en');

    await tester.tap(_acceptanceRow('en'));
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Outside activity'), findsOneWidget);
    write.completeError(StateError('synthetic late transport failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Connections destination'), findsNothing);
  });

  testWidgets('server acceptance inbox link opens its relationship', (
    tester,
  ) async {
    final repository = _NotificationRepository(
      path: '/community/notifications',
    );
    final write = Completer<int>();
    repository.writes.add(write);
    await _pumpNotifications(tester, repository, language: 'en');
    await tester.tap(_acceptanceRow('en'));
    await tester.pump();
    write.complete(1);
    await tester.pumpAndSettle();
    expect(repository.markedIds, hasLength(1));
    expect(find.text('Connections destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
