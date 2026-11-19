import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8000-000000000001';
const _otherOwner = '00000000-0000-4000-8000-000000000002';
const _peer = '00000000-0000-4000-8000-000000000003';

Map<String, dynamic> _row(
  String status, {
  bool incoming = false,
  int serial = 3,
}) {
  final peer = '00000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}';
  return {
    'id': '10000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}',
    'requester_id': incoming ? peer : _owner,
    'addressee_id': incoming ? _owner : peer,
    'other_user_id': peer,
    'status': status,
    'created_at': '2026-11-18T10:00:00Z',
    'display_name': '${incoming ? 'Incoming' : 'Outgoing'} $status',
    'avatar_url': null,
    'profile': {
      'display_name': '${incoming ? 'Incoming' : 'Outgoing'} $status',
    },
  };
}

void main() {
  testWidgets(
    'successful retype replaces a stale Pending override with declined',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await h.pending(tester);
        h.repository.rows = [_row('declined')];
        await h.query(tester, 'peer');
        expect(h.repository.relationshipReads, 1);
        expect(find.byTooltip('Pending'), findsNothing);
        expect(find.byTooltip('Unavailable'), findsOneWidget);
        expect(find.byTooltip('Send request'), findsNothing);
        expect(
          h.repository.requests,
          1,
          reason: 'Reading a decline never resends it.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );

  for (final result in ['accepted', 'missing', 'incoming', 'failure']) {
    testWidgets(
      'fresh People relationship $result preserves its exact meaning',
      (tester) async {
        final h = await _Harness.open(tester);
        try {
          await h.pending(tester);
          h.repository.failRead = result == 'failure';
          h.repository.rows = result == 'missing'
              ? []
              : [
                  _row(
                    result == 'incoming' ? 'pending' : 'accepted',
                    incoming: result == 'incoming',
                  ),
                ];
          await h.query(tester, 'peer');
          expect(h.repository.relationshipReads, 1);
          if (result == 'failure') {
            expect(find.byTooltip('Pending'), findsOneWidget);
            expect(find.byTooltip('Send request'), findsNothing);
          } else if (result == 'accepted') {
            expect(find.byTooltip('Friend'), findsOneWidget);
            expect(find.byTooltip('Pending'), findsNothing);
          } else if (result == 'incoming') {
            expect(find.text('Review'), findsOneWidget);
            expect(find.byTooltip('Pending'), findsNothing);
          } else {
            expect(find.byTooltip('Send request'), findsOneWidget);
            expect(
              find.byTooltip('Unavailable'),
              findsNothing,
              reason:
                  'A missing/private/blocked row is not an inferred rejection.',
            );
          }
          expect(h.repository.requests, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  testWidgets(
    'an older query relationship read cannot overwrite a newer declined result',
    (tester) async {
      final h = await _Harness.open(tester);
      final held = Completer<List<Map<String, dynamic>>>();
      try {
        await h.pending(tester);
        h.repository.holdNextRead = held;
        await h.query(tester, 'old query', settle: false);
        expect(h.repository.relationshipReads, 1);
        expect(held.isCompleted, isFalse);
        h.repository.rows = [_row('declined')];
        await h.query(tester, 'new query');
        expect(h.repository.relationshipReads, 2);
        expect(find.byTooltip('Unavailable'), findsOneWidget);
        held.complete([_row('pending')]);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Unavailable'), findsOneWidget);
        expect(find.byTooltip('Pending'), findsNothing);
        expect(h.repository.requests, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!held.isCompleted) held.complete([]);
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'a hidden identity result does not invent a declined status or resend',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await h.pending(tester);
        h.repository.hidden = true;
        await h.query(tester, 'hidden peer');
        expect(find.text('No people found.'), findsOneWidget);
        expect(find.byTooltip('Pending'), findsNothing);
        expect(find.byTooltip('Unavailable'), findsNothing);
        expect(find.byTooltip('Send request'), findsNothing);
        expect(h.repository.requests, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'a held People refresh cannot restore rows after delivered owner A B A',
    (tester) async {
      final h = await _Harness.open(tester);
      final held = Completer<List<Map<String, dynamic>>>();
      try {
        await h.pending(tester);
        h.repository.holdNextRead = held;
        await h.query(tester, 'peer', settle: false);
        expect(h.repository.relationshipReads, 1);
        for (final owner in [_otherOwner, _owner]) {
          await tester.runAsync(() => h.signIn(owner));
          await tester.pump();
        }
        held.complete([_row('declined')]);
        await tester.pumpAndSettle();
        expect(h.client.auth.currentUser?.id, _owner);
        expect(find.text('Synthetic peer'), findsNothing);
        expect(find.byTooltip('Pending'), findsNothing);
        expect(find.byTooltip('Send request'), findsNothing);
        expect(h.repository.requests, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!held.isCompleted) held.complete([]);
        await h.close(tester);
      }
    },
  );

  for (final locale in ['en', 'ar']) {
    testWidgets(
      'Sent shows only requester-owned pending accepted declined: $locale',
      (tester) async {
        final h = await _Harness.open(
          tester,
          connections: true,
          locale: locale,
          rows: [
            _row('pending', serial: 3),
            _row('accepted', serial: 4),
            _row('declined', serial: 5),
            _row('pending', incoming: true, serial: 6),
            _row('declined', incoming: true, serial: 7),
          ],
        );
        try {
          await tester.tap(
            find.byKey(const Key('community-connections-sent-tab')),
          );
          await tester.pumpAndSettle();
          for (final status in ['pending', 'accepted', 'declined']) {
            expect(find.text('Outgoing $status'), findsOneWidget);
          }
          expect(find.text('Incoming pending'), findsNothing);
          expect(find.text('Incoming declined'), findsNothing);
          expect(
            find.text(locale == 'ar' ? 'طلب مرفوض' : 'Request declined'),
            findsOneWidget,
          );
          expect(
            find.byTooltip(locale == 'ar' ? 'قبول' : 'Accept'),
            findsNothing,
          );
          expect(
            find.byTooltip(locale == 'ar' ? 'رفض' : 'Decline'),
            findsNothing,
          );
          final declinedRow = find.byKey(
            const Key(
              'community-connection-profile-00000000-0000-4000-8000-000000000005',
            ),
          );
          expect(
            find.descendant(of: declinedRow, matching: find.byType(IconButton)),
            findsNothing,
          );
          expect(h.repository.requests, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  test(
    'repository retains only requester-owned declined with exact other identity',
    () async {
      final response = [
        _row('declined'),
        _row('declined', incoming: true, serial: 4),
        {
          ..._row('accepted', serial: 5),
          'requester_id': _otherOwner,
          'addressee_id': _peer,
        },
        {..._row('declined', serial: 6), 'other_user_id': _peer},
      ];
      final client = await _client(response);
      try {
        final rows = await CommunityRepository(
          client,
        ).loadFriendshipsWithProfiles();
        expect(rows, hasLength(1));
        expect(rows.single['status'], 'declined');
        expect(rows.single['requester_id'], _owner);
        expect(rows.single['other_user_id'], _peer);
      } finally {
        await client.dispose();
      }
    },
  );
}

Future<SupabaseClient> _client(Object response) async {
  final client = SupabaseClient(
    'https://outgoing-fixture.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(response),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  await client.auth.setInitialSession(jsonEncode(_session(_owner)));
  return client;
}

Map<String, dynamic> _session(String owner) => {
  'access_token': 'synthetic-token',
  'token_type': 'bearer',
  'user': {
    'id': owner,
    'app_metadata': {},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  },
};

class _Harness {
  _Harness(this.client, this.repository, this.router);
  final SupabaseClient client;
  final _Repository repository;
  final GoRouter router;
  static Future<_Harness> open(
    WidgetTester tester, {
    bool connections = false,
    String locale = 'en',
    List<Map<String, dynamic>> rows = const [],
  }) async {
    final client = (await tester.runAsync(() => _client([])))!;
    final repository = _Repository(client)..rows = rows;
    final router = GoRouter(
      initialLocation: connections ? '/connections' : '/people',
      routes: [
        GoRoute(
          path: '/people',
          builder: (_, _) => CommunityPeoplePage(repository: repository),
        ),
        GoRoute(
          path: '/connections',
          builder: (_, _) => CommunityConnectionsPage(repository: repository),
        ),
        GoRoute(
          path: '/community',
          builder: (_, _) => const Scaffold(body: Text('Community')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Sign in')),
        ),
      ],
    );
    final h = _Harness(client, repository, router);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> signIn(String owner) =>
      client.auth.setInitialSession(jsonEncode(_session(owner)));
  Future<void> pending(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pending'), findsOneWidget);
    expect(repository.requests, 1);
  }

  Future<void> query(
    WidgetTester tester,
    String query, {
    bool settle = true,
  }) async {
    await tester.enterText(
      find.byKey(const Key('community-people-search')),
      query,
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await tester.runAsync(client.dispose);
  }
}

class _Repository extends CommunityRepository {
  _Repository(super.client);
  List<Map<String, dynamic>> rows = [];
  Completer<List<Map<String, dynamic>>>? holdNextRead;
  bool failRead = false, hidden = false;
  int relationshipReads = 0, requests = 0;
  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async => [
    if (!hidden)
      {
        'user_id': _peer,
        'display_name': 'Synthetic peer',
        'handle': 'synthetic_peer',
      },
  ];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    relationshipReads++;
    final held = holdNextRead;
    holdNextRead = null;
    if (held != null) {
      return held.future;
    }
    if (failRead) {
      throw StateError('Synthetic relationship read unavailable');
    }
    return List.of(rows);
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String id) async {
    requests++;
    rows = [_row('pending')];
    return CommunityFriendRequestStatus.pending;
  }

  @override
  Stream<void> watchConnectionChanges() => const Stream.empty();
}
