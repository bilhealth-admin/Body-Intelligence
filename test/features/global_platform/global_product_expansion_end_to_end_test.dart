import 'global_platform_test_support.dart';

void main() {
  test(
    'eleven modules participate through one global composition root',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final health = UnifiedHealthDataRuntime(
        bridges: [TestHealthBridge()],
        store: store,
        audit: audit,
      );
      final wearable = WearableRuntime(
        providers: [TestWearable()],
        store: store,
        audit: audit,
      );
      final fitness = FitnessDeviceRuntime(
        providers: [TestFitness()],
        store: store,
        audit: audit,
      );
      final vision = VisionRuntime(
        provider: TestVision(),
        store: store,
        audit: audit,
      );
      final cloud = OptionalCloudAiRuntime(
        providers: [TestCloudAi()],
        store: store,
        audit: audit,
        monthlyTokenBudget: 100,
      );
      final plugins = PluginRegistry(
        store: store,
        audit: audit,
        coreVersion: '1.0.0',
      );
      final reports = ScientificReportRuntime();
      final professional = ProfessionalRuntime(store: store, audit: audit);
      final commerce = CommerceRuntime(
        store: store,
        audit: audit,
        verifiers: [TestVerifier()],
        productFeatures: {
          'premium': {'reports'},
        },
      );
      final globalization = GlobalizationRuntime(
        catalogs: [
          const GlobalLocaleCatalog('en', {'status': 'Status'}),
          const GlobalLocaleCatalog('ar', {'status': 'الحالة'}),
        ],
        requiredKeys: {'status'},
      );
      final runtime = const BilGlobalProductExpansionCompositionRoot().create(
        health: health,
        wearables: wearable,
        fitness: fitness,
        vision: vision,
        cloudAi: cloud,
        plugins: plugins,
        reports: reports,
        professional: professional,
        commerce: commerce,
        globalization: globalization,
        audit: audit,
        store: store,
      );
      final state = await runtime.synchronize(
        asOf: DateTime.utc(2026),
        healthConsent: GlobalConsentGrant(
          scope: 'health',
          state: GlobalConsentState.granted,
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(state.capabilityCount, greaterThanOrEqualTo(5));
      expect(state.healthSignals, isNotEmpty);
      expect(state.fitnessMeasurements, isNotEmpty);
      expect(state.productStates.length, 11);
      expect(state.status, GlobalRuntimeStatus.blocked);
    },
  );
}
