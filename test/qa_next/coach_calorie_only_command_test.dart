import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_calorie_command.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LocalCoachCalorieCommand();
  final now = DateTime(2026, 10, 6, 14, 42);

  for (final input in [
    '1905 calories',
    'Log 1905 kcal',
    'record 1,905 calories only',
    'Please add 1905 calories without meals',
    '1905 calories no foods',
    'سجل ١٩٠٥ سعرة',
    'سجّل لي ١٬٩٠٥ سعرة حرارية فقط',
    'أضف ۱۹۰۵ سعرات بدون وجبات',
    '١٩٠٥ كالوري بدون اكل',
    'دون 1905 سعرة بدون طعام فقط',
  ]) {
    test('calorie-only proposal preserves missing nutrients: $input', () {
      final action = parser.parse(input, locale: 'ar', referenceLocal: now);
      expect(action, isNotNull);
      expect(action!.type, IntelligenceActionType.quickAddMacros);
      expect(action.toolId, 'quick_add_macros');
      expect(action.payload, {
        'mealType': 'lunch',
        'date': '2026-10-06',
        'calories': 1905.0,
      });
      expect(action.requiresConfirmation, isTrue);
      expect(action.requiresFreshConfirmation, isTrue);
      expect(action.operationId, isNull);
      expect(action.label, contains('1905'));
      expect(action.label, contains('2026-10-06'));
      final binding = const CoachActionAdmission().bind(action);
      expect(binding, isNotNull);
      expect(binding!.writesData, isTrue);
      expect(binding.allows(CoachActionPermissionMode.readOnly), isFalse);
      expect(
        binding.requiresConfirmation(CoachActionPermissionMode.writeAllowed),
        isTrue,
      );
      expect(() => action.payload['protein'] = 0, throwsUnsupportedError);
    });
  }

  for (final entry in <String, double>{
    'Log 0.5 calories': .5,
    'سجل ١٩٠٥٫٥ سعرة': 1905.5,
    'record 1,905.25 kcal': 1905.25,
    '10000 calories': 10000,
  }.entries) {
    test('valid calorie quantity retains precision: ${entry.key}', () {
      expect(
        parser
            .parse(entry.key, locale: 'en', referenceLocal: now)!
            .payload['calories'],
        entry.value,
      );
    });
  }

  for (final entry in <String, String>{
    'log 1905 calories yesterday': '2026-10-05',
    'سجل امس 1905 سعرة': '2026-10-05',
    'سجل مبارح ١٩٠٥ سعرة': '2026-10-05',
    'today log 1905 calories': '2026-10-06',
    'سجل النهارده 1905 سعرة': '2026-10-06',
    'log 1905 calories on 2026-10-01 yesterday': '2026-10-01',
    'سجل ١٩٠٥ سعرة بتاريخ ٢٠٢٦-١٠-٠١ امس': '2026-10-01',
    'record 1905 calories on 1 October 2026 today': '2026-10-01',
    'سجل 1905 سعرة يوم 1 اكتوبر 2026': '2026-10-01',
  }.entries) {
    test('calendar date is not a calorie quantity: ${entry.key}', () {
      final action = parser.parse(entry.key, locale: 'en', referenceLocal: now);
      expect(action, isNotNull);
      expect(action!.payload['date'], entry.value);
      expect(action.payload['calories'], 1905);
    });
  }

  test('yesterday follows the local calendar at month and DST boundaries', () {
    for (final date in [
      DateTime(2026, 3, 1, 0, 5),
      DateTime(2026, 10, 5, 0, 5),
      DateTime(2027, 1, 1, 0, 5),
    ]) {
      final expected = DateTime(date.year, date.month, date.day - 1);
      final text =
          '${expected.year}-${expected.month.toString().padLeft(2, '0')}-'
          '${expected.day.toString().padLeft(2, '0')}';
      expect(
        parser
            .parse(
              '1905 calories yesterday',
              locale: 'en',
              referenceLocal: date,
            )!
            .payload['date'],
        text,
      );
    }
  });

  for (final entry in <String, String>{
    'Log 1905 calories for breakfast': 'breakfast',
    'للفطور سجل 1905 سعرة': 'breakfast',
    'add 1905 calories for lunch': 'lunch',
    'سجل 1905 سعرة للغداء': 'lunch',
    '1905 calories for dinner': 'dinner',
    'سجل 1905 سعرة للعشاء': 'dinner',
    'Log 1905 calories for snack': 'snack',
    'سجل 1905 سعرة وجبة خفيفة': 'snack',
  }.entries) {
    test('explicit meal overrides the suggested bucket: ${entry.key}', () {
      expect(
        parser
            .parse(entry.key, locale: 'en', referenceLocal: now)!
            .payload['mealType'],
        entry.value,
      );
    });
  }

  for (final entry in <int, String>{
    0: 'snack',
    5: 'breakfast',
    10: 'breakfast',
    11: 'lunch',
    15: 'lunch',
    16: 'dinner',
    21: 'dinner',
    22: 'snack',
  }.entries) {
    test('unspecified meal is proposed using local hour ${entry.key}', () {
      final action = parser.parse(
        '1905 calories',
        locale: 'en',
        referenceLocal: DateTime(2026, 10, 6, entry.key),
      )!;
      expect(action.payload['mealType'], entry.value);
      expect(action.requiresFreshConfirmation, isTrue);
    });
  }

  for (final input in [
    '1905',
    '1905 kg',
    '1905 grams of rice',
    'I burned 1905 calories',
    'My target is 1905 calories',
    'My total is 1905 calories',
    'Set the daily total to 1905 calories',
    'I have 1905 calories remaining',
    'Do not log 1905 calories',
    'Should I eat 1905 calories?',
    '1905 calories?',
    'If I log 1905 calories',
    'Change it to 1905 calories',
    'Replace 1800 with 1905 calories',
    '1905 calories per serving',
    '1905 calories from chicken and rice',
    'Log 1905 calories and 80 protein',
    'Log 1905 and 200 calories',
    'log -1905 calories',
    '0 calories',
    '10000.1 calories',
    'NaN calories',
    '1e3 calories',
    '19,05 calories',
    '1,90,500 calories',
    '1905.5.2 calories',
    '1905% calories',
    '1905 calories yesterday today',
    '1905 calories for breakfast and dinner',
    '1905 calories 2026-02-30',
    '1905 calories 2026-10-01 2026-10-02',
    '1905 calories tomorrow',
    'غدا 1905 سعرة',
    'لا تسجل 1905 سعرة',
    'حرقت 1905 سعرة',
    'هدفي 1905 سعرة',
    'اجمالي اليوم 1905 سعرة',
    'لا قصدي 1905 سعرة',
    'بدل 1905 سعرة',
    'نصها 1905 سعرة',
    'زي امس 1905 سعرة',
    'سجل 1905 سعرة وبيضتين',
    'هل 1905 سعرة مناسبة؟',
    'سكر 1905 سعرة',
  ]) {
    test(
      'ambiguous or non-intake number cannot become calorie entry: $input',
      () {
        expect(parser.parse(input, locale: 'ar', referenceLocal: now), isNull);
        expect(
          const LocalCoachCommandParser()
              .parse(input, locale: 'ar')
              .where(
                (action) =>
                    action.type == IntelligenceActionType.quickAddMacros,
              ),
          isEmpty,
        );
      },
    );
  }

  for (final channel in CoachInputChannel.values) {
    for (final prompt in [
      'Log 1905 calories for lunch on 2026-10-01',
      'سجل ١٩٠٥ سعرة للغداء بتاريخ ٢٠٢٦-١٠-٠١',
    ]) {
      test(
        'typed and voice pipelines use the same native entry: $channel $prompt',
        () async {
          final gateway = _NoCalorieModel();
          final api = ModelBackedLocalCoachApi(
            gateway: gateway,
            context: CoachContextSnapshot.empty(),
          );
          final result = await api.understand(
            LocalCoachRequest(text: prompt, locale: 'ar', channel: channel),
          );
          expect(result.actions, hasLength(1));
          expect(result.processedOnDevice, isTrue);
          expect(result.actions.single.toolId, 'quick_add_macros');
          expect(result.actions.single.payload, {
            'mealType': 'lunch',
            'date': '2026-10-01',
            'calories': 1905.0,
          });
          expect(gateway.calls, 0);
        },
      );
    }
  }
}

class _NoCalorieModel implements LocalModelGateway {
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    calls++;
    throw StateError('A known calorie-only entry must not invoke a provider');
  }
}
