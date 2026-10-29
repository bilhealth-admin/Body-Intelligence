import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _target = '33333333-3333-4333-8333-333333333333';
const _report = '44444444-4444-4444-8444-444444444444';

class _ReceiptFixture {
  String owner = _owner;
  Object response = [
    {'id': _report},
  ];
  int status = 201;
  final writes = <http.Request>[];
  Completer<void>? entered;
  Completer<void>? release;
  late final client = SupabaseClient(
    'https://report-receipt.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
              )
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$payload.synthetic',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': owner,
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-10-29T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.url.path, '/rest/v1/bil_community_reports');
        expect(request.method, 'POST');
        writes.add(request);
        entered?.complete();
        if (release != null) await release!.future;
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    ),
  );

  Future<void> signIn([String nextOwner = _owner]) async {
    owner = nextOwner;
    await client.auth.signInWithPassword(
      email: 'report-fixture@example.invalid',
      password: 'synthetic-password',
    );
  }

  Future<void> send() => CommunityRepository(client).report(
    targetKind: 'profile',
    targetId: _target,
    reason: 'other: Explicit QA note',
  );
}

void main() {
  test(
    'created report requests only its returned id in the same HTTP write',
    () async {
      final fixture = _ReceiptFixture();
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await fixture.send();
      expect(fixture.writes, hasLength(1));
      final request = fixture.writes.single;
      expect(request.url.queryParameters['select'], 'id');
      expect(request.headers['prefer'], contains('return=representation'));
      expect(jsonDecode(request.body), {
        'reporter_id': _owner,
        'target_kind': 'profile',
        'target_id': _target,
        'reason': 'other: Explicit QA note',
      });
    },
  );

  test(
    'server duplicate with zero returned rows has an explicit acknowledgement',
    () async {
      final fixture = _ReceiptFixture()..response = <Object>[];
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await expectLater(
        fixture.send(),
        throwsA(isA<CommunityReportAlreadyPending>()),
      );
      expect(fixture.writes, hasLength(1));
    },
  );

  for (final invalid in <Object>[
    [{}],
    [
      {'id': 'not-a-report-id'},
    ],
    [
      {'id': _report},
      {'id': _target},
    ],
  ]) {
    test(
      'malformed insert representation cannot claim report success: $invalid',
      () async {
        final fixture = _ReceiptFixture()..response = invalid;
        addTearDown(fixture.client.dispose);
        await fixture.signIn();
        await expectLater(fixture.send(), throwsFormatException);
        expect(fixture.writes, hasLength(1));
      },
    );
  }

  for (final code in ['42501', '23505', 'P0001']) {
    test(
      'server $code stays a failure rather than an already-reported acknowledgement',
      () async {
        final fixture = _ReceiptFixture()
          ..status = 403
          ..response = {'code': code, 'message': 'controlled_failure'};
        addTearDown(fixture.client.dispose);
        await fixture.signIn();
        await expectLater(
          fixture.send(),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        expect(fixture.writes, hasLength(1));
      },
    );
  }

  for (final duplicate in [false, true]) {
    test(
      'owner A-B-A retires a delayed ${duplicate ? 'duplicate' : 'created'} receipt',
      () async {
        final fixture = _ReceiptFixture()
          ..entered = Completer<void>()
          ..release = Completer<void>();
        if (duplicate) fixture.response = <Object>[];
        addTearDown(fixture.client.dispose);
        await fixture.signIn();
        final pending = fixture.send();
        final assertion = expectLater(
          pending,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await fixture.entered!.future;
        await fixture.signIn(_otherOwner);
        await fixture.signIn(_owner);
        fixture.release!.complete();
        await assertion;
        expect(fixture.writes, hasLength(1));
      },
    );
  }

  test(
    'unauthenticated server denial cannot become an already-reported notice',
    () async {
      final fixture = _ReceiptFixture()
        ..status = 403
        ..response = {'code': '42501', 'message': 'authentication_required'};
      addTearDown(fixture.client.dispose);
      expect(fixture.client.auth.currentUser, isNull);
      await expectLater(
        fixture.send(),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            '42501',
          ),
        ),
      );
      expect(fixture.writes, hasLength(1));
      expect(
        (jsonDecode(fixture.writes.single.body) as Map)['reporter_id'],
        isNull,
      );
    },
  );
}
