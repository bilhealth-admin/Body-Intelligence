import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusApi implements LocalCoachApi {
  _StatusApi(this.status);
  final CoachServiceStatus status;
  int calls = 0;

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async {
    calls++;
    return LocalCoachResult(
      actions: const [],
      processedOnDevice: false,
      serviceStatus: status,
    );
  }
}

void main() {
  for (final question in ['hi', 'كيفك']) {
    test(
      'local greeting is complete after transient provider failure: $question',
      () async {
        final api = _StatusApi(CoachServiceStatus.temporarilyUnavailable);
        final reply = await IntelligenceCenterEngine(
          localApi: api,
        ).answer(question: question, arabic: false);
        expect(reply.serviceStatus, CoachServiceStatus.ready);
        expect(reply.runtime, CoachAnswerRuntime.localFallback);
        expect(reply.actions, isEmpty);
        expect(api.calls, 1);
      },
    );
    for (final status in [
      CoachServiceStatus.signedOut,
      CoachServiceStatus.consentRequired,
      CoachServiceStatus.creditsRequired,
      CoachServiceStatus.quotaExhausted,
      CoachServiceStatus.safetyBlocked,
    ]) {
      test('greeting cannot mask $status: $question', () async {
        final reply = await IntelligenceCenterEngine(
          localApi: _StatusApi(status),
        ).answer(question: question, arabic: false);
        expect(reply.serviceStatus, status);
        expect(reply.message.text, isNot(contains('I am ready.')));
        expect(reply.message.text, isNot(contains('أنا جاهز معك')));
      });
    }
  }
  test('a substantive question retains its real transient failure', () async {
    final reply = await IntelligenceCenterEngine(
      localApi: _StatusApi(CoachServiceStatus.temporarilyUnavailable),
    ).answer(question: 'Explain balanced nutrition', arabic: false);
    expect(reply.serviceStatus, CoachServiceStatus.temporarilyUnavailable);
  });
}
