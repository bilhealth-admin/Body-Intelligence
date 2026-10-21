import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/security/bil_mobile_integrity_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _id = 'coach-reconciliation-fixture-0001';

Map<String, Object?> _receipt(String state, {String requestId = _id}) => {
  'request_id': requestId,
  'capability': 'text',
  'state': state,
  'credit_actual': state == 'succeeded' ? 3 : 0,
  'credit_included_actual': state == 'succeeded' ? 3 : 0,
  'credit_paid_actual': 0,
  'completed_at': state == 'reserved' ? null : '2026-10-20T12:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lost reply after settlement: checking and repeated admission debit once',
    () async {
      final fixture = await _HttpFixture.open();
      addTearDown(fixture.dispose);
      final operation = fixture.operation(_id);
      final bound = bindCoachCloudRequest(fixture.gateway, operation);
      expect(
        (await _answer(bound)).status,
        CoachServiceStatus.temporarilyUnavailable,
      );
      expect(operation.submitted, isTrue);
      expect(await operation.reconcile(), CoachCloudRequestState.settled);
      expect(
        (await _answer(bound)).diagnosticCode,
        'request_reconciliation_required',
      );
      expect(fixture.providerCalls, 1);
      expect(fixture.settlements, 1);
      expect(fixture.charges, 1);
      expect(fixture.statusReads, 1);
      expect(fixture.requestIds, [_id]);
    },
  );

  test(
    'legacy control: independent retry IDs create two paid generations',
    () async {
      final fixture = await _HttpFixture.open();
      addTearDown(fixture.dispose);
      await _answer(fixture.gateway);
      await _answer(fixture.gateway);
      expect(fixture.providerCalls, 2);
      expect(fixture.charges, 2);
      expect(fixture.requestIds.toSet(), hasLength(2));
    },
  );

  for (final scenario in ['reserved', 'absent', 'query-failure']) {
    test('$scenario receipt never permits a second generation', () async {
      final fixture = await _HttpFixture.open(states: ['reserved']);
      addTearDown(fixture.dispose);
      final operation = fixture.operation(_id);
      final bound = bindCoachCloudRequest(fixture.gateway, operation);
      await _answer(bound);
      fixture.absent = scenario == 'absent';
      fixture.queryFailure = scenario == 'query-failure';
      expect(
        await operation.reconcile(),
        scenario == 'reserved'
            ? CoachCloudRequestState.pending
            : CoachCloudRequestState.unknown,
      );
      await _answer(bound);
      expect(fixture.providerCalls, 1);
      expect(fixture.settlements, 0);
      expect(fixture.charges, 0);
    });
  }

  test(
    'only confirmed zero-cost terminal refund permits a fresh paid attempt',
    () async {
      final fixture = await _HttpFixture.open(
        states: ['refunded', 'succeeded'],
      );
      addTearDown(fixture.dispose);
      final original = fixture.operation(_id);
      await _answer(bindCoachCloudRequest(fixture.gateway, original));
      expect(await original.reconcile(), CoachCloudRequestState.refunded);
      // The UI creates a fresh identity only after this terminal receipt.
      final replacement = fixture.operation(
        'coach-reconciliation-fixture-0002',
      );
      await _answer(bindCoachCloudRequest(fixture.gateway, replacement));
      expect(await replacement.reconcile(), CoachCloudRequestState.settled);
      expect(fixture.providerCalls, 2);
      expect(fixture.settlements, 2);
      expect(fixture.charges, 1);
      expect(fixture.requestIds.toSet(), hasLength(2));
    },
  );

  test(
    'account switch and A-B-A permanently fence the original status read',
    () async {
      final fixture = await _HttpFixture.open();
      addTearDown(fixture.dispose);
      final operation = fixture.operation(_id);
      final bound = bindCoachCloudRequest(fixture.gateway, operation);
      await _answer(bound);
      await fixture.switchOwner(_other);
      await fixture.switchOwner(_owner);
      expect(await operation.reconcile(), CoachCloudRequestState.unknown);
      await _answer(bound);
      expect(fixture.statusReads, 0);
      expect(fixture.providerCalls, 1);
      expect(fixture.charges, 1);
    },
  );

  test(
    'owner change while a status GET waits cannot accept the old receipt',
    () async {
      final fixture = await _HttpFixture.open();
      addTearDown(fixture.dispose);
      final operation = fixture.operation(_id);
      await _answer(bindCoachCloudRequest(fixture.gateway, operation));
      fixture.holdStatus = true;
      final checking = operation.reconcile();
      await fixture.statusEntered.future;
      await fixture.switchOwner(_other);
      fixture.statusRelease.complete();
      expect(await checking, CoachCloudRequestState.unknown);
      expect(fixture.providerCalls, 1);
      expect(fixture.charges, 1);
    },
  );

  test('malformed or inconsistent terminal receipts remain unknown', () async {
    for (final raw in <Object?>[
      null,
      {..._receipt('refunded'), 'request_id': 'another-request'},
      {..._receipt('refunded'), 'capability': 'vision'},
      {..._receipt('refunded'), 'credit_actual': 1},
      {..._receipt('refunded'), 'credit_paid_actual': 1},
      {..._receipt('refunded'), 'credit_included_actual': '0'},
      {..._receipt('refunded'), 'credit_paid_actual': false},
      {..._receipt('succeeded'), 'credit_included_actual': null},
      {..._receipt('succeeded'), 'credit_paid_actual': 1},
      {..._receipt('refunded'), 'completed_at': null},
      {..._receipt('refunded'), 'state': 'cancelled'},
    ]) {
      final operation = CoachCloudRequest(requestId: _id);
      expect(operation.beginSubmission(readReceipt: () async => raw), isTrue);
      expect(await operation.reconcile(), CoachCloudRequestState.unknown);
    }
  });

  test(
    'actual expiry refund receipt permits a fresh attempt with null allocations',
    () async {
      final operation = CoachCloudRequest(requestId: _id);
      operation.beginSubmission(
        readReceipt: () async => {
          ..._receipt('refunded'),
          'credit_included_actual': null,
          'credit_paid_actual': null,
        },
      );
      expect(await operation.reconcile(), CoachCloudRequestState.refunded);
    },
  );

  test(
    'expired reservation remains pending, never proof of released funding',
    () async {
      final operation = CoachCloudRequest(requestId: _id);
      operation.beginSubmission(
        readReceipt: () async => {
          ..._receipt('reserved'),
          'reservation_expires_at': '2000-01-01T00:00:00Z',
        },
      );
      expect(await operation.reconcile(), CoachCloudRequestState.pending);
    },
  );

  test(
    'status timeout remains unknown without permitting a second generation',
    () async {
      final delayed = Completer<Object?>();
      final operation = CoachCloudRequest(
        requestId: _id,
        statusTimeout: const Duration(milliseconds: 5),
      );
      expect(
        operation.beginSubmission(readReceipt: () => delayed.future),
        isTrue,
      );
      expect(await operation.reconcile(), CoachCloudRequestState.unknown);
      expect(operation.submitted, isTrue);
      expect(
        operation.beginSubmission(
          readReceipt: () async => _receipt('refunded'),
        ),
        isFalse,
      );
      delayed.complete(_receipt('succeeded'));
      // A late response does not reset admission or silently create another turn.
      expect(operation.beginSubmission(readReceipt: () async => null), isFalse);
      expect(await operation.reconcile(), CoachCloudRequestState.settled);
    },
  );

  test(
    'double status taps share one GET and admission is synchronous',
    () async {
      final receipt = Completer<Object?>();
      var reads = 0;
      final operation = CoachCloudRequest(requestId: _id);
      expect(
        operation.beginSubmission(
          readReceipt: () {
            reads++;
            return receipt.future;
          },
        ),
        isTrue,
      );
      expect(operation.beginSubmission(readReceipt: () async => null), isFalse);
      final first = operation.reconcile(), second = operation.reconcile();
      receipt.complete(_receipt('succeeded'));
      expect(await first, CoachCloudRequestState.settled);
      expect(await second, CoachCloudRequestState.settled);
      expect(reads, 1);
    },
  );
}

