import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/community/services/community_translation_service.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<SupabaseClient> clientFor(
  Future<http.Response> Function(http.Request) send,
) async {
  final client = SupabaseClient(
    'https://translation.invalid',
    'synthetic-publishable',
    httpClient: CommunityOwnerHttpClient(MockClient(send)),
  );
  final token = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': 'translation-owner', 'exp': 4102444800}),
        ),
      )
      .replaceAll('=', '');
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'e30.$token.synthetic',
      'refresh_token': 'synthetic-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': 'translation-owner',
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-10-18T00:00:00Z',
      },
    }),
  );
  return client;
}

void main() {
  test('a cancelled translation cannot enter the data transport', () async {
    var calls = 0;
    final client = await clientFor((_) async {
      calls++;
      return http.Response(
        '{"texts":{"body":"translated"},"engine":"google"}',
        200,
      );
    });
    addTearDown(client.dispose);
    final port = CloudCommunityTranslation(client: client);
    final pending = port.translate(
      requestId: 'cancel-before-send',
      texts: {'body': 'Private source'},
      targetTag: 'ar',
    );
    final rejected = expectLater(pending, throwsFormatException);
    await port.cancel('cancel-before-send');
    await rejected;
    expect(calls, 0);
  });

  for (final roundTrip in [false, true]) {
    test(
      'an account transition before send cannot transmit source text; ABA=$roundTrip',
      () async {
        var calls = 0;
        final client = await clientFor((_) async {
          calls++;
          return http.Response(
            '{"texts":{"body":"translated"},"engine":"google"}',
            200,
          );
        });
        addTearDown(client.dispose);
        final original = jsonEncode(client.auth.currentSession!.toJson());
        final next = jsonDecode(original) as Map<String, dynamic>;
        final payload = base64Url
            .encode(
              utf8.encode(jsonEncode({'sub': 'next-owner', 'exp': 4102444800})),
            )
            .replaceAll('=', '');
        next['access_token'] = 'e30.$payload.synthetic';
        (next['user'] as Map)['id'] = 'next-owner';
        final port = CloudCommunityTranslation(client: client);
        final pending = port.translate(
          requestId: 'owner-before-send',
          texts: {'body': 'Private source'},
          targetTag: 'ar',
        );
        final rejected = expectLater(pending, throwsFormatException);
        final changed = client.auth.recoverSession(jsonEncode(next));
        if (roundTrip) {
          final restored = client.auth.recoverSession(original);
          await Future.wait([changed, restored]);
        } else {
          await changed;
        }
        await rejected;
        expect(calls, 0);
      },
    );
  }

  test(
    'cloud request sends selected fields only and never calls a native translation sheet',
    () async {
      final requests = <http.Request>[];
      final client = await clientFor((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'texts': {'body': 'مرحبا'},
            'engine': 'google',
            'sameLanguage': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.dispose);
      final port = CloudCommunityTranslation(client: client);
      final result = await port.translate(
        requestId: 'visit',
        texts: {'body': 'Hello'},
        targetTag: 'ar',
      );
      expect(result.texts, {'body': 'مرحبا'});
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/functions/v1/community-translate');
      expect(jsonDecode(requests.single.body), {
        'texts': {'body': 'Hello'},
        'targetTag': 'ar',
      });
      expect(requests.single.headers['authorization'], startsWith('Bearer '));
    },
  );
  test('cancelled requests reject late cloud results', () async {
    final pending = Completer<http.Response>();
    final client = await clientFor((_) => pending.future);
    addTearDown(client.dispose);
    final port = CloudCommunityTranslation(client: client);
    final result = port.translate(
      requestId: 'visit',
      texts: {'body': 'Hello'},
      targetTag: 'ar',
    );
    final assertion = expectLater(result, throwsFormatException);
    await port.cancel('visit');
    pending.complete(
      http.Response('{"texts":{"body":"late"},"engine":"google"}', 200),
    );
    await assertion;
  });
  test(
    'missing fields and invalid engines cannot replace the original',
    () async {
      final client = await clientFor(
        (_) async => http.Response('{"texts":{},"engine":"apple"}', 200),
      );
      addTearDown(client.dispose);
      await expectLater(
        CloudCommunityTranslation(client: client).translate(
          requestId: 'bad',
          texts: {'body': 'Hello'},
          targetTag: 'ar',
        ),
        throwsFormatException,
      );
    },
  );
  test('signed-out client does not contact the provider', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://translation.invalid',
      'synthetic',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      CloudCommunityTranslation(
        client: client,
      ).translate(requestId: 'out', texts: {'body': 'Hello'}, targetTag: 'ar'),
      throwsFormatException,
    );
    expect(calls, 0);
  });
}
