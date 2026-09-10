import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../support/read_push_dispatcher.dart';

void main() {
  const dispatchPaths = <String>[
    'supabase/functions/community-push-dispatch/index.ts',
    'supabase/functions/community_push_dispatch.ts',
  ];

  test('push entry points share one implementation and fail closed', () {
    final sources = dispatchPaths
        .map(readPushDispatcherImplementation)
        .toList(growable: false);
    expect(sources[0], sources[1]);

    final source = sources.first;
    final secretRead = source.indexOf(
      'const dispatchSecret = readEnv("BIL_INTERNAL_DISPATCH_SECRET")',
    );
    final missingSecretGuard = source.indexOf('if (!dispatchSecret)');
    final headerComparison = source.indexOf(
      'request.headers.get("x-bil-dispatch-secret")',
    );
    expect(secretRead, greaterThanOrEqualTo(0));
    expect(missingSecretGuard, greaterThan(secretRead));
    expect(headerComparison, greaterThan(missingSecretGuard));
    expect(source, contains('!await secretMatches('));
    expect(source, contains('timingSafeEqual('));
    expect(source, contains('request.method !== "POST"'));
    expect(source, contains('parsed.protocol === "https:"'));
    expect(source, contains('redirect: "error"'));
    expect(
      source,
      isNot(contains('event.category === "ai_coach"')),
      reason:
          'AI coach text can contain private health context and must obey '
          'the lock-screen preview preference.',
    );
  });

  test('push delivery is leased per token and gateway calls are bounded', () {
    final source = readPushDispatcherImplementation(dispatchPaths.first);

    expect(source, contains('bil_claim_push_deliveries'));
    expect(source, contains('bil_record_push_delivery_result'));
    expect(source, contains('bil_finalize_push_outbox'));
    expect(source, isNot(contains('.from("bil_push_device_tokens")')));
    expect(source, contains('Promise.all'));
    expect(source, contains('new AbortController()'));
    expect(source, contains('controller.abort()'));
    expect(source, contains('clearTimeout(timeout)'));
    expect(source, contains('"gateway_timeout"'));
    expect(source, contains('"gateway_network_error"'));
    expect(source, contains('"idempotency-key": token.delivery_key'));
    expect(source, contains('idempotency_key: token.delivery_key'));
    expect(source, contains('provider_token: string'));
    expect(source, contains('token: token.provider_token'));
    expect(source, contains('x-bil-token-status'));
    expect(source, contains('[400, 404, 410].includes(response.status)'));
    expect(source, contains('p_permanent_token_failure'));
  });

  test('unpublished migration bounds retries and terminal delivery', () {
    final sql = File(
      'supabase/migrations/20260904040000_push_delivery_idempotency.sql',
    ).readAsStringSync();

    expect(sql, contains('primary key (outbox_id, device_token_id)'));
    expect(sql, contains('for update of attempt skip locked'));
    expect(sql, contains('limit 100'));
    expect(sql, contains('bil_push_delivery_policy'));
    expect(sql, contains('max_attempts integer not null default 5'));
    expect(sql, contains('base_backoff_seconds'));
    expect(sql, contains('max_backoff_seconds'));
    expect(sql, contains('attempt.attempt_count < v_max_attempts'));
    expect(sql, contains('attempt.next_attempt_at <='));
    expect(sql, contains('v_attempt_count >= v_max_attempts'));
    expect(sql, contains('pg_catalog.power'));
    expect(sql, contains('terminal_at'));
    expect(sql, contains('permanent_token_failure'));
    expect(sql, contains('set enabled = false'));
    expect(sql, contains('p_permanent_token_failure'));
    expect(
      sql,
      contains('if not found or v_existing_delivered_at is not null'),
    );
    expect(sql, contains('bil_finalize_push_outbox'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('from public, anon, authenticated, service_role'));
    expect(sql, contains('to service_role'));
    expect(sql, contains("set search_path = ''"));
    expect(
      RegExp(
        r"security definer\s+set search_path = ''",
        multiLine: true,
      ).allMatches(sql).length,
      3,
    );
    expect(sql, contains('despite the legacy column name'));
    expect(sql, contains('not application-layer ciphertext'));
  });
}
