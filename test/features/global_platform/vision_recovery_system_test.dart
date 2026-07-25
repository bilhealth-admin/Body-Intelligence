import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/vision/computer_vision_platform.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FlakyVision implements VisionProvider {
  _FlakyVision(this.failuresBeforeSuccess);
  final int failuresBeforeSuccess;
  int calls = 0;
  @override
  String get id => 'vision-production';
  @override
  Set<VisionJobKind> get capabilities => VisionJobKind.values.toSet();
  @override
  Future<List<VisionFinding>> analyze(
    VisionJobKind kind,
    List<int> bytes, {
    required String locale,
  }) async {
    calls += 1;
    if (calls <= failuresBeforeSuccess) throw StateError('transient');
    return const <VisionFinding>[
      VisionFinding(
        key: 'food',
        value: 'grilled chicken',
        confidence: .91,
        provenance: 'provider:item-1',
        rangeMin: 140,
        rangeMax: 190,
      ),
    ];
  }
}

void main() {
  test(
    'vision persists lifecycle, retries transient failure, and records review evidence',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final provider = _FlakyVision(1);
      final runtime = VisionRuntime(
        providers: <VisionProvider>[provider],
        store: store,
        audit: audit,
      );
      final job = await runtime.submit(
        id: 'meal-1',
        kind: VisionJobKind.meal,
        bytes: <int>[1, 2, 3],
        at: DateTime.utc(2026),
        consent: GlobalConsentGrant(
          scope: 'vision',
          state: GlobalConsentState.granted,
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(job.status, VisionJobStatus.accepted);
      expect(job.attempts, 2);
      expect((await store.get('vision_jobs', 'meal-1'))?['status'], 'accepted');
      await runtime.review(
        id: 'meal-1',
        accept: true,
        corrections: const <String, String>{'food': 'chicken breast'},
        at: DateTime.utc(2026, 1, 2),
      );
      expect((await store.get('vision_feedback', 'meal-1'))?['accepted'], true);
      expect(
        audit.events.map((event) => event.action),
        containsAll(<String>['vision.completed', 'vision.reviewed']),
      );
    },
  );

  test(
    'vision never persists raw image bytes and consent withdrawal removes durable jobs',
    () async {
      final store = InMemoryGlobalStore();
      final runtime = VisionRuntime(
        providers: <VisionProvider>[_FlakyVision(0)],
        store: store,
      );
      await runtime.submit(
        id: 'label-1',
        kind: VisionJobKind.label,
        bytes: <int>[9, 8, 7],
        at: DateTime.utc(2026),
        consent: GlobalConsentGrant(
          scope: 'vision',
          state: GlobalConsentState.granted,
          updatedAt: DateTime.utc(2026),
        ),
      );
      final persisted = await store.get('vision_jobs', 'label-1');
      expect(persisted.toString(), isNot(contains('9, 8, 7')));
      await runtime.withdrawConsent();
      expect(await store.list('vision_jobs'), isEmpty);
    },
  );
}
