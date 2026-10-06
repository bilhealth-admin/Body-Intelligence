import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LocalCoachCommandParser();

  for (final input in [
    'I weighed 250 g of chicken',
    'وزن الدجاج ٢٠٠ غرام',
    'اكلت وجبة وزنها ٣٠٠ جرام',
    'Deadlift 120 kg',
    'رفعت ١٢٠ كيلو في التمرين',
    'My weight is 250 grams',
    'I drank 400 ml of milk',
    'شربت ٢٥٠ مل حليب',
    '250 ml',
  ]) {
    test('food or exercise quantity is not a body or water write: $input', () {
      final actions = parser.parse(input);
      expect(
        actions.where(
          (a) => const {
            IntelligenceActionType.addWeight,
            IntelligenceActionType.addWater,
          }.contains(a.type),
        ),
        isEmpty,
      );
    });
  }

  for (final example in [
    ('2026-09-05: record my weight 82.4 kg', 82.4, '2026-09-05'),
    ('سجل وزني ٨٢٫٤ كغ بتاريخ ٢٠٢٦-٠٩-٠٥', 82.4, '2026-09-05'),
    ('My weight is 180 lb on 2026-09-05', 81.6466266, '2026-09-05'),
  ]) {
    test('body weight uses its own unit and explicit date: ${example.$1}', () {
      final action = parser.parse(example.$1).single;
      expect(action.type, IntelligenceActionType.addWeight);
      expect(action.payload['weightKg'], closeTo(example.$2, 0.00001));
      expect(action.payload['date'], example.$3);
      expect(action.requiresConfirmation, isTrue);
    });
  }

  for (final example in [
    ('Log 1.5 liters of water', 1500),
    ('سجل ١٫٥ لتر مويه', 1500),
    ('شربت نص لتر موية', 500),
    ('Log 1000 ml water', 1000),
    ('Record 2 cups of water', null),
  ]) {
    test(
      'water quantities require a known milliliter conversion: ${example.$1}',
      () {
        final actions = parser.parse(example.$1);
        final writes = actions.where(
          (a) => a.type == IntelligenceActionType.addWater,
        );
        if (example.$2 == null) {
          expect(writes, isEmpty, reason: 'An unspecified cup is not two ml.');
        } else {
          expect(writes.single.payload['amountMl'], example.$2);
        }
      },
    );
  }

  test('unknown calories remain unknown when only a macro is supplied', () {
    const registry = BilToolRegistry();
    for (final args in [
      <String, Object?>{'mealType': 'lunch', 'protein': 30},
      <String, Object?>{'mealType': 'lunch', 'calories': null, 'fat': 12},
    ]) {
      final action = registry.createAction(
        name: 'quick_add_macros',
        arguments: args,
        label: 'Partial nutrition',
      );
      expect(action, isNotNull);
      expect(action!.payload, args);
    }
    for (final args in [
      <String, Object?>{'mealType': 'lunch'},
      <String, Object?>{'mealType': 'lunch', 'calories': null, 'protein': 0},
      <String, Object?>{'mealType': 'lunch', 'protein': double.nan},
    ]) {
      expect(
        registry.createAction(
          name: 'quick_add_macros',
          arguments: args,
          label: 'Invalid',
        ),
        isNull,
      );
    }
  });
}
