import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _ActivityRequest = ({
  DateTime? before,
  String? beforeId,
  List<CommunityNotificationKind>? kinds,
  int limit,
});

class _ActivityRepository extends CommunityRepository {
  _ActivityRepository(this.rows)
    : super(
        SupabaseClient(
          'https://activity-page.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<CommunityNotification> rows;
  final requests = <_ActivityRequest>[];
  bool failMore = false;
  Completer<List<CommunityNotification>>? delayedMore;

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  @override
  Future<CommunityAttention> loadAttention() async =>
      CommunityAttention(communityUpdates: rows.length);

  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async {
    requests.add((
      before: before,
      beforeId: beforeId,
      kinds: kinds == null ? null : List.of(kinds),
      limit: limit,
    ));
    if (before != null && delayedMore != null) return delayedMore!.future;
    if (before != null && failMore) throw StateError('synthetic transport');
    final eligible =
        rows
            .where(
              (row) =>
                  (kinds == null || kinds.contains(row.kind)) &&
                  (before == null ||
                      row.createdAt.isBefore(before) ||
                      (row.createdAt == before &&
                          row.id.compareTo(beforeId!) < 0)),
            )
            .toList()
          ..sort(
            (a, b) => b.createdAt.compareTo(a.createdAt) == 0
                ? b.id.compareTo(a.id)
                : b.createdAt.compareTo(a.createdAt),
          );
    return eligible.take(limit).toList();
  }
}

CommunityNotification _row(
  int index,
  CommunityNotificationKind kind, {
  DateTime? time,
}) => CommunityNotification(
  id: '99999999-9999-4999-8999-${index.toString().padLeft(12, '0')}',
  kind: kind,
  actorId: '22222222-2222-4222-8222-222222222222',
  actorDisplayName: 'Peer $index',
  createdAt:
      time ?? DateTime.utc(2026, 10, 4).subtract(Duration(minutes: index)),
  entityKind: 'post',
  entityId: '33333333-3333-4333-8333-333333333333',
  copyKey: 'synthetic_activity_v1',
  deepLinkPath: '/community',
);

Future<void> _pump(
  WidgetTester tester,
  _ActivityRepository repository,
  String language,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CommunityNotificationsPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String filter) async {
  final chip = find.byKey(Key('community-activity-filter-$filter'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester) async {
  final more = find.byKey(const Key('community-activity-load-more'));
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  expect(vertical, findsOneWidget);
  await tester.scrollUntilVisible(more, 400, scrollable: vertical);
  expect(more.hitTestable(), findsOneWidget);
  await tester.tap(more.hitTestable());
  await tester.pump();
}

void main() {
  test(
    'repository sends filter and stable tuple cursor to actual RPC transport',
    () async {
      final requests = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://activity-rpc.invalid',
        'synthetic-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/bil_list_community_activity_v2',
          );
          requests.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final repository = CommunityRepository(client);
      final before = DateTime.utc(2026, 10, 4);
      const beforeId = '99999999-9999-4999-8999-999999999999';
      await repository.loadCommunityNotifications(
        kinds: [CommunityNotificationKind.follow],
      );
      await repository.loadCommunityNotifications(
        before: before,
        beforeId: beforeId,
        kinds: [
          CommunityNotificationKind.comment,
          CommunityNotificationKind.reply,
        ],
        limit: 30,
      );
      expect(requests.first, {
        'p_before': null,
        'p_before_id': null,
        'p_kinds': ['follow'],
        'p_limit': 30,
      });
      expect(requests.last, {
        'p_before': before.toIso8601String(),
        'p_before_id': beforeId,
        'p_kinds': ['comment', 'reply'],
        'p_limit': 30,
      });
      await expectLater(
        repository.loadCommunityNotifications(before: before),
        throwsArgumentError,
      );
      await expectLater(
        repository.loadCommunityNotifications(kinds: []),
        throwsArgumentError,
      );
      expect(requests, hasLength(2));
    },
  );
  for (final language in ['en', 'ar']) {
    testWidgets(
      'server filter finds older category outside newest 30 in $language',
      (tester) async {
        final repository = _ActivityRepository([
          for (var i = 1; i <= 35; i++)
            _row(i, CommunityNotificationKind.postLike),
          _row(100, CommunityNotificationKind.mention),
          _row(101, CommunityNotificationKind.friendAccepted),
        ]);
        await _pump(tester, repository, language);
        expect(
          repository.requests.first.kinds,
          isNull, // The initial All tab must not exclude badge-producing kinds.
        );
        expect(
          repository.requests.first.kinds,
          isNot(contains(CommunityNotificationKind.mention)),
        );
        await _choose(tester, 'reactions');
        expect(repository.requests.last.kinds, [
          CommunityNotificationKind.mention,
        ]);
        expect(repository.requests.last.before, isNull);
        expect(find.textContaining('Peer 100'), findsOneWidget);
        expect(find.textContaining('Peer 101'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cursor paging fails safely and retries same cursor in $language',
      (tester) async {
        final tiedTime = DateTime.utc(2026, 10, 4);
        final rows = [
          for (var i = 1; i <= 31; i++)
            _row(i, CommunityNotificationKind.comment, time: tiedTime),
        ];
        final repository = _ActivityRepository(rows);
        await _pump(tester, repository, language);
        await _choose(tester, 'comments');
        repository.failMore = true;
        await _more(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsOneWidget);
        final failedCursor = repository.requests.last;
        expect(failedCursor.before, tiedTime);
        expect(failedCursor.beforeId, rows[1].id);
        final requestsAfterFailure = repository.requests.length;
        final errorSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        // The human-visible error overlays the bottom action until its normal
        // lifetime ends. Do not manufacture a tap through that overlay.
        await tester.pump(errorSnackBar.duration + const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        repository.failMore = false;
        await _more(tester);
        await tester.pumpAndSettle();
        expect(repository.requests, hasLength(requestsAfterFailure + 1));
        expect(repository.requests.last.before, failedCursor.before);
        expect(repository.requests.last.beforeId, failedCursor.beforeId);
        expect(find.textContaining('Peer 1 '), findsOneWidget);
        expect(
          find.byKey(const Key('community-activity-load-more')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('filter switch discards late page from previous category', (
    tester,
  ) async {
    final rows = [
      for (var i = 1; i <= 31; i++) _row(i, CommunityNotificationKind.comment),
      _row(100, CommunityNotificationKind.mention),
    ];
    final repository = _ActivityRepository(rows);
    await _pump(tester, repository, 'en');
    await _choose(tester, 'comments');
    final late = Completer<List<CommunityNotification>>();
    repository.delayedMore = late;
    await _more(tester);
    // Pending spinner is intentionally not settled. Move back to filters.
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pump();
    await _choose(tester, 'reactions');
    expect(find.textContaining('Peer 100'), findsOneWidget);
    late.complete([rows[30]]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Peer 31 '), findsNothing);
    expect(find.textContaining('Peer 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty update category keeps other server filters reachable', (
    tester,
  ) async {
    final repository = _ActivityRepository([
      _row(1, CommunityNotificationKind.mention),
    ]);
    await _pump(tester, repository, 'en');
    expect(
      find.byKey(const Key('community-activity-filter-reactions')),
      findsOneWidget,
    );
    await _choose(tester, 'reactions');
    expect(find.textContaining('Peer 1 '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
