import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_return_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// These exercise the real Flutter page against an explicit, offline RPC seam.
// They are NOT device, push-provider, or real Supabase E2E tests.
class _InboxRepository extends CommunityRepository {
  _InboxRepository(this.rows)
    : super(
        SupabaseClient(
          'https://offline-inbox.invalid',
          'synthetic-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<CommunityNotification> rows;
  final seenIds = <String>{};
  final marks = <List<String>>[];
  final requestedKinds = <List<CommunityNotificationKind>?>[];
  Completer<void>? pendingWrite;
  bool failWrite = false;
  int reads = 0;

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  @override
  Future<CommunityAttention> loadAttention() async => CommunityAttention(
    communityUpdates: rows.where((item) => !seenIds.contains(item.id)).length,
  );

  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async {
    reads += 1;
    requestedKinds.add(kinds == null ? null : List.of(kinds));
    return rows
        .where((item) => kinds == null || kinds.contains(item.kind))
        .where((item) => before == null || item.createdAt.isBefore(before))
        .take(limit)
        .map(
          (item) => CommunityNotification(
            id: item.id,
            kind: item.kind,
            actorId: item.actorId,
            actorDisplayName: item.actorDisplayName,
            createdAt: item.createdAt,
            entityKind: item.entityKind,
            entityId: item.entityId,
            copyKey: item.copyKey,
            deepLinkPath: item.deepLinkPath,
            seenAt: seenIds.contains(item.id)
                ? DateTime.utc(2026, 10, 5)
                : null,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    marks.add(List.of(ids));
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw StateError('offline fixture');
    var changed = 0;
    for (final id in ids) {
      if (seenIds.add(id)) changed += 1;
    }
    return changed;
  }
}

CommunityNotification _activity(int index, CommunityNotificationKind kind) =>
    CommunityNotification(
      id: '99999999-9999-4999-8999-${index.toString().padLeft(12, '0')}',
      kind: kind,
      actorId: '22222222-2222-4222-8222-222222222222',
      actorDisplayName: 'Peer $index',
      createdAt: DateTime.utc(2026, 10, 5).subtract(Duration(minutes: index)),
      entityKind: 'post',
      entityId: '33333333-3333-4333-8333-333333333333',
      copyKey: 'synthetic_activity_v1',
      deepLinkPath: '/community',
    );

Future<GoRouter> _mount(
  WidgetTester tester,
  _InboxRepository repository, {
  String language = 'en',
}) async {
  final router = GoRouter(
    initialLocation: '/community/notifications',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Safe dashboard')),
      ),
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => CommunityNotificationsPage(repository: repository),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => Scaffold(
          appBar: AppBar(leading: const CommunityReturnButton()),
          body: const Text('Community destination'),
        ),
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
  return router;
}

Finder get _markPage =>
    find.byKey(const Key('community-activity-mark-page-read'));

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('All initially includes reactions and comments in $language', (
      tester,
    ) async {
      final repository = _InboxRepository([
        _activity(1, CommunityNotificationKind.postLike),
        _activity(2, CommunityNotificationKind.comment),
      ]);
      await _mount(tester, repository, language: language);
      expect(repository.requestedKinds.first, isNull);
      final all = tester.widget<ChoiceChip>(
        find.byKey(const Key('community-activity-filter-all')),
      );
      expect(all.selected, isTrue);
      expect(
        repository.marks,
        isEmpty,
      ); // Reading a list does not acknowledge it.
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Page acknowledgement writes only the selected category', (
    tester,
  ) async {
    final accepted = _activity(1, CommunityNotificationKind.friendAccepted);
    final liked = _activity(2, CommunityNotificationKind.postLike);
    final repository = _InboxRepository([accepted, liked]);
    await _mount(tester, repository);
    await tester.tap(
      find.byKey(const Key('community-activity-filter-updates')),
    );
    await tester.pumpAndSettle();
    await tester.tap(_markPage);
    await tester.pumpAndSettle();
    expect(repository.marks, [
      <String>[accepted.id],
    ]);
    expect(repository.seenIds.contains(liked.id), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Badge and rows use readback after acknowledgement', (
    tester,
  ) async {
    final repository = _InboxRepository([
      _activity(1, CommunityNotificationKind.postLike),
    ]);
    await _mount(tester, repository);
    final readsBefore = repository.reads;
    await tester.tap(_markPage);
    await tester.pumpAndSettle();
    expect(repository.reads, greaterThan(readsBefore));
    expect(find.text('Seen'), findsOneWidget);
    expect(_markPage, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed acknowledgement retains unread row and permits retry', (
    tester,
  ) async {
    final repository = _InboxRepository([
      _activity(1, CommunityNotificationKind.postLike),
    ])..failWrite = true;
    await _mount(tester, repository);
    await tester.tap(_markPage);
    await tester.pumpAndSettle();
    expect(repository.seenIds, isEmpty);
    expect(find.text('New'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    repository.failWrite = false;
    await tester.tap(_markPage);
    await tester.pumpAndSettle();
    expect(repository.marks, hasLength(2));
    expect(repository.seenIds, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Repeated mark taps share one in-flight write', (tester) async {
    final completion = Completer<void>();
    final repository = _InboxRepository([
      _activity(1, CommunityNotificationKind.postLike),
    ])..pendingWrite = completion;
    await _mount(tester, repository);
    await tester.tap(_markPage);
    await tester.tap(_markPage);
    await tester.pump();
    expect(repository.marks, hasLength(1));
    expect(repository.seenIds, isEmpty);
    completion.complete();
    await tester.pumpAndSettle();
    expect(repository.seenIds, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unfetched older notifications are not silently acknowledged', (
    tester,
  ) async {
    final repository = _InboxRepository([
      for (var i = 1; i <= 40; i++)
        _activity(i, CommunityNotificationKind.postLike),
    ]);
    await _mount(tester, repository);
    await tester.tap(_markPage);
    await tester.pumpAndSettle();
    expect(repository.marks.single, hasLength(30));
    expect(repository.seenIds.contains(repository.rows.last.id), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cold root notification page returns to dashboard', (
    tester,
  ) async {
    final repository = _InboxRepository([]);
    final router = await _mount(tester, repository);
    expect(router.canPop(), isFalse);
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(find.text('Safe dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A pushed Community page returns to its existing inbox', (
    tester,
  ) async {
    final repository = _InboxRepository([]);
    final router = await _mount(tester, repository);
    unawaited(router.push<void>('/community'));
    await tester.pumpAndSettle();
    expect(find.text('Community destination'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-safe-return')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityNotificationsPage), findsOneWidget);
    expect(find.text('Safe dashboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
