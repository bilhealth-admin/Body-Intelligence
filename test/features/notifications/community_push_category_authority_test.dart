import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/notifications/domain/community_push_delivery_categories.dart';
import 'package:body_intelligence_log/features/notifications/domain/notification_delivery_preferences.dart';
import 'package:body_intelligence_log/features/notifications/services/community_push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Actual Supabase SDK/RPC transport; explicitly MOCKED_BACKEND_CONTRACTS_ONLY.
// Real Production SQL, FCM/APNs, and physical delivery are separate evidence.
const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';

void main() {
  test('category owner getter preserves unknown, not fabricated OFF', () async {
    final fixture = await _AuthorityFixture.open();
    fixture.reply = _receipt(initialized: false, revision: 0);
    final actual = await fixture.service.loadDeliveryCategories();
    expect(actual.initialized, isFalse);
    expect(actual.desired, isNull);
    expect(actual.verified, isFalse);
    expect(actual.revision, 0);
    expect(fixture.paths, [
      '/rest/v1/rpc/bil_get_my_push_delivery_categories_v1',
    ]);
  });

  test(
    'category owner getter verifies exact persisted desired without tokens',
    () async {
      final fixture = await _AuthorityFixture.open();
      fixture.reply = _receipt(message: false, request: true, accepted: false);
      final actual = await fixture.service.loadDeliveryCategories();
      expect(actual.ownerId, _owner);
      expect(actual.desired, {NotificationCategory.friendRequest});
      expect(actual.effective, isEmpty);
      expect(actual.verified, isTrue);
    },
  );

  test(
    'category strict CAS setter sends exact four arguments and accepts readback',
    () async {
      final fixture = await _AuthorityFixture.open();
      final current = _state(_receipt());
      fixture.reply = _receipt(revision: 2, accepted: false);
      final actual = await fixture.service.syncDeliveryPreferences(
        const NotificationDeliveryPreferences(
          enabledCategories: {
            NotificationCategory.newMessage,
            NotificationCategory.friendRequest,
          },
        ),
        expectedState: current,
      );
      expect(actual.revision, 2);
      expect(
        actual.desired!.contains(NotificationCategory.friendAccepted),
        isFalse,
      );
      expect(fixture.paths, [
        '/rest/v1/rpc/bil_set_my_push_delivery_categories_v1',
      ]);
      expect(fixture.parameters.single, {
        'p_message_enabled': true,
        'p_friend_request_enabled': true,
        'p_friend_accepted_enabled': false,
        'p_expected_revision': 1,
      });
    },
  );

  test(
    'category identical verified CAS snapshot accepts only same revision',
    () async {
      final fixture = await _AuthorityFixture.open();
      final current = _state(_receipt(revision: 7));
      fixture.reply = _receipt(revision: 7);
      final actual = await fixture.service.syncDeliveryPreferences(
        const NotificationDeliveryPreferences(),
        expectedState: current,
      );
      expect(actual.revision, 7);
      fixture.reply = _receipt(revision: 8);
      await expectLater(
        fixture.service.syncDeliveryPreferences(
          const NotificationDeliveryPreferences(),
          expectedState: current,
        ),
        throwsStateError,
      );
    },
  );

  for (final bad in [
    'owner',
    'desired',
    'synchronized',
    'revision',
    'missing',
    'contradictory',
  ]) {
    test('category strict setter rejects unverified $bad readback', () async {
      final fixture = await _AuthorityFixture.open();
      fixture.reply = _receipt(revision: 2, accepted: false);
      switch (bad) {
        case 'owner':
          fixture.reply!['owner_id'] = _otherOwner;
        case 'desired':
          fixture.reply!['friend_accepted_enabled'] = true;
        case 'synchronized':
          fixture.reply!['synchronized'] = false;
        case 'revision':
          fixture.reply!['revision'] = 1;
        case 'missing':
          fixture.reply!.remove('effective_message_enabled');
        case 'contradictory':
          fixture.reply!['effective_friend_accepted_enabled'] = true;
      }
      await expectLater(
        fixture.service.syncDeliveryPreferences(
          const NotificationDeliveryPreferences(
            enabledCategories: {
              NotificationCategory.newMessage,
              NotificationCategory.friendRequest,
            },
          ),
          expectedState: _state(_receipt()),
        ),
        throwsStateError,
      );
      expect(fixture.paths, [
        '/rest/v1/rpc/bil_set_my_push_delivery_categories_v1',
      ]);
    });
  }

  test(
    'category missing forward RPC never falls back to legacy/local success',
    () async {
      final fixture = await _AuthorityFixture.open();
      fixture.status = 404;
      fixture.reply = {
        'code': 'PGRST202',
        'message': 'Forward RPC unavailable',
      };
      await expectLater(
        fixture.service.loadDeliveryCategories(),
        throwsA(isA<PostgrestException>()),
      );
      expect(fixture.paths, [
        '/rest/v1/rpc/bil_get_my_push_delivery_categories_v1',
      ]);
    },
  );

  test(
    'category stale revision rejects without automatic replay then refreshes truth',
    () async {
      final fixture = await _AuthorityFixture.open();
      fixture.status = 409;
      fixture.reply = {
        'code': '40001',
        'message': 'push_delivery_preferences_conflict',
      };
      await expectLater(
        fixture.service.syncDeliveryPreferences(
          const NotificationDeliveryPreferences(enabledCategories: {}),
          expectedState: _state(_receipt()),
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'CAS code', '40001'),
        ),
      );
      expect(fixture.paths, [
        '/rest/v1/rpc/bil_set_my_push_delivery_categories_v1',
      ]);
      fixture.status = 200;
      fixture.reply = _receipt(revision: 2, request: false);
      final current = await fixture.service.loadDeliveryCategories();
      expect(
        current.desired!.contains(NotificationCategory.friendRequest),
        isFalse,
      );
      expect(current.revision, 2);
      expect(fixture.paths.where((p) => p.contains('bil_set_')), hasLength(1));
    },
  );

  test(
    'category owner switch before write cannot send old account intent',
    () async {
      final fixture = await _AuthorityFixture.open();
      final current = _state(_receipt());
      fixture.owner = _otherOwner;
      await fixture.signIn();
      await expectLater(
        fixture.service.syncDeliveryPreferences(
          const NotificationDeliveryPreferences(),
          expectedState: current,
        ),
        throwsA(isA<AuthException>()),
      );
      expect(fixture.paths, isEmpty);
    },
  );

  test(
    'category owner switch during deferred getter never acknowledges old receipt',
    () async {
      final fixture = await _AuthorityFixture.open();
      final returned = Completer<Map<String, dynamic>>();
      fixture.pending = returned.future;
      final response = fixture.service.loadDeliveryCategories();
      await Future<void>.delayed(Duration.zero);
      fixture.owner = _otherOwner;
      await fixture.signIn();
      returned.complete(_receipt());
      await expectLater(response, throwsA(isA<AuthException>()));
    },
  );
}

