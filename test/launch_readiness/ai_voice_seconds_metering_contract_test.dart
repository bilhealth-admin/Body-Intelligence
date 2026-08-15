import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid backend voice reserves estimate and settles actual seconds', () {
    final sql = File(
      'supabase/migrations/202608110007_bil_ai_voice_actual_seconds.sql',
    ).readAsStringSync();

    expect(sql, contains('p_estimated_seconds::numeric/60'));
    expect(sql, contains('p_actual_seconds::numeric/60'));
    expect(sql, contains('voice_actual_exceeds_reservation'));
    expect(sql, contains('v_week_actual:=least'));
    expect(sql, contains('v_paid_actual:=v_actual_units-v_week_actual'));
    expect(sql, contains('reserved=greatest(reserved-v_event.weekly_debit,0)'));
    expect(sql, contains('reserved=greatest(reserved-v_event.paid_debit,0)'));
    expect(sql, contains("auth.role()<>'service_role'"));
    expect(sql, isNot(contains('speech_to_text')));
    expect(sql, isNot(contains('flutter_tts')));
  });
}
