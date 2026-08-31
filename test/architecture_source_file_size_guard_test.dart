import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hand-maintained Dart sources stay below the architecture ceiling', () async {
    const maximumLines = 700;
    const reviewedCeilings = <String, int>{
      // These are audited locale data catalogs rather than runtime
      // coordinators or UI surfaces. Keeping each 25-locale matrix intact
      // preserves source/placeholder reviewability; behavior lives elsewhere.
      'lib/app/localization/runtime_copy_profile.dart': 1300,
      'lib/app/localization/runtime_copy_release_closure.dart': 1075,
      'lib/features/profile/profile_locale_copy.dart': 875,
      // This part owns one cohesive phone composition. Its reusable cards,
      // goal controls, and discover sections already live in sibling parts;
      // the remaining 23 lines avoid splitting a single build hierarchy.
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart': 725,
      // These Community part files each own one cohesive stateful surface;
      // their repositories, models, taxonomy, and long locale copy already
      // live in separate files. Keep only a narrow 25-line review margin.
      'lib/features/community/presentation/community_connections_page.dart':
          725,
      'lib/features/community/presentation/community_messages_page.dart': 725,
      // Voice capture is one seek-safe conversation lifecycle. Recognition,
      // silence detection, placeholder reconciliation, and cancellation must
      // remain in the same State extension to preserve ordering guarantees.
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart':
          750,
      // This source is a data-only 25-locale food/serving lookup; splitting
      // it would obscure the audited completeness matrix without reducing
      // runtime responsibility.
      'lib/features/nutrition/services/food_presentation_localizer.dart': 1250,
      // Cohesive visual component libraries, already separated from state,
      // repositories, and domain logic. Allow only a small review margin.
      'lib/features/nutrition_plans/presentation/diet_plan_editor_components.dart':
          725,
      // Weekly reporting is already separated into engine, provider, body,
      // food, locale copy, and this render-only component library. Keep a
      // narrow ceiling around the audited chart/painter collection.
      'lib/features/analytics/weekly_report_components.dart': 950,
      // The reference goal file is a render-only family whose private
      // calorie and macro value objects share one layout contract.
      'lib/features/dashboard/widgets/dashboard_reference_goal_components.dart':
          750,
      // These stateful surfaces each coordinate one guarded form lifecycle;
      // persistence, permission probing, repositories, and locale copy are
      // already separate. Splitting the State across extensions would hide
      // the ordering guarantees without creating a runtime boundary.
      'lib/features/notifications/presentation/notification_settings_page.dart':
          800,
      'lib/features/nutrition/food_page.dart': 750,
      'lib/features/wellness/presentation/fasting_timer_page.dart': 800,
      'lib/features/wellness/presentation/sleep_tracker_experience.dart': 900,
      // Notification delivery is one platform scheduling coordinator;
      // permissions, copy, preferences, and UI remain in sibling files.
      'lib/features/notifications/services/bil_notification_service.dart': 925,
      // These are render-only catalog libraries. Data, verification,
      // entitlement, cache, manifests, and content management are separate.
      'lib/features/wellness/presentation/bil_workout_routines_list.dart': 725,
      'lib/features/wellness/presentation/recipe_library_page.dart': 850,
    };

    final oversized = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final path = entity.path.replaceAll(Platform.pathSeparator, '/');
      final generated = entity
          .openRead(0, 160)
          .transform(const SystemEncoding().decoder)
          .join()
          .then((header) => header.contains('GENERATED FILE'));
      if (path.endsWith('.g.dart') || await generated) {
        continue;
      }

      final lines = entity.readAsLinesSync().length;
      final reviewedCeiling = reviewedCeilings[path] ?? maximumLines;
      if (lines > reviewedCeiling) oversized.add('$path ($lines lines)');
    }

    expect(
      oversized,
      isEmpty,
      reason:
          'Split oversized sources by responsibility. If a cohesive boundary '
          'must exceed $maximumLines lines, document and review the exception.',
    );
  });
}
