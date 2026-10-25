import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIL-05 Goals exposes Back with a safe cold-route destination', () {
    final source = File(
      'lib/features/settings/reference_goals_page.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("BilSafeReturnButton(fallbackLocation: '/dashboard')"),
    );
    // Do not allow a route exit to bypass an in-progress Goals save.
    expect(source, contains('leading: saving'));
    expect(source, contains('onPressed: null, icon: BackButtonIcon()'));
  });

  test('BIL-14/BIL-18 Steps uses a push stack and safe root fallback', () {
    final settings = File(
      'lib/features/connected_health/steps_settings_page.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/connected_health/steps_history_page.dart',
    ).readAsStringSync();
    expect(
      settings,
      contains("context.push('/connected-health/steps/history')"),
    );
    expect(
      settings,
      isNot(contains("context.go('/connected-health/steps/history')")),
    );
    expect(history, contains('BilSafeReturnButton('));
    expect(history, contains("fallbackLocation: '/connected-health/steps'"));
  });

  test(
    'BIL-20 direct health and language routes have fixed fallback paths',
    () {
      final routes = <String, String>{
        'lib/features/connected_health/connected_health_signal_detail_page.dart':
            '/connected-health',
        'lib/features/connected_health/partner_capabilities_page.dart':
            '/connected-health',
        'lib/features/settings/language_settings_page.dart': '/settings',
      };
      for (final entry in routes.entries) {
        final source = File(entry.key).readAsStringSync();
        expect(source, contains('BilSafeReturnButton('), reason: entry.key);
        expect(
          source,
          contains("fallbackLocation: '${entry.value}'"),
          reason: entry.key,
        );
      }
    },
  );

  test('BIL-10 only Smart Plan session media returns past the library', () {
    final actions = File(
      'lib/features/smart_plan/presentation/bil_smart_plan_actions.dart',
    ).readAsStringSync();
    final routes = File(
      'lib/app/router/app_wellness_routes.dart',
    ).readAsStringSync();
    final library = File(
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
    ).readAsStringSync();

    // The ordinary library entry remains unchanged; the live session opts in.
    expect(
      actions,
      contains(
        'openExercise: (id) => _openExercise(id, returnToSession: true)',
      ),
    );
    expect(
      actions,
      contains(r"returnToSession ? '$route&returnToSession=1' : route"),
    );
    expect(
      routes,
      contains("state.uri.queryParameters['returnToSession'] == '1'"),
    );
    expect(library, contains('this.returnToCallerAfterInitialItem = false'));
    expect(library, contains('await _openDetails(item);'));
    expect(library, contains('!widget.returnToCallerAfterInitialItem'));
    expect(library, contains('ModalRoute.of(context)?.isCurrent == true'));
    expect(library, contains('context.pop();'));
  });
}
