import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/ai_coach_safety_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedCoachApi implements LocalCoachApi {
  _FixedCoachApi(this.result);
  final LocalCoachResult result;
  int calls = 0;

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async {
    calls += 1;
    return result;
  }
}

const _question = 'What should I eat after a workout?';
const _openMeals = IntelligenceAction(
  id: 'open_meals',
  type: IntelligenceActionType.reviewMeal,
  label: 'Open meal log',
  requiresConfirmation: false,
);

Future<IntelligenceCenterReply> _answer(LocalCoachResult result) =>
    IntelligenceCenterEngine(
      localApi: _FixedCoachApi(result),
    ).answer(question: _question, arabic: false, localeCode: 'en');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud answer and action are both preserved with provenance', () async {
    final response = await _answer(
      const LocalCoachResult(
        actions: [_openMeals],
        processedOnDevice: false,
        answer: 'Synthetic answer from the cloud fixture.',
        spokenAnswer: 'Synthetic spoken answer.',
        runtime: CoachAnswerRuntime.cloudPersonalized,
        responseId: 'cloud-fixture-0001',
        evidence: ['fixture-field'],
        reason: 'Fixture reason',
        missingData: ['fixture missing field'],
        confidence: 0.72,
      ),
    );
    expect(response.message.text, 'Synthetic answer from the cloud fixture.');
    expect(
      response.message.text,
      isNot(contains('understood your request locally')),
    );
    expect(response.message.kind, IntelligenceMessageKind.action);
    expect(response.actions, hasLength(1));
    expect(identical(response.actions.single, _openMeals), isTrue);
    expect(response.runtime, CoachAnswerRuntime.cloudPersonalized);
    expect(response.message.id, 'cloud-fixture-0001');
    expect(response.spokenText, 'Synthetic spoken answer.');
    expect(response.message.evidence, ['fixture-field']);
    expect(response.message.reason, 'Fixture reason');
    expect(response.message.missingData, ['fixture missing field']);
    expect(response.message.confidence, 0.72);
  });

  test('cloud answer without action is unchanged', () async {
    final response = await _answer(
      const LocalCoachResult(
        actions: [],
        processedOnDevice: false,
        answer: '  Synthetic standalone answer.  ',
        runtime: CoachAnswerRuntime.cloudPersonalized,
      ),
    );
    expect(response.message.text, 'Synthetic standalone answer.');
    expect(response.actions, isEmpty);
    expect(response.message.kind, IntelligenceMessageKind.freeQuestion);
    expect(response.runtime, CoachAnswerRuntime.cloudPersonalized);
  });

  test(
    'on-device model answer with action is not discarded or relabelled',
    () async {
      final response = await _answer(
        const LocalCoachResult(
          actions: [_openMeals],
          processedOnDevice: true,
          answer: 'Synthetic on-device model answer.',
          runtime: CoachAnswerRuntime.onDevice,
        ),
      );
      expect(response.message.text, 'Synthetic on-device model answer.');
      expect(response.actions, hasLength(1));
      expect(response.runtime, CoachAnswerRuntime.onDevice);
    },
  );

  test('action-only local command keeps its original copy', () async {
    final response = await _answer(
      const LocalCoachResult(actions: [_openMeals], processedOnDevice: true),
    );
    expect(
      response.message.text,
      contains('I understood your request locally.'),
    );
    expect(response.actions, hasLength(1));
    expect(response.runtime, CoachAnswerRuntime.onDevice);
  });

  test('blank answer does not erase action-only local behavior', () async {
    final response = await _answer(
      const LocalCoachResult(
        actions: [_openMeals],
        processedOnDevice: true,
        answer: '  ',
      ),
    );
    expect(
      response.message.text,
      contains('I understood your request locally.'),
    );
    expect(response.actions, hasLength(1));
  });

  test('cloud failure without answer still shows unavailable status', () async {
    final response = await _answer(
      const LocalCoachResult(
        actions: [],
        processedOnDevice: true,
        serviceStatus: CoachServiceStatus.temporarilyUnavailable,
        runtime: CoachAnswerRuntime.localFallback,
      ),
    );
    expect(response.message.text, contains('temporarily unavailable'));
    expect(response.actions, isEmpty);
    expect(response.serviceStatus, CoachServiceStatus.temporarilyUnavailable);
  });

  test('safety-blocked cloud payload exposes no answer or action', () async {
    final response = await _answer(
      const LocalCoachResult(
        actions: [_openMeals],
        processedOnDevice: false,
        answer: 'Provider output must never reach the user.',
        spokenAnswer: 'Provider speech must never play.',
        serviceStatus: CoachServiceStatus.safetyBlocked,
        runtime: CoachAnswerRuntime.cloudPersonalized,
      ),
    );
    expect(response.message.text, AiCoachSafetyCopy.resolve('en'));
    expect(response.message.text, isNot(contains('Provider output')));
    expect(response.spokenText, isNull);
    expect(response.actions, isEmpty);
    expect(response.serviceStatus, CoachServiceStatus.safetyBlocked);
    expect(response.runtime, CoachAnswerRuntime.localFallback);
    expect(response.message.kind, IntelligenceMessageKind.safety);
  });

  test(
    'destructive and confirmation flags remain on the same action',
    () async {
      const action = IntelligenceAction(
        id: 'request-account-deletion',
        type: IntelligenceActionType.requestAccountDeletion,
        label: 'Review deletion',
        requiresConfirmation: true,
        destructive: true,
      );
      final response = await _answer(
        const LocalCoachResult(
          actions: [action],
          processedOnDevice: false,
          answer: 'Review this proposal before any action.',
          runtime: CoachAnswerRuntime.cloudPersonalized,
        ),
      );
      expect(response.message.text, 'Review this proposal before any action.');
      expect(identical(response.actions.single, action), isTrue);
      expect(response.actions.single.requiresConfirmation, isTrue);
      expect(response.actions.single.destructive, isTrue);
    },
  );

  test('urgent safety gate still runs before model/action branch', () async {
    final api = _FixedCoachApi(
      const LocalCoachResult(
        actions: [_openMeals],
        processedOnDevice: false,
        answer: 'This model fixture must not be used.',
        runtime: CoachAnswerRuntime.cloudPersonalized,
      ),
    );
    final response = await IntelligenceCenterEngine(
      localApi: api,
    ).answer(question: 'I have chest pain.', arabic: false, localeCode: 'en');
    expect(api.calls, 0);
    expect(response.actions, isEmpty);
    expect(response.message.text, isNot(contains('model fixture')));
  });
}
