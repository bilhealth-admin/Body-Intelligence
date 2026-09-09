import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const registry = BilToolRegistry();

  test('unknown tools fail closed', () {
    expect(
      registry.createAction(
        name: 'execute_sql',
        arguments: const {},
        label: 'x',
      ),
      isNull,
    );
  });

  test('weight schema validates bounds, date, and extra arguments', () {
    expect(
      registry.createAction(
        name: 'log_weight',
        arguments: const {'weightKg': 89.7, 'date': '2026-08-09'},
        label: 'Log weight',
      ),
      isA<IntelligenceAction>()
          .having((a) => a.requiresConfirmation, 'confirmation', isTrue)
          .having((a) => a.payload['date'], 'date', '2026-08-09'),
    );
    expect(
      registry.createAction(
        name: 'log_weight',
        arguments: const {'weightKg': 5},
        label: 'x',
      ),
      isNull,
    );
    for (final invalid in <Object?>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        registry.createAction(
          name: 'log_weight',
          arguments: <String, Object?>{'weightKg': invalid},
          label: 'invalid numeric value',
        ),
        isNull,
      );
    }
    for (final invalidDate in <Object?>[
      '2026-02-30',
      '2026-08-09T12:00:00Z',
      20260809,
    ]) {
      expect(
        registry.createAction(
          name: 'log_weight',
          arguments: <String, Object?>{'weightKg': 89, 'date': invalidDate},
          label: 'invalid date',
        ),
        isNull,
      );
    }
    expect(
      registry.createAction(
        name: 'log_weight',
        arguments: const {'weightKg': 89, 'sql': 'drop table users'},
        label: 'x',
      ),
      isNull,
    );
  });

  test('navigation is low risk and deletion is destructive', () {
    final navigation = registry.createAction(
      name: 'open_report',
      arguments: const {},
      label: 'Open report',
    );
    final deletion = registry.createAction(
      name: 'request_account_deletion',
      arguments: const {},
      label: 'Delete',
    );
    expect(navigation!.requiresConfirmation, isFalse);
    expect(deletion!.requiresConfirmation, isTrue);
    expect(deletion.destructive, isTrue);
    expect(registry.lookup('request_account_deletion')!.confirmationStages, 2);
  });

  test('open weight log is read-only navigation to weight history', () {
    final action = registry.createAction(
      name: 'open_weight_log',
      arguments: const <String, Object?>{},
      label: 'Open weight history',
    );
    expect(action, isNotNull);
    expect(action!.type, IntelligenceActionType.navigate);
    expect(action.requiresConfirmation, isFalse);
    expect(action.payload, const <String, Object?>{'target': 'weight_history'});
  });

  test('registry is the finite model-visible allow-list', () {
    expect(BilToolRegistry.tools, hasLength(22));
    expect(BilToolRegistry.tools, contains('save_memory'));
    expect(
      BilToolRegistry.tools.values
          .where((tool) => tool.risk == BilToolRisk.destructive)
          .map((tool) => tool.name),
      ['request_account_deletion'],
    );
  });

  test(
    'navigation accepts target ids only and ambiguous meal moves fail closed',
    () {
      expect(
        registry
            .createAction(
              name: 'navigate',
              arguments: const {'target': 'weight_history'},
              label: 'open',
            )
            ?.type,
        IntelligenceActionType.navigate,
      );
      expect(
        registry.createAction(
          name: 'navigate',
          arguments: const {'target': '/admin?raw=true'},
          label: 'bad',
        ),
        isNull,
      );
      expect(
        registry.createAction(
          name: 'move_meal_item',
          arguments: const {'itemId': 12},
          label: 'ambiguous destination',
        ),
        isNull,
      );
      expect(
        registry.createAction(
          name: 'move_meal_item',
          arguments: const {'itemId': 12, 'mealType': 'dinner'},
          label: 'move',
        ),
        isA<IntelligenceAction>().having(
          (a) => a.requiresConfirmation,
          'confirmation',
          isTrue,
        ),
      );
    },
  );

  test('meal goal and measurement writes are typed and bounded', () {
    expect(
      registry.createAction(
        name: 'update_goal',
        arguments: const {'targetWeightKg': 85, 'targetDate': '2026-12-01'},
        label: 'goal',
      ),
      isNotNull,
    );
    expect(
      registry.createAction(
        name: 'save_measurements',
        arguments: const {'waistCm': 91.2},
        label: 'measure',
      ),
      isNotNull,
    );
    expect(
      registry.createAction(
        name: 'quick_add_macros',
        arguments: const {
          'date': '2026-08-10',
          'mealType': 'lunch',
          'calories': 420,
          'protein': 35,
          'carbohydrates': 40,
          'fat': 12,
        },
        label: 'meal',
      ),
      isNotNull,
    );
    expect(
      registry.createAction(
        name: 'quick_add_macros',
        arguments: const {
          'date': 'not-a-date',
          'mealType': 'lunch',
          'calories': 420,
          'protein': 35,
          'carbohydrates': 40,
          'fat': 12,
        },
        label: 'bad date',
      ),
      isNull,
    );
    expect(
      registry.createAction(
        name: 'save_measurements',
        arguments: const {'waistCm': 900},
        label: 'bad',
      ),
      isNull,
    );
    expect(
      registry.createAction(
        name: 'quick_add_macros',
        arguments: const {
          'mealType': 'lunch',
          'calories': 10001,
          'protein': 35,
          'carbohydrates': 40,
          'fat': 12,
        },
        label: 'repository would reject this',
      ),
      isNull,
    );
    expect(
      registry.createAction(
        name: 'save_measurements',
        arguments: <String, Object?>{'waistCm': double.nan},
        label: 'non-finite measurement',
      ),
      isNull,
    );
  });
}
