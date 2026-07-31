import 'package:body_intelligence_log/features/global_platform/cloud_ai/optional_cloud_ai_platform.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Provider implements CloudAiProvider {
  _Provider({required this.providerId, this.fail = false});
  final String providerId;
  final bool fail;
  int calls = 0;
  Map<String, Object?>? seen;
  @override
  String get id => providerId;
  @override
  Set<String> get capabilities => const <String>{'summary'};
  @override
  Future<CloudAiResponse> execute(CloudAiRequest request) async {
    calls += 1;
    seen = request.redactedPayload;
    if (fail) throw StateError('provider-down');
    return CloudAiResponse(
      providerId: id,
      modelId: 'model-1',
      output: 'Safe summary',
      usageTokens: 12,
      provenance: '$id:model-1:${request.id}',
      safe: true,
      structuredOutput: const <String, Object?>{'summary': 'Safe summary'},
    );
  }
}

void main() {
  test(
    'cloud AI redacts sensitive values, falls back, validates schema, and is idempotent',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final failing = _Provider(providerId: 'a-provider', fail: true);
      final healthy = _Provider(providerId: 'z-provider');
      final runtime = OptionalCloudAiRuntime(
        providers: <CloudAiProvider>[failing, healthy],
        store: store,
        audit: audit,
        monthlyTokenBudget: 1000,
      );
      final request = CloudAiRequest(
        id: 'r1',
        capability: 'summary',
        redactedPayload: const <String, Object?>{
          'name': 'User',
          'health': <String, Object?>{
            'weight': 90,
            'email': 'private@example.com',
          },
        },
        maxTokens: 50,
        timeout: const Duration(seconds: 2),
        requiredOutputKeys: const <String>{'summary'},
      );
      final consent = GlobalConsentGrant(
        scope: 'cloud-ai',
        state: GlobalConsentState.granted,
        updatedAt: DateTime.utc(2026),
      );
      final first = await runtime.run(
        request: request,
        consent: consent,
        localOnly: false,
        at: DateTime.utc(2026),
      );
      final second = await runtime.run(
        request: request,
        consent: consent,
        localOnly: false,
        at: DateTime.utc(2026),
      );
      expect(first?.providerId, 'z-provider');
      expect(second?.provenance, first?.provenance);
      expect(healthy.calls, 1);
      expect(healthy.seen?['name'], '[REDACTED]');
      expect((healthy.seen?['health'] as Map)['email'], '[REDACTED]');
      expect(
        audit.events
            .singleWhere((event) => event.action == 'cloud_ai.used')
            .metadata['tokens'],
        12,
      );
    },
  );

  test(
    'cloud AI safely abstains without consent, in local-only mode, and over budget',
    () async {
      final audit = InMemoryGlobalAuditSink();
      final runtime = OptionalCloudAiRuntime(
        providers: <CloudAiProvider>[_Provider(providerId: 'p')],
        store: InMemoryGlobalStore(),
        audit: audit,
        monthlyTokenBudget: 10,
      );
      const request = CloudAiRequest(
        id: 'r2',
        capability: 'summary',
        redactedPayload: <String, Object?>{},
        maxTokens: 20,
        timeout: Duration(seconds: 1),
      );
      final denied = GlobalConsentGrant(
        scope: 'cloud-ai',
        state: GlobalConsentState.denied,
        updatedAt: DateTime.utc(2026),
      );
      expect(
        await runtime.run(
          request: request,
          consent: denied,
          localOnly: false,
          at: DateTime.utc(2026),
        ),
        isNull,
      );
      expect(
        await runtime.run(
          request: request,
          consent: GlobalConsentGrant(
            scope: 'cloud-ai',
            state: GlobalConsentState.granted,
            updatedAt: DateTime.utc(2026),
          ),
          localOnly: true,
          at: DateTime.utc(2026),
        ),
        isNull,
      );
      expect(
        await runtime.run(
          request: request,
          consent: GlobalConsentGrant(
            scope: 'cloud-ai',
            state: GlobalConsentState.granted,
            updatedAt: DateTime.utc(2026),
          ),
          localOnly: false,
          at: DateTime.utc(2026),
        ),
        isNull,
      );
    },
  );
}
