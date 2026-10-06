import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/services/community_entry_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _code = 'aabbccddaabbccddaabbccddaabbccdd';

class _Transport {
  Map<String, Object?>? profile;
  final requests = <http.Request>[];
  bool insertConcurrent = false;
  bool failCode = false;
  String owner = _owner;
  late final SupabaseClient client = SupabaseClient(
    'https://entry-rpc.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      Object? body;
      var status = 200;
      if (request.url.path == '/auth/v1/token') {
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
            .replaceAll('=', '');
        body = {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'email': 'fixture@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-05T00:00:00Z',
          },
        };
      } else if (request.url.path == '/rest/v1/bil_public_profiles') {
        if (request.method == 'POST') {
          expect(request.url.queryParameters['on_conflict'], 'user_id');
          expect(
            request.headers['prefer'],
            contains('resolution=ignore-duplicates'),
          );
          final incoming = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          expect(incoming['user_id'], _owner);
          expect(incoming.keys, isNot(contains('avatar_url')));
          expect(incoming.keys, isNot(contains('bio')));
          expect(incoming.keys, isNot(contains('handle')));
          expect(incoming.keys, isNot(contains('policy_version')));
          if (insertConcurrent) {
            profile = {
              'user_id': _owner,
              'display_name': 'Other device name',
              'locale_code': 'fr',
              'discoverable': false,
              'profile_visibility': 'private',
              'allow_friend_requests': false,
              'allow_follows': false,
              'allow_messages_from': 'nobody',
            };
          }
          profile ??= incoming;
          body = null;
          status = 201;
        } else {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['user_id'], 'eq.$owner');
          body = profile == null ? [] : [profile];
        }
      } else if (request.url.path.endsWith('/rpc/bil_social_public_code_v2')) {
        if (failCode) {
          body = {'code': 'P0001', 'message': 'synthetic_code_unavailable'};
          status = 503;
        } else {
          body = {
            'code': _code,
            'uri': 'bil://community/member/$_code',
            'handle': 'member_qa',
          };
        }
      } else if (request.url.path == '/auth/v1/logout') {
        body = {};
      } else {
        throw StateError(
          'Unexpected external operation: ${request.method} ${request.url.path}',
        );
      }
      return http.Response(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  Future<void> signIn() => client.auth.signInWithPassword(
    email: 'fixture@example.invalid',
    password: 'synthetic-password',
  );
}

void main() {
  test(
    'real transport is create-only, owner-bound and privacy-safe; code is server-issued',
    () async {
      final t = _Transport();
      addTearDown(t.client.dispose);
      await t.signIn();
      final receipt = await CommunityEntryCoordinator(
        CommunityRepository(t.client),
      ).save(displayName: ' Alex ', localeCode: 'en');
      expect(receipt.profile.displayName, 'Alex');
      expect(receipt.code.code, _code);
      expect(t.profile!['discoverable'], false);
      expect(t.profile!['profile_visibility'], 'friends');
      expect(t.profile!['allow_follows'], false);
      expect(t.profile!['allow_messages_from'], 'friends');
      expect(
        t.requests
            .where((r) => r.url.path.startsWith('/rest/'))
            .map((r) => '${r.method} ${r.url.path}'),
        [
          'GET /rest/v1/bil_public_profiles',
          'POST /rest/v1/bil_public_profiles',
          'GET /rest/v1/bil_public_profiles',
          'POST /rest/v1/rpc/bil_social_public_code_v2',
        ],
      );
    },
  );
  test(
    'concurrent profile creation does not overwrite stored name or privacy',
    () async {
      final t = _Transport()..insertConcurrent = true;
      addTearDown(t.client.dispose);
      await t.signIn();
      final receipt = await CommunityEntryCoordinator(
        CommunityRepository(t.client),
      ).save(displayName: 'Alex', localeCode: 'en');
      expect(receipt.profile.displayName, 'Other device name');
      expect(receipt.profile.visibility, CommunityProfileVisibility.private);
      expect(receipt.profile.allowFriendRequests, false);
      expect(receipt.profile.localeCode, 'fr');
    },
  );
  test('wrong expected owner is rejected before REST write', () async {
    final t = _Transport();
    addTearDown(t.client.dispose);
    await t.signIn();
    await expectLater(
      CommunityRepository(t.client).createMyCommunityEntryProfile(
        displayName: 'Alex',
        localeCode: 'en',
        expectedOwnerId: _other,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(t.requests.where((r) => r.url.path.startsWith('/rest/')), isEmpty);
  });
  test('unsupported locale rejects entry before REST write', () async {
    final t = _Transport();
    addTearDown(t.client.dispose);
    await t.signIn();
    await expectLater(
      CommunityRepository(t.client).createMyCommunityEntryProfile(
        displayName: 'Alex',
        localeCode: 'xx',
        expectedOwnerId: _owner,
      ),
      throwsFormatException,
    );
    expect(t.requests.where((r) => r.url.path.startsWith('/rest/')), isEmpty);
  });
}
