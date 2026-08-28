import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed-test access is server issued and auditable', () {
    final sql = File(
      'supabase/migrations/20260820115847_ai_coach_closed_test_feedback_and_consent.sql',
    ).readAsStringSync();

    expect(sql, contains('public.bil_ai_closed_test_grants'));
    expect(sql, contains('public.bil_set_ai_closed_test_access'));
    expect(sql, contains("auth.role() <> 'service_role'"));
    expect(sql, contains('to service_role;'));
    expect(
      sql,
      isNot(
        contains(
          'bil_set_ai_closed_test_access(\n  uuid, text, boolean, timestamptz, text\n) to authenticated',
        ),
      ),
    );
    expect(sql, contains("provider in ('google', 'apple', 'closed_test')"));
    expect(sql, contains('bil_ai_closed_test_grants_read_own'));
  });

  test('AI Coach follow-up hardens RLS and removes deprecated role checks', () {
    final sql = File(
      'supabase/migrations/20260820172843_ai_coach_rls_and_consent_invoker.sql',
    ).readAsStringSync();

    expect(sql, contains('owner_id = (select auth.uid())'));
    expect(sql, contains('bil_get_remote_ai_consent() security invoker'));
    expect(sql, contains('bil_set_ai_closed_test_access'));
    expect(sql, isNot(contains('auth.role()')));
    expect(sql, contains('to service_role;'));
  });

  test(
    'remote AI is server consent gated and feedback stores no conversation text',
    () {
      final sql = File(
        'supabase/migrations/20260820115847_ai_coach_closed_test_feedback_and_consent.sql',
      ).readAsStringSync();
      final server = File(
        'supabase/functions/ai-coach/server.ts',
      ).readAsStringSync();
      final gateway = File(
        'lib/features/intelligence_center/services/local_model_gateway_io.dart',
      ).readAsStringSync();

      expect(sql, contains('bil_get_remote_ai_consent'));
      expect(sql, contains('bil_has_remote_ai_consent'));
      expect(server, contains('bil_has_remote_ai_consent'));
      expect(server, contains('code === "ai_consent_required"'));
      expect(
        gateway,
        isNot(contains("client.rpc('bil_get_remote_ai_consent')")),
      );
      expect(gateway, contains('authoritative consent gate'));
      expect(gateway, contains("'ai-coach'"));
      expect(sql, contains('public.bil_ai_coach_feedback'));
      expect(sql, contains('public.bil_ai_usage_events'));
      expect(sql, contains("e.state = 'succeeded'"));
      expect(sql, isNot(contains('question_text')));
      expect(sql, isNot(contains('answer_text')));
      expect(sql, isNot(contains('conversation')));
    },
  );
}
