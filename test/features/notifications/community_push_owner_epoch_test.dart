import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_push_delivery_categories.dart';
import 'package:body_intelligence_log/features/notifications/domain/notification_delivery_preferences.dart';
import 'package:body_intelligence_log/features/notifications/services/community_push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/support/community_rewards_rpc_fixture.dart';

// Real Supabase auth/RPC and the production transport fence, with no network,
// provider, credentials or real-user notification tokens.
void main() {
  for (final roundTrip in [false, true]) {
    for (final stage in ['policy-read', 'capability', 'token', 'timezone']) {
      test('refresh retires pending $stage at ABA=$roundTrip', () async {
        final fixture = await _PushFixture.open();
        fixture.pauseAt = stage;
        final pending = fixture.service.refreshRegistrationIfEnabled(
          deliveryPreferences: const NotificationDeliveryPreferences(),
        );
        final assertion = expectLater(pending, throwsA(isA<AuthException>()));
        await fixture.entered.future;
        await fixture.changeOwner(roundTrip);
        fixture.release.complete();
        await assertion;
        expect(fixture.requests, isEmpty);
        expect(fixture.tokens.requestCalls, 0);
      });
    }

    test('master disable cannot disable a later account ABA=$roundTrip', () async {
      final fixture = await _PushFixture.open();
      fixture.pauseAt = 'policy-write';
      final pending = fixture.service.setEnabled(
        false,
        deliveryPreferences: const NotificationDeliveryPreferences(),
      );
      final assertion = expectLater(pending, throwsA(isA<AuthException>()));
      await fixture.entered.future;
      await fixture.changeOwner(roundTrip);
      fixture.release.complete();
      await assertion;
      expect(fixture.requests, isEmpty);
      expect(fixture.tokens.deleteCalls, 0);
      expect(fixture.policy.disabled[rewardsOwnerA], isFalse);
    });

    test('explicit enable cannot register for another visit ABA=$roundTrip', () async {
      final fixture = await _PushFixture.open();
      fixture.pauseAt = 'request-token';
      final pending = fixture.service.setEnabled(
        true,
        deliveryPreferences: const NotificationDeliveryPreferences(),
      );
      final assertion = expectLater(pending, throwsA(isA<AuthException>()));
      await fixture.entered.future;
      await fixture.changeOwner(roundTrip);
      fixture.release.complete();
      await assertion;
      expect(fixture.requests, isEmpty);
      expect(fixture.tokens.requestCalls, 1);
    });

    for (final mutation in [false, true]) {
      test('category receipt cannot acknowledge retired visit mutation=$mutation ABA=$roundTrip', () async {
        final fixture = await _PushFixture.open();
        fixture.pauseAt = 'rpc';
        final pending = mutation
            ? fixture.service.syncDeliveryPreferences(
                const NotificationDeliveryPreferences(),
                expectedState: CommunityPushDeliveryCategories.fromReceipt(
                  _receipt(),
                  expectedOwnerId: rewardsOwnerA,
                ),
              )
            : fixture.service.loadDeliveryCategories();
        final assertion = expectLater(pending, throwsA(isA<AuthException>()));
        await fixture.entered.future;
        await fixture.changeOwner(roundTrip);
        fixture.release.complete();
        await assertion;
        expect(fixture.requests.single.owner, rewardsOwnerA);
      });
    }
  }

  test('same owner silently refreshes existing token without permission request', () async {
    final fixture = await _PushFixture.open();
    await fixture.service.refreshRegistrationIfEnabled(
      deliveryPreferences: const NotificationDeliveryPreferences(),
    );
    expect(fixture.requests.single.method, 'bil_register_push_token_v2');
    expect(fixture.requests.single.owner, rewardsOwnerA);
    expect(fixture.requests.single.params, {
      'p_token': 'synthetic-device-token',
      'p_platform': 'fcm',
      'p_timezone': 'Europe/London',
      'p_sensitive_preview_allowed': false,
      'p_message_enabled': true,
      'p_friend_request_enabled': true,
      'p_friend_accepted_enabled': true,
    });
    expect(fixture.tokens.requestCalls, 0);
  });

  test('current owner explicit optout never reads or registers provider token', () async {
    final fixture = await _PushFixture.open();
    fixture.policy.disabled[rewardsOwnerA] = true;
    await fixture.service.refreshRegistrationIfEnabled(
      deliveryPreferences: const NotificationDeliveryPreferences(),
    );
    expect(fixture.requests, isEmpty);
    expect(fixture.tokens.capabilityCalls, 0);
    expect(fixture.tokens.requestCalls, 0);
  });

  test('same owner disable persists optout and disables only its token', () async {
    final fixture = await _PushFixture.open();
    await fixture.service.setEnabled(
      false,
      deliveryPreferences: const NotificationDeliveryPreferences(),
    );
    expect(fixture.requests.single.method, 'bil_disable_push_tokens');
    expect(fixture.requests.single.owner, rewardsOwnerA);
    expect(fixture.policy.disabled[rewardsOwnerA], isTrue);
    expect(fixture.tokens.deleteCalls, 1);
  });

  test('server disable failure rolls back local intent without deleting token', () async {
    final fixture = await _PushFixture.open();
    fixture.failure = true;
    await expectLater(
      fixture.service.setEnabled(
        false,
        deliveryPreferences: const NotificationDeliveryPreferences(),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(fixture.policy.disabled[rewardsOwnerA], isFalse);
    expect(fixture.tokens.deleteCalls, 0);
  });
}

Map<String, Object?> _receipt() => {
  'owner_id': rewardsOwnerA,
  'initialized': true,
  'revision': 1,
  'message_enabled': true,
  'friend_request_enabled': true,
  'friend_accepted_enabled': true,
  'effective_message_enabled': false,
  'effective_friend_request_enabled': false,
  'effective_friend_accepted_enabled': false,
  'synchronized': true,
};

class _PushFixture {
  late final SupabaseClient client;
  late final _Policy policy = _Policy(this);
  late final _Tokens tokens = _Tokens(this);
  late final CommunityPushService service = CommunityPushService(
    client,
    tokenProvider: tokens,
    registrationPolicyStore: policy,
    availability: () => true,
    timeZoneIdentifier: () async {
      await pause('timezone');
      return 'Europe/London';
    },
  );
  final requests = <({String method, String owner, Map<String, dynamic> params})>[];
  final entered = Completer<void>();
  final release = Completer<void>();
  String? pauseAt;
  bool failure = false;

  static Future<_PushFixture> open() async {
    final fixture = _PushFixture();
    fixture.client = SupabaseClient(
      'https://push-owner-fixture.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(fixture.respond)),
    );
    await fixture.client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
    addTearDown(fixture.client.dispose);
    return fixture;
  }

  Future<void> changeOwner(bool roundTrip) async {
    await client.auth.recoverSession(jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)));
    if (roundTrip) {
      await client.auth.recoverSession(jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)));
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> pause(String stage) async {
    if (pauseAt != stage) return;
    pauseAt = null;
    entered.complete();
    await release.future;
  }

  Future<http.Response> respond(http.Request request) async {
    final token = request.headers['authorization']!.split(' ').last;
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1])))) as Map;
    final decoded = jsonDecode(request.body);
    requests.add((
      method: request.url.pathSegments.last,
      owner: claims['sub'] as String,
      params: decoded == null ? {} : (decoded as Map).cast<String, dynamic>(),
    ));
    await pause('rpc');
    return http.Response(
      jsonEncode(failure ? {'message': 'Synthetic failed write'} : _receipt()),
      failure ? 503 : 200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _Policy extends CommunityPushRegistrationPolicyStore {
  _Policy(this.fixture);
  final _PushFixture fixture;
  final disabled = <String, bool>{};

  @override
  Future<bool> isExplicitlyDisabled(String userId) async {
    await fixture.pause('policy-read');
    return disabled[userId] ?? false;
  }

  @override
  Future<void> setExplicitlyDisabled(String userId, bool value) async {
    await fixture.pause('policy-write');
    disabled[userId] = value;
  }
}

class _Tokens implements PushTokenProvider {
  _Tokens(this.fixture);
  final _PushFixture fixture;
  int capabilityCalls = 0;
  int requestCalls = 0;
  int deleteCalls = 0;

  @override
  Future<PushProviderCapability> capability() async {
    capabilityCalls++;
    await fixture.pause('capability');
    return const PushProviderCapability(
      configured: true,
      tokenRegistration: true,
      remoteTapRouting: true,
      permissionGranted: true,
      provider: 'synthetic',
    );
  }

  @override
  Future<String?> existingPermissionToken() async {
    await fixture.pause('token');
    return 'synthetic-device-token';
  }

  @override
  Future<String?> requestToken() async {
    requestCalls++;
    await fixture.pause('request-token');
    return 'synthetic-device-token';
  }

  @override
  Future<void> deleteToken() async {
    deleteCalls++;
  }
}
