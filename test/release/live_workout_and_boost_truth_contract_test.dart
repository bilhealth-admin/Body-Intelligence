import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live workout surfaces do not promise unpublished video inventory', () {
    final paths = <String>[
      'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
      'lib/features/commerce/presentation/premium_route_glass_gate.dart',
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
      'lib/features/wellness/presentation/bil_workout_routines_states.dart',
    ];
    const forbidden = <String>[
      '300+ home workout videos',
      '100+ video-guided weight-training plans',
      '138 movement videos passed',
      '54 require media remediation',
      'None are playable yet',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      for (final phrase in forbidden) {
        expect(source, isNot(contains(phrase)), reason: '$path: $phrase');
      }
    }
  });

  test('AI Boost allowance is canonical across live surfaces', () {
    final coachAccess = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_components.dart',
    ).readAsStringSync();
    final store = File(
      'lib/features/commerce/presentation/bil_store_copy.dart',
    ).readAsStringSync();

    expect(coachAccess, contains('+2,500 BIL AI Tokens'));
    expect(coachAccess, isNot(contains('+5,000 BIL AI Tokens')));
    expect(store, contains("'boost_benefit_1': '2,500 BIL AI Coach tokens'"));
  });

  test('Daily check-in close persists the same skip-today decision', () {
    final source = File(
      'lib/features/daily_check_in/daily_check_in_page.dart',
    ).readAsStringSync();
    expect(source, contains("set('weightReminderSkippedDay'"));
    expect(
      source,
      contains('onPressed: saving || skipping ? null : skipToday'),
    );
  });
}
