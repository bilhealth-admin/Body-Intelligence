import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/intelligence/global_health_evidence_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'evidence graph learns source reliability and explains deterministic conflict resolution',
    () async {
      final store = InMemoryGlobalStore();
      final memory = SourceReliabilityMemory(store: store);
      for (var index = 0; index < 4; index++) {
        await memory.record(
          sourceKey: 'healthkit:watch',
          accepted: true,
          conflicted: false,
        );
      }
      for (var index = 0; index < 3; index++) {
        await memory.record(
          sourceKey: 'manual:user',
          accepted: false,
          conflicted: true,
        );
      }
      final at = DateTime.utc(2026, 7, 24, 8);
      final graph = await BilGlobalHealthEvidenceGraphEngine(memory: memory)
          .build(<GlobalHealthSignal>[
            GlobalHealthSignal(
              key: 'weight',
              canonicalValue: 95.1,
              canonicalUnit: 'kg',
              provenance: GlobalProvenance(
                providerId: 'healthkit',
                sourceId: 'watch',
                recordId: 'a',
                observedAt: at,
                confidence: 0.82,
                deviceId: 'watch-1',
              ),
            ),
            GlobalHealthSignal(
              key: 'weight',
              canonicalValue: 96.7,
              canonicalUnit: 'kg',
              provenance: GlobalProvenance(
                providerId: 'manual',
                sourceId: 'user',
                recordId: 'b',
                observedAt: at,
                confidence: 0.88,
              ),
            ),
          ]);

      expect(graph.selectedSignals.single.canonicalValue, 95.1);
      expect(graph.conflicts, hasLength(1));
      expect(
        graph.nodes.where((node) => node.selected).single.explanation,
        contains('learned source reliability'),
      );
      expect(graph.confidence, greaterThan(0.75));
    },
  );

  test('same evidence produces the same selected identity', () async {
    Future<String> run() async {
      final store = InMemoryGlobalStore();
      final engine = BilGlobalHealthEvidenceGraphEngine(
        memory: SourceReliabilityMemory(store: store),
      );
      final at = DateTime.utc(2026, 7, 24);
      final graph = await engine.build(<GlobalHealthSignal>[
        GlobalHealthSignal(
          key: 'steps',
          canonicalValue: 1000,
          canonicalUnit: 'count',
          provenance: GlobalProvenance(
            providerId: 'b',
            sourceId: 'watch',
            recordId: '2',
            observedAt: at,
            confidence: 0.8,
          ),
        ),
        GlobalHealthSignal(
          key: 'steps',
          canonicalValue: 1000,
          canonicalUnit: 'count',
          provenance: GlobalProvenance(
            providerId: 'a',
            sourceId: 'watch',
            recordId: '1',
            observedAt: at,
            confidence: 0.8,
          ),
        ),
      ]);
      return graph.selectedSignals.single.identity;
    }

    expect(await run(), await run());
  });
}
