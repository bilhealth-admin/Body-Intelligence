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

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

class _ActivityRepo extends CommunityRepository {
  _ActivityRepo({this.owner = _ownerA, this.count = 70})
    : super(
        SupabaseClient(
          'https://activity-fixture.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final String owner;
  final int count;
  final seen = <String>{};
  final calls = <List<String>>[];
  final reads = <({DateTime? before, String? beforeId})>[];
  final trace = <String>[];
  bool fail = false;
  bool suppressReadback = false;
  int privateReads = 0;
  int friendChanges = 0;
  Completer<void>? pending;

  @override
  String get currentUserId => owner;

  String id(int index) =>
      '99999999-9999-4999-8999-${index.toString().padLeft(12, '0')}';

  CommunityNotification row(int index) => CommunityNotification(
    id: id(index),
    kind: index.isEven
        ? CommunityNotificationKind.postLike
        : CommunityNotificationKind.comment,
    actorId: _ownerB,
    actorDisplayName: 'Peer $index',
    createdAt: DateTime.utc(2026, 10, 6).subtract(Duration(minutes: index)),
    entityKind: 'post',
    entityId: '33333333-3333-4333-8333-333333333333',
    copyKey: 'synthetic_activity_v1',
    deepLinkPath: '/community',
    seenAt: seen.contains(id(index)) && !suppressReadback
        ? DateTime.utc(2026, 10, 6)
        : null,
  );

  @override
  Future<CommunityAttention> loadAttention() async {
    trace.add('attention');
    return CommunityAttention(
      communityUpdates: count - seen.length,
      unreadMessages: 7,
      incomingRequests: 2,
    );
  }

  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async {
    reads.add((before: before, beforeId: beforeId));
    trace.add('read');
    return [for (var i = 0; i < count; i++) row(i)]
        .where((r) => kinds == null || kinds.contains(r.kind))
        .where(
          (r) =>
              before == null ||
              r.createdAt.isBefore(before) ||
              (r.createdAt == before && r.id.compareTo(beforeId!) < 0),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    calls.add(List.of(ids));
    trace.add('mark');
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Offline fixture');
    var changed = 0;
    for (final value in ids) {
      if (seen.add(value)) changed++;
    }
    return changed;
  }

  @override
  Future<void> markConversationRead(String otherUserId) async {
    privateReads++;
    throw StateError('Activity acknowledgement cannot read a conversation');
  }

  @override
  Future<void> respondToFriendship(String id, {required bool accept}) async {
    friendChanges++;
    throw StateError('Reading cannot answer a friend request');
  }
}

Future<ValueNotifier<_ActivityRepo>> _mount(
  WidgetTester tester,
  _ActivityRepo repository, {
  String language = 'en',
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final selected = ValueNotifier(repository);
  addTearDown(selected.dispose);
  addTearDown(() async {
    debugPrint('R4 trace: client dispose begins');
    await repository.communitySocialClient.dispose();
    debugPrint('R4 trace: client dispose ends');
  });
  final router = GoRouter(
    initialLocation: '/community/notifications',
    routes: [
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => ValueListenableBuilder<_ActivityRepo>(
          valueListenable: selected,
          builder: (_, value, _) =>
              CommunityNotificationsPage(repository: value),
        ),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const Scaffold(body: Text('Community destination')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
    ],
  );
  addTearDown(router.dispose);
  debugPrint('R4 trace: mount begins');
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
  debugPrint('R4 trace: first frame complete');
  await tester.pumpAndSettle();
  debugPrint('R4 trace: mount settled');
  return selected;
}

Future<void> _dwell(WidgetTester tester) async {
  debugPrint('R4 trace: dwell begins');
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 20));
  debugPrint('R4 trace: dwell elapsed');
  await tester.pumpAndSettle();
  debugPrint('R4 trace: dwell settled');
}

Finder get _vertical => find
    .descendant(
      of: find.byKey(const PageStorageKey('community-activity-list')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'real inbox automatically persists only visible activity in $language',
      (tester) async {
        final repository = _ActivityRepo();
        await _mount(tester, repository, language: language);
        expect(repository.calls, isEmpty);
        await _dwell(tester);
        expect(repository.calls, isNotEmpty);
        expect(repository.seen, isNotEmpty);
        expect(repository.seen.length, lessThan(30));
        expect(repository.seen, isNot(contains(repository.id(29))));
        expect(repository.seen, isNot(contains(repository.id(69))));
        expect(
          repository.trace.indexOf('mark'),
          lessThan(repository.trace.lastIndexOf('read')),
        );
        expect(repository.privateReads, 0);
        expect(repository.friendChanges, 0);
        final attention = await repository.loadAttention();
        expect(attention.incomingRequests, 2);
        expect(attention.unreadMessages, 7);
        expect(
          attention.communityUpdates,
          repository.count - repository.seen.length,
        );
        expect(tester.takeException(), isNull);
        debugPrint('R4 trace: initial assertions complete');
      },
    );
  }

  testWidgets(
    'a successful write without seen readback never paints false Seen',
    (tester) async {
      final repository = _ActivityRepo(count: 4)..suppressReadback = true;
      await _mount(tester, repository);
      await _dwell(tester);
      expect(repository.seen, isNotEmpty);
      expect(find.text('Seen'), findsNothing);
      expect(find.text('New'), findsWidgets);
      final calls = repository.calls.length;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(repository.calls.length, calls);
    },
  );

  testWidgets(
    'offline automatic read is retryable and never clears unread rows',
    (tester) async {
      final repository = _ActivityRepo(count: 4)..fail = true;
      await _mount(tester, repository);
      await _dwell(tester);
      expect(repository.calls, hasLength(1));
      expect(repository.seen, isEmpty);
      expect(find.text('New'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
      expect(repository.calls, hasLength(1));
      repository.fail = false;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await _dwell(tester);
      expect(repository.seen, isNotEmpty);
      expect(find.text('Seen'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'original page cursor and scroll position survive automatic readback',
    (tester) async {
      final repository = _ActivityRepo();
      await _mount(tester, repository);
      final more = find.byKey(const Key('community-activity-load-more'));
      await tester.scrollUntilVisible(more, 400, scrollable: _vertical);
      await tester.tap(more);
      await tester.pumpAndSettle();
      final later = find.textContaining('Peer 45 ');
      await tester.scrollUntilVisible(later, 250, scrollable: _vertical);
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(_vertical).position.pixels;
      final loads = repository.reads.length;
      await _dwell(tester);
      expect(repository.reads.length, greaterThan(loads));
      expect(repository.reads.last.before, isNotNull);
      expect(
        tester.state<ScrollableState>(_vertical).position.pixels,
        closeTo(position, 1),
      );
      expect(later, findsOneWidget);
      expect(repository.seen.contains(repository.id(69)), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late first-account write does not refresh or acknowledge second account',
    (tester) async {
      final wait = Completer<void>();
      final first = _ActivityRepo(count: 4)..pending = wait;
      final selected = await _mount(tester, first);
      await _dwell(tester);
      expect(first.calls, hasLength(1));
      final second = _ActivityRepo(owner: _ownerB, count: 3);
      addTearDown(second.communitySocialClient.dispose);
      selected.value = second;
      await tester.pumpAndSettle();
      wait.complete();
      await tester.pumpAndSettle();
      expect(second.seen, isEmpty);
      await _dwell(tester);
      expect(second.seen, hasLength(3));
      expect(first.reads, hasLength(1));
      expect(second.privateReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tap still opens its destination while automatic receipt is in flight',
    (tester) async {
      final wait = Completer<void>();
      final repository = _ActivityRepo(count: 4)..pending = wait;
      await _mount(tester, repository);
      await _dwell(tester);
      await tester.tap(find.textContaining('Peer 0 '));
      await tester.pump();
      wait.complete();
      await tester.pumpAndSettle();
      expect(find.text('Community destination'), findsOneWidget);
      expect(repository.privateReads, 0);
      expect(repository.friendChanges, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background inbox does not acknowledge rows merely fetched', (
    tester,
  ) async {
    final repository = _ActivityRepo(count: 4);
    await _mount(tester, repository);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _dwell(tester);
    expect(repository.calls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await _dwell(tester);
    expect(repository.seen, hasLength(4));
    expect(tester.takeException(), isNull);
  });
}
