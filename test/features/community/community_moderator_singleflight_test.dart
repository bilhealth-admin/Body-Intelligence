import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _first = '11111111-1111-4111-8111-111111111111';
const _second = '22222222-2222-4222-8222-222222222222';

void main() {
  test(
    'identical card role reads share one actual RPC per authenticated session',
    () async {
      var owner = _first;
      var tokenVersion = 1;
      var failNext = false;
      final queries = <String>[];
      Completer<bool>? pending = Completer<bool>();
      final client = SupabaseClient(
        'https://moderator-singleflight.invalid',
        'synthetic-fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object body;
          if (request.url.path == '/auth/v1/token') {
            final payload = base64Url
                .encode(
                  utf8.encode(
                    jsonEncode({
                      'sub': owner,
                      'exp': 4102444800,
                      'session_version': tokenVersion,
                    }),
                  ),
                )
                .replaceAll('=', '');
            body = {
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': owner,
                'email': 'fixture@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-10-04T00:00:00Z',
              },
            };
          } else {
            expect(request.url.path, '/rest/v1/rpc/bil_is_community_moderator');
            expect(request.headers['Authorization'], startsWith('Bearer ey'));
            queries.add(owner);
            if (failNext) {
              failNext = false;
              return http.Response(
                jsonEncode({'message': 'Synthetic failure'}),
                500,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            body = pending == null ? owner == _first : await pending.future;
          }
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'synthetic-password',
      );
      final repository = CommunityRepository(client);
      // Every actual post card makes this same role lookup; use16 concurrent
      // calls without replacing the production repository/RPC implementation.
      final cards = List.generate(16, (_) => repository.isCommunityModerator());
      await Future<void>.delayed(Duration.zero);
      pending.complete(true);
      expect(await Future.wait(cards), everyElement(isTrue));
      expect(
        queries,
        [_first],
        reason: 'Card count must not multiply identical authorization queries.',
      );
      pending = null;
      expect(await repository.isCommunityModerator(), isTrue);
      expect(queries, [_first]);

      owner = _second;
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'synthetic-password',
      );
      expect(await repository.isCommunityModerator(), isFalse);
      expect(
        queries,
        [_first, _second],
        reason: 'A different authenticated owner must never reuse cached role.',
      );

      tokenVersion++;
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'synthetic-password',
      );
      expect(await repository.isCommunityModerator(), isFalse);
      expect(
        queries,
        [_first, _second, _second],
        reason: 'A new auth session must revalidate even for the same owner.',
      );
      repository.invalidateCommunityModeratorStatus();
      final stale = Completer<bool>();
      pending = stale;
      final oldLookup = repository.isCommunityModerator();
      await Future<void>.delayed(Duration.zero);
      repository.invalidateCommunityModeratorStatus();
      pending = null;
      expect(await repository.isCommunityModerator(), isFalse);
      stale.complete(true);
      expect(
        await oldLookup,
        isFalse,
        reason: 'A late positive before explicit refresh is not current proof.',
      );
      expect(queries, [_first, _second, _second, _second, _second]);

      repository.invalidateCommunityModeratorStatus();
      failNext = true;
      await expectLater(
        repository.isCommunityModerator(),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await repository.isCommunityModerator(),
        isFalse,
        reason: 'A failed lookup must fail closed and permit a real retry.',
      );
      expect(queries, [
        _first,
        _second,
        _second,
        _second,
        _second,
        _second,
        _second,
      ]);
    },
  );
}
