import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real projection sends permitted profile facts in one Cloud request',
    () async {
      final events = <String>[];
      final cloud = _RecordingCloudAccess(
        events: events,
        consent: _grantedConsent,
      );
      final context = CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 9, 21),
        profile: const {
          'age': 35,
          'currentWeightKg': 87.0,
          'targetWeightKg': 79.0,
          'email': 'must-not-be-sent@example.com',
        },
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
      );
      final result = await LlamaCppLocalGateway(
        cloudAccess: cloud,
      ).answer(question: 'كم عمري؟', locale: 'ar', context: context);
      expect(result.status, CoachServiceStatus.ready);
      expect(events, ['session', 'consent', 'invoke']);
      final payload = cloud.lastBody!['context']! as Map;
      expect(payload['profile'], {
        'age': 35,
        'currentWeightKg': 87.0,
        'targetWeightKg': 79.0,
      });
      expect(
        cloud.lastBody!['context_disclosure'],
        containsPair('categories', ['weight_measurements_goal']),
      );
    },
  );

  group('remote AI consent preflight', () {
    test(
      'signed-out request builds no context and invokes no Edge function',
      () async {
        final events = <String>[];
        final cloud = _RecordingCloudAccess(
          events: events,
          hasSession: false,
          consent: _grantedConsent,
        );
        final projector = _RecordingProjector(events);

        final result = await _gateway(cloud, projector).answer(
          question: 'What is my weight?',
          locale: 'en',
          context: _context(),
        );

        expect(result.status, CoachServiceStatus.signedOut);
        expect(events, ['session']);
        expect(cloud.lastBody, isNull);
      },
    );

    for (final receipt in <Object?>[
      const <String, Object?>{'granted': false, 'policy_version': '2'},
      const <String, Object?>{'granted': true, 'policy_version': '1'},
      const <String, Object?>{'granted': true},
      null,
    ]) {
      test('denied or stale receipt $receipt sends no payload', () async {
        final events = <String>[];
        final cloud = _RecordingCloudAccess(events: events, consent: receipt);
        final projector = _RecordingProjector(events);

        final result = await _gateway(cloud, projector).answer(
          question: 'Review my sleep',
          locale: 'en',
          context: _context(),
        );

        expect(result.status, CoachServiceStatus.consentRequired);
        expect(result.diagnosticCode, 'ai_consent_required');
        expect(events, ['session', 'consent']);
        expect(cloud.lastBody, isNull);
      });
    }

    test('preflight error fails closed before projection or invoke', () async {
      final events = <String>[];
      final cloud = _RecordingCloudAccess(
        events: events,
        throwConsentRead: true,
      );
      final projector = _RecordingProjector(events);

      final result = await _gateway(
        cloud,
        projector,
      ).answer(question: 'Review my meals', locale: 'en', context: _context());

      expect(result.status, CoachServiceStatus.temporarilyUnavailable);
      expect(result.diagnosticCode, 'remote_ai_consent_preflight_failed');
      expect(events, ['session', 'consent']);
      expect(cloud.lastBody, isNull);
    });

    test(
      'transient consent failure waits for explicit retry before any invoke',
      () async {
        final events = <String>[];
        final cloud = _RecordingCloudAccess(
          events: events,
          consentFailuresRemaining: 1,
          consent: _grantedConsent,
        );
        final projector = _RecordingProjector(events);

        final result = await _gateway(cloud, projector).answer(
          question: 'Review my meals',
          locale: 'en',
          context: _context(),
        );

        expect(result.status, CoachServiceStatus.temporarilyUnavailable);
        expect(events, ['session', 'consent']);
        expect(cloud.lastBody, isNull);

        final retry = await _gateway(cloud, projector).answer(
          question: 'Review my meals',
          locale: 'en',
          context: _context(),
        );
        expect(retry.status, CoachServiceStatus.ready);
        expect(events, [
          'session',
          'consent',
          'session',
          'consent',
          'project',
          'invoke',
        ]);
        expect(cloud.lastBody, isNotNull);
      },
    );

    test(
      'current consent projects context then invokes and keeps tool action',
      () async {
        final events = <String>[];
        final cloud = _RecordingCloudAccess(
          events: events,
          consent: _grantedConsent,
          response: const CoachCloudFunctionResponse(
            status: 200,
            data: <String, Object?>{
              'reply': 'I can update that after confirmation.',
              'proposed_actions': <Object?>[
                <String, Object?>{
                  'type': 'update_goal',
                  'arguments': <String, Object?>{'targetWeightKg': 79},
                },
              ],
            },
          ),
        );
        final projector = _RecordingProjector(events);

        final result = await _gateway(cloud, projector).answer(
          question: 'Change my target weight to 79 kg',
          locale: 'en',
          context: _context(),
        );

        expect(result.status, CoachServiceStatus.ready);
        expect(result.answer?.processedOnDevice, isFalse);
        expect(result.answer?.action, <String, Object?>{
          'name': 'update_goal',
          'arguments': <String, Object?>{'targetWeightKg': 79},
        });
        expect(events, ['session', 'consent', 'project', 'invoke']);
        expect(cloud.lastBody?['context'], <String, Object?>{
          'marker': 'projected',
        });
        expect(cloud.lastBody?['context_disclosure'], <String, Object?>{
          'categories': <String>['weight_measurements_goal'],
          'included_context_fields': <String>['marker'],
          'included_prior_turn_count': 0,
          'sent_message_count': 1,
        });
      },
    );

    test(
      'cloud response keeps only allow-listed health citation IDs',
      () async {
        final cloud = _RecordingCloudAccess(
          events: <String>[],
          consent: _grantedConsent,
          response: const CoachCloudFunctionResponse(
            status: 200,
            data: <String, Object?>{
              'reply': 'General BMI screening guidance.',
              'citations': <Object?>[
                HealthEvidenceIds.cdcAdultBmi,
                'https://untrusted.example/fake',
                'invented_study',
                HealthEvidenceIds.cdcAdultBmi,
              ],
            },
          ),
        );

        final result = await _gateway(
          cloud,
          _RecordingProjector(cloud.events),
        ).answer(question: 'Explain BMI', locale: 'en', context: _context());

        expect(result.status, CoachServiceStatus.ready);
        expect(result.answer?.citationIds, const <String>[
          HealthEvidenceIds.cdcAdultBmi,
        ]);
      },
    );
  });

  group('consent receipt parser', () {
    test('requires exact granted true and current policy version', () {
      expect(isCurrentRemoteAiConsentGranted(_grantedConsent), isTrue);
      expect(
        isCurrentRemoteAiConsentGranted(const <String, Object?>{
          'granted': 1,
          'policy_version': '2',
        }),
        isFalse,
      );
      expect(
        isCurrentRemoteAiConsentGranted(const <String, Object?>{
          'granted': true,
          'policy_version': 2,
        }),
        isFalse,
      );
    });
  });
}