Future<LocalModelResult> _answer(LocalModelGateway gateway) => gateway.answer(
  question: 'Help me understand a balanced meal',
  locale: 'en',
  context: CoachContextSnapshot.empty(),
);

class _HttpFixture {
  _HttpFixture(this.states);
  final List<String> states;
  late Supabase supabase;
  late SupabaseClient client;
  bool visitCurrent = true,
      absent = false,
      queryFailure = false,
      holdStatus = false;
  int providerCalls = 0, settlements = 0, charges = 0, statusReads = 0;
  final requestIds = <String>[];
  final receipts = <String, Map<String, Object?>>{};
  final statusEntered = Completer<void>(), statusRelease = Completer<void>();

  LlamaCppLocalGateway get gateway => LlamaCppLocalGateway(
    mobileIntegrityService: BilMobileIntegrityService(
      integrityRequired: () => false,
    ),
  );
  CoachCloudRequest operation(String id) => CoachCloudRequest(
    requestId: id,
    isCurrent: () => visitCurrent && client.auth.currentUser?.id == _owner,
  );

  static Future<_HttpFixture> open({
    List<String> states = const ['succeeded'],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = _HttpFixture(states);
    final transport = MockClient(fixture.handle);
    fixture.supabase = await Supabase.initialize(
      url: 'https://coach-retry-bootstrap.invalid',
      publishableKey: 'synthetic-publishable',
      debug: false,
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
    await fixture.supabase.client.dispose();
    fixture.client = SupabaseClient(
      'https://coach-retry.invalid',
      'synthetic-publishable',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport,
    );
    fixture.supabase.client = fixture.client;
    await fixture.client.auth.recoverSession(jsonEncode(_session(_owner)));
    return fixture;
  }

  Future<void> switchOwner(String owner) async {
    if (owner != _owner) visitCurrent = false;
    await client.auth.recoverSession(jsonEncode(_session(owner)));
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    Object? response;
    if (path == '/rest/v1/rpc/bil_get_remote_ai_consent') {
      response = {'granted': true, 'policy_version': '3'};
    } else if (path == '/functions/v1/ai-coach') {
      final body = jsonDecode(request.body) as Map;
      final id = body['request_id'] as String;
      requestIds.add(id);
      providerCalls++;
      final state = states[(providerCalls - 1).clamp(0, states.length - 1)];
      receipts[id] = _receipt(state, requestId: id);
      if (state != 'reserved') settlements++;
      if (state == 'succeeded') charges++;
      // The provider/ledger succeeded, then the HTTP response was lost.
      throw http.ClientException('synthetic lost response', request.url);
    } else if (path == '/rest/v1/bil_ai_usage_events') {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['owner_id'], 'eq.$_owner');
      expect(request.url.queryParameters['capability'], 'eq.text');
      expect(
        request.url.queryParameters['select'],
        'request_id,capability,state,credit_actual,credit_included_actual,credit_paid_actual,completed_at',
      );
      statusReads++;
      if (holdStatus) {
        statusEntered.complete();
        await statusRelease.future;
      }
      if (queryFailure) {
        return http.Response('{"message":"synthetic unavailable"}', 503);
      }
      final id = request.url.queryParameters['request_id']!.substring(3);
      response = absent || !receipts.containsKey(id) ? [] : [receipts[id]];
    } else {
      throw StateError('Unexpected fixture route: $path');
    }
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Future<void> dispose() => supabase.dispose();
}

Map<String, Object?> _session(String owner) => {
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800}))).replaceAll('=', '')}.fixture',
  'refresh_token': 'synthetic-$owner',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': {},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2026-10-20T00:00:00Z',
  },
};
