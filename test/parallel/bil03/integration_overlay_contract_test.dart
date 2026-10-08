import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_tools.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_settings_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const admission = CoachActionAdmission();
  const localCatalog = CoachSettingsToolCatalog();

  test(
    'BIL-03 local settings tools stay separate; all 23 original tools survive extension',
    () {
      // Food V2 and Health Commands may add supported tools, but must never
      // replace/remove the frozen 23 canonical descriptors or inject settings
      // tools into the canonical registry.
      const originalCanonical = <String>{
        'navigate',
        'read_nutrition_remaining',
        'read_profile_identity',
        'open_weight_log',
        'open_meals',
        'open_meals_yesterday',
        'open_workouts',
        'open_plan',
        'open_report',
        'manage_subscription',
        'set_theme_mode',
        'set_language',
        'update_goal',
        'save_measurements',
        'quick_add_macros',
        'update_meal_item',
        'delete_meal_item',
        'move_meal_item',
        'request_account_deletion',
        'sign_out',
        'log_water',
        'log_weight',
        'save_memory',
      };
      const foodV2 = <String>{'log_foods', 'replace_meal_item'};
      expect(
        BilToolRegistry.tools.keys.toSet(),
        originalCanonical
            .union(foodV2)
            .union(coachHealthToolsByName.keys.toSet()),
      );
      expect(BilToolRegistry.tools.keys, containsAll(originalCanonical));
      expect(
        BilToolRegistry.tools.keys,
        isNot(contains('set_unit_preference')),
      );
      expect(BilToolRegistry.tools.keys, isNot(contains('set_reminder')));
      expect(BilToolRegistry.tools.keys, isNot(contains('review_memories')));
      expect(
        BilToolRegistry.tools.keys,
        isNot(contains('prepare_local_export')),
      );
      expect(CoachSettingsToolCatalog.toolNames, hasLength(4));
    },
  );

  test('local reversible write is admitted with fresh operation identity', () {
    final action = localCatalog.createAction(
      name: 'set_unit_preference',
      arguments: const {'dimension': 'weight', 'value': 'Kilograms'},
      label: 'Change display units',
    );
    expect(action, isNotNull);
    expect(action!.type, IntelligenceActionType.setUnitPreference);
    final admitted = admission.admitProposal(
      action,
      createOperationId: () => 'bil03-overlay-unit-1',
    );
    expect(admitted, isNotNull);
    expect(admitted!.operationId, 'bil03-overlay-unit-1');
    final binding = admission.bind(admitted, requireOperationId: true);
    expect(binding, isNotNull);
    expect(binding!.writesData, isTrue);
    expect(binding.allows(CoachActionPermissionMode.readOnly), isFalse);
    expect(
      binding.requiresConfirmation(CoachActionPermissionMode.askBeforeWrite),
      isTrue,
    );
  });

  test('memory review and export remain non-writing local handoffs', () {
    final review = localCatalog.createAction(
      name: 'review_memories',
      arguments: const {},
      label: 'Review memories',
    )!;
    final export = localCatalog.createAction(
      name: 'prepare_local_export',
      arguments: const {
        'from': '2026-09-01',
        'to': '2026-09-30',
        'datasets': ['progress'],
      },
      label: 'Review local export',
    )!;
    expect(admission.bind(review)!.writesData, isFalse);
    expect(admission.bind(export)!.writesData, isFalse);
    expect(admission.admitProposal(review)!.operationId, isNull);
    expect(admission.admitProposal(export)!.operationId, isNull);
  });
}
