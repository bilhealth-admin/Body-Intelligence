import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LocalCoachCommandParser();
  const admission = CoachActionAdmission();
  Iterable<IntelligenceAction> writes(String input) => parser
      .parse(input)
      .where((action) => admission.bind(action)?.writesData == true);

  for (final example in <(String, double)>[
    ('Set my target weight to 180 lb', 81.6466266),
    ('Change target weight to 180 pounds', 81.6466266),
    ('اجعل هدفي ١٨٠ رطل', 81.6466266),
    ('غير الوزن المستهدف إلى ١٨٠ باوند', 81.6466266),
    ('Set my target weight to 1000 lb', 453.59237),
    ('Set my target weight to 78 kg', 78),
  ]) {
    test('target unit conversion precedes kilogram bounds: ${example.$1}', () {
      final action = parser.parse(example.$1).single;
      expect(action.type, IntelligenceActionType.updateGoal);
      expect(action.toolId, 'update_goal');
      expect(action.payload['targetWeightKg'], closeTo(example.$2, 1e-8));
      expect(action.requiresConfirmation, isTrue);
      expect(
        admission.bind(action)!.allows(CoachActionPermissionMode.readOnly),
        isFalse,
      );
    });
  }

  for (final input in [
    'Set my target weight to 80 stones',
    'My weight is 80 stones',
    'اجعل هدفي ٨٠ أونصة',
    'My weight is 80 percent',
    'Set my target weight to 100 g',
    'Set my target weight to 20 lb',
    'Set my target weight to 80 kg or 175 lb',
    'My weight is 80 kg or 82 kg',
    'My weight is 80 kg/lb',
  ]) {
    test(
      'unknown, conflicting or unsafe mass cannot become a write: $input',
      () {
        expect(writes(input), isEmpty);
      },
    );
  }

  for (final example in <(String, int)>[
    ('سجل ٢٥٠ مليلتر ماء', 250),
    ('سجل ٢٥٠ ملليلتر ماء', 250),
    ('شربت لترين ماء', 2000),
    ('شربت ربع لتر ماء', 250),
    ('شربت لتر ونص ماء', 1500),
    ('Log 1.5 liters of water', 1500),
    ('شربت نص لتر موية', 500),
    ('Log .5 liters of water', 500),
  ]) {
    test('explicit water amount keeps its actual volume: ${example.$1}', () {
      final action = writes(example.$1).single;
      expect(action.type, IntelligenceActionType.addWater);
      expect(action.payload['amountMl'], example.$2);
      expect(action.requiresConfirmation, isTrue);
    });
  }

  for (final input in [
    'Log 2 gallons of water',
    'Log 2 deciliters of water',
    'Log 2 tablespoons of water',
    'شربت ٢ عبوة ماء',
    'شربت ٢ قناني ماء',
    'شربت ٢ ديسيلتر ماء',
    'Log 250 ml and 500 ml water',
    'سجل ٢٥٠ مل و٥٠٠ مل ماء',
    'شربت ٢ ونص لتر ماء',
    'شربت نصف ونصف لتر ماء',
    'Log 1 or 2 liters of water',
    'Log water 1e3 ml',
    'Log 1,905 ml water',
    'Should I drink 500 ml water?',
  ]) {
    test(
      'unknown or ambiguous water measure never falls through as ml: $input',
      () {
        expect(writes(input), isEmpty);
      },
    );
  }

  for (final example in <(String, String, String?)>[
    ('1905 calories', 'snack', null),
    ('1905 kcal', 'snack', null),
    ('Log 1905 calories only', 'snack', null),
    ('1905 calories without meals', 'snack', null),
    ('السعرات: ١٩٠٥', 'snack', null),
    ('سجل ١٩٠٥ سعرة حرارية', 'snack', null),
    ('أضف ۱۹۰۵ سعرات فقط', 'snack', null),
    ('I ate 1905 calories for dinner', 'dinner', null),
    ('Log 1905 calories for lunch on 2026-10-01', 'lunch', '2026-10-01'),
    ('أضف ١٩٠٥ سعرة للعشاء بتاريخ ٢٠٢٦-١٠-٠١', 'dinner', '2026-10-01'),
  ]) {
    test('calorie-only text prepares only known calories: ${example.$1}', () {
      // The newer owner-authored calorie contract always freezes a local date
      // and proposes a meal bucket from the clock before fresh confirmation.
      final action = parser
          .parse(example.$1, referenceLocal: DateTime(2026, 10, 6, 0, 5))
          .single;
      expect(action.type, IntelligenceActionType.quickAddMacros);
      expect(action.toolId, 'quick_add_macros');
      expect(action.payload, {
        'mealType': example.$2,
        'calories': 1905.0,
        'date': example.$3 ?? '2026-10-06',
      });
      expect(action.requiresConfirmation, isTrue);
      expect(action.requiresFreshConfirmation, isTrue);
      expect(
        admission.bind(action)!.allows(CoachActionPermissionMode.readOnly),
        isFalse,
      );
      expect(
        action.operationId,
        isNull,
        reason: 'Admission allocates a proposal ID later.',
      );
    });
  }

  for (final input in [
    'My total today is 1905 calories',
    'Log a total of 1905 calories',
    'إجمالي اليوم ١٩٠٥ سعرات',
    'Make today total 1905 calories',
    '1905 calories or 1800 calories',
    '1905 calories and 30 g protein',
    '19,05 calories',
    '1905 calories per 100 g',
    'I ate two eggs and 1905 calories',
    '1905 kJ',
    '1905 calories?',
    '0 calories',
    '-1905 calories',
    '10001 calories',
    '1905 calories for breakfast and dinner',
    'Log 1905 calories on 2026-02-30',
    'Log 1905 calories on 2026-10-01 and 2026-10-02',
  ]) {
    test(
      'a total, food mixture or ambiguous calorie statement does not append: $input',
      () {
        expect(
          writes(input).where(
            (action) => action.type == IntelligenceActionType.quickAddMacros,
          ),
          isEmpty,
        );
      },
    );
  }

  final reference = DateTime(2026, 1, 1, 0, 5);
  for (final example in <(String, String)>[
    ('Log 1905 calories today', '2026-01-01'),
    ('Log 1905 calories yesterday', '2025-12-31'),
    ('سجل ١٩٠٥ سعرة امس', '2025-12-31'),
    ('Yesterday log 1905 calories on 2025-12-20', '2025-12-20'),
  ]) {
    test('calorie date uses the caller local calendar: ${example.$1}', () {
      final action = parser.parse(example.$1, referenceLocal: reference).single;
      expect(action.type, IntelligenceActionType.quickAddMacros);
      expect(action.payload['date'], example.$2);
      expect(action.payload['calories'], 1905);
      expect(action.payload.containsKey('protein'), isFalse);
    });
  }
  for (final example in <(String, String)>[
    ('My weight is 82 kg today', '2026-01-01'),
    ('My weight is 82 kg yesterday', '2025-12-31'),
    ('سجل وزني ٨٢ كغ امس', '2025-12-31'),
    ('Yesterday my weight is 82 kg on 2025-12-20', '2025-12-20'),
  ]) {
    test('weight date uses the same caller local calendar: ${example.$1}', () {
      final action = parser.parse(example.$1, referenceLocal: reference).single;
      expect(action.type, IntelligenceActionType.addWeight);
      expect(action.payload['date'], example.$2);
      expect(action.payload['weightKg'], 82);
    });
  }
  for (final input in [
    'Log 1905 calories today yesterday',
    'My weight is 82 kg today yesterday',
    'Log 250 ml water on 2026-02-30',
  ]) {
    test(
      'unsupported/conflicting dates cannot target an unintended day: $input',
      () {
        final actions = parser.parse(input, referenceLocal: reference);
        expect(
          actions.where((action) => admission.bind(action)?.writesData == true),
          isEmpty,
        );
      },
    );
  }
  for (final example in <(String, String)>[
    ('Log 250 ml water today', '2026-01-01'),
    ('Log 250 ml water yesterday', '2025-12-31'),
    ('Log 250 ml water on 2025-12-31', '2025-12-31'),
    ('سجل ٢٥٠ مل ماء امس', '2025-12-31'),
    ('Yesterday log 250 ml water on 2025-12-20', '2025-12-20'),
  ]) {
    test('water keeps its explicit local calendar day: ${example.$1}', () {
      final action = parser.parse(example.$1, referenceLocal: reference).single;
      expect(action.type, IntelligenceActionType.addWater);
      expect(action.toolId, 'log_water');
      expect(action.payload, {'amountMl': 250, 'date': example.$2});
      expect(action.requiresConfirmation, isTrue);
    });
  }
}