CommunityPushDeliveryCategories _state(Map<String, dynamic> receipt) =>
    CommunityPushDeliveryCategories.fromReceipt(
      receipt,
      expectedOwnerId: _owner,
    );

Map<String, dynamic> _receipt({
  bool initialized = true,
  int revision = 1,
  bool message = true,
  bool request = true,
  bool accepted = true,
}) => {
  'owner_id': _owner,
  'initialized': initialized,
  'revision': revision,
  'message_enabled': initialized ? message : null,
  'friend_request_enabled': initialized ? request : null,
  'friend_accepted_enabled': initialized ? accepted : null,
  'effective_message_enabled': false,
  'effective_friend_request_enabled': false,
  'effective_friend_accepted_enabled': false,
  'synchronized': initialized,
};

class _AuthorityFixture {
  late final SupabaseClient client;
  CommunityPushService get service => CommunityPushService(client);
  String owner = _owner;
  int status = 200;
  Map<String, dynamic>? reply;
  Future<Map<String, dynamic>>? pending;
  final paths = <String>[];
  final parameters = <Map<String, dynamic>>[];

  static Future<_AuthorityFixture> open() async {
    final fixture = _AuthorityFixture();
    fixture.client = SupabaseClient(
      'https://push-authority.invalid',
      'synthetic-fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body;
        var status = 200;
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({'sub': fixture.owner, 'exp': 4102444800}),
                ),
              )
              .replaceAll('=', '');
          body = {
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': fixture.owner,
              'email': 'fixture@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-04T00:00:00Z',
            },
          };
        } else {
          expect(request.headers['Authorization'], startsWith('Bearer ey'));
          fixture.paths.add(request.url.path);
          final requestBody = jsonDecode(request.body);
          fixture.parameters.add(
            requestBody == null
                ? <String, dynamic>{}
                : (requestBody as Map).cast<String, dynamic>(),
          );
          body = fixture.pending == null
              ? fixture.reply ?? _receipt()
              : await fixture.pending!;
          status = fixture.status;
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(fixture.client.dispose);
    await fixture.signIn();
    return fixture;
  }

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'synthetic-password',
    );
  }
}