const _grantedConsent = <String, Object?>{
  'granted': true,
  'policy_version': '2',
};

LlamaCppLocalGateway _gateway(
  CoachCloudAccess cloud,
  CoachCloudContextProjector projector,
) => LlamaCppLocalGateway(cloudAccess: cloud, cloudContextProjector: projector);

CoachContextSnapshot _context() =>
    CoachContextSnapshot.empty(generatedAt: DateTime.utc(2026, 9, 5));

final class _RecordingCloudAccess implements CoachCloudAccess {
  _RecordingCloudAccess({
    required this.events,
    this.hasSession = true,
    this.consent,
    this.throwConsentRead = false,
    this.consentFailuresRemaining = 0,
    this.response = const CoachCloudFunctionResponse(
      status: 200,
      data: <String, Object?>{'reply': 'ok'},
    ),
  });

  final List<String> events;
  final bool hasSession;
  final Object? consent;
  final bool throwConsentRead;
  int consentFailuresRemaining;
  final CoachCloudFunctionResponse response;
  Map<String, Object?>? lastBody;

  @override
  bool get hasAuthenticatedSession {
    events.add('session');
    return hasSession;
  }

  @override
  Future<Object?> readRemoteAiConsent() async {
    events.add('consent');
    if (throwConsentRead || consentFailuresRemaining > 0) {
      if (consentFailuresRemaining > 0) consentFailuresRemaining--;
      throw StateError('offline');
    }
    return consent;
  }

  @override
  Future<CoachCloudFunctionResponse> invokeCoach(
    Map<String, Object?> body,
  ) async {
    events.add('invoke');
    lastBody = body;
    return response;
  }
}

final class _RecordingProjector implements CoachCloudContextProjector {
  _RecordingProjector(this.events);

  final List<String> events;

  @override
  CoachCloudContextProjection project({
    required String question,
    required CoachContextSnapshot context,
    required List<CoachConversationTurn> conversation,
  }) {
    events.add('project');
    return const CoachCloudContextProjection(
      context: <String, Object?>{'marker': 'projected'},
      disclosure: <String, Object?>{
        'categories': <String>['weight_measurements_goal'],
        'included_context_fields': <String>['marker'],
      },
    );
  }
}
