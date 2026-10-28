import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:flutter_test/flutter_test.dart';

const _physicalRequest =
    'Do not change or log anything. Show a short Arabic reply with heading, '
    'bullets and a two-row table with English exercise names and kg, '
    'plus a WHO health link.';

void main() {
  test('physical39 read-only Markdown request stays informational', () {
    expect(
      classifyCoachRequest(_physicalRequest).kind,
      CoachRequestKind.information,
    );
  });

  test(
    'physical39 read-only request cannot launch a plan or admit its tool',
    () {
      for (final channel in CoachInputChannel.values) {
        final input = const CoachIntentNormalizer().normalize(
          text: _physicalRequest,
          locale: 'en',
          channel: channel,
        );
        expect(smartPlanIntent(input.normalized), BilSmartPlanIntent.none);
        expect(coachAllowsSuggestedPlanAction(input.normalized), isFalse);
        expect(
          classifyCoachPlanSequence([
            'Create a training plan for a week',
            input.normalized,
          ]).createsPlan,
          isFalse,
        );
      }
    },
  );

  test('negated English and Arabic actions never become local commands', () {
    const parser = LocalCoachCommandParser();
    for (final input in [
      _physicalRequest,
      "Don't change my workout plan; only explain the options.",
      'Do not log water 300 ml; explain hydration instead.',
      'Do not delete my account; explain the privacy policy.',
      'Read-only: change my workout plan is just an example.',
      'لا تغير او تسجل اي شيء. اعرض جدولا باسماء تمارين بالانجليزية وكغ.',
      'لا تعدل خطة التمرين، اشرح البدائل فقط.',
      'لا تسجل ماء 300 مل، اشرح الترطيب فقط.',
      'بدون تعديل الخطة او تسجيل اي شيء، اشرح تمرين الخميس.',
    ]) {
      expect(smartPlanIntent(input), BilSmartPlanIntent.none, reason: input);
      expect(coachAllowsSuggestedPlanAction(input), isFalse, reason: input);
      expect(parser.parse(input, locale: 'en'), isEmpty, reason: input);
    }
  });

  test(
    'read-only answer reaches model but rejects an unsolicited write',
    () async {
      final gateway = _Gateway();
      final api = ModelBackedLocalCoachApi(
        gateway: gateway,
        context: CoachContextSnapshot.empty(),
      );
      final result = await api.understand(
        const LocalCoachRequest(text: _physicalRequest, locale: 'en'),
      );
      expect(gateway.calls, 1);
      expect(result.answer, contains('## تدريب'));
      expect(result.answer, contains('| Squat | 20 kg |'));
      expect(result.actions, isEmpty);
    },
  );

  test(
    'positive revision and logging still require the existing confirmation',
    () {
      expect(
        smartPlanIntent(
          'Change my workout on Thursday because I am travelling',
        ),
        BilSmartPlanIntent.revise,
      );
      expect(
        smartPlanIntent('غيّر تمرين الخميس لاني مسافر'),
        BilSmartPlanIntent.revise,
      );
      final action = const LocalCoachCommandParser().parse(
        'Log water 300 ml',
        locale: 'en',
      );
      expect(action, hasLength(1));
      expect(action.single.requiresConfirmation, isTrue);
      expect(action.single.payload['amountMl'], 300);
    },
  );

  test(
    'a scoped negation preserves the contrasting confirmed positive request',
    () {
      const parser = LocalCoachCommandParser();
      for (final request in [
        'Do not log my weight; update my goal to 60 kg.',
        "Don't log my weight, but update my goal to 60 kg.",
        'لا تسجل وزني؛ غير الهدف الى 60 كيلو.',
      ]) {
        final actions = parser.parse(request, locale: 'en');
        expect(actions, hasLength(1), reason: request);
        expect(actions.single.toolId, 'update_goal');
        expect(actions.single.payload['targetWeightKg'], 60);
        expect(actions.single.requiresConfirmation, isTrue);
      }
      const plan = 'Do not log my weight; change my workout on Thursday.';
      expect(smartPlanIntent(plan), BilSmartPlanIntent.revise);
      expect(coachAllowsSuggestedPlanAction(plan), isTrue);
    },
  );

  test('literal note bodies keep spelling and cannot redirect the command', () {
    const body = 'Do not change anything.\nMy Exercise Value: 42 kg.';
    const input = 'Save a note yesterday: $body';
    expect(coachExplicitlyForbidsActions(input), isFalse);
    expect(smartPlanIntent(input), BilSmartPlanIntent.none);
    final actions = const LocalCoachCommandParser().parse(
      input,
      locale: 'en',
      referenceLocal: DateTime(2026, 10, 28),
    );
    expect(actions, hasLength(1));
    expect(actions.single.toolId, 'save_day_note');
    expect(actions.single.payload['text'], body);
    expect(actions.single.payload['date'], '2026-10-27');
    expect(actions.single.requiresConfirmation, isTrue);
  });
}

class _Gateway implements LocalModelGateway {
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
    return const LocalModelResult.answer(
      LocalModelAnswer(
        text:
            '## تدريب\n- مثال فقط\n\n| Exercise | kg |\n|---|---|\n'
            '| Squat | 20 kg |\n| Row | 10 kg |\n'
            '[WHO](https://www.who.int/)',
        action: {
          'name': 'log_water',
          'arguments': {'amountMl': 300},
        },
      ),
    );
  }
}
