import 'global_platform_test_support.dart';

void main() {
  test(
    'one composition root orchestrates all modules with consent and provenance',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final runtime = const BilGlobalProductExpansionCompositionRoot().create(
        health: UnifiedHealthDataRuntime(
          bridges: [TestHealthBridge()],
          store: store,
          audit: audit,
        ),
        wearables: WearableRuntime(
          providers: [TestWearable()],
          store: store,
          audit: audit,
        ),
        medical: MedicalDeviceRuntime(
          providers: [TestMedical()],
          store: store,
          audit: audit,
        ),
        vision: VisionRuntime(
          provider: TestVision(),
          store: store,
          audit: audit,
        ),
        cloudAi: OptionalCloudAiRuntime(
          providers: [TestCloudAi()],
          store: store,
          audit: audit,
          monthlyTokenBudget: 100,
        ),
        plugins: PluginRegistry(
          store: store,
          audit: audit,
          coreVersion: '1.0.0',
        ),
        reports: ScientificReportRuntime(),
        professional: ProfessionalRuntime(store: store, audit: audit),
        commerce: CommerceRuntime(
          store: store,
          audit: audit,
          verifiers: [TestVerifier()],
          productFeatures: const {
            'premium': {'reports'},
          },
        ),
        globalization: GlobalizationRuntime(
          catalogs: const [
            GlobalLocaleCatalog('en', {'x': 'x'}),
            GlobalLocaleCatalog('ar', {'x': 'س'}),
          ],
          requiredKeys: const {'x'},
        ),
        audit: audit,
        store: store,
      );

      final state = await runtime.synchronize(
        asOf: DateTime.utc(2026),
        healthConsent: GlobalConsentGrant(
          scope: 'user',
          state: GlobalConsentState.granted,
          updatedAt: DateTime.utc(2026),
        ),
      );

      expect(state.capabilityCount, greaterThanOrEqualTo(5));
      expect(state.healthSignals, isNotEmpty);
      expect(state.medicalMeasurements.single.value, 120);
      expect(state.status, GlobalRuntimeStatus.blocked);
      expect(state.auditCount, greaterThan(0));
    },
  );
}
