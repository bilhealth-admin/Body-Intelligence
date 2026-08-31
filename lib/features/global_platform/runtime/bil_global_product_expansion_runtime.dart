import '../cloud_ai/optional_cloud_ai_platform.dart';
import '../commerce/commerce_platform.dart';
import '../core/global_platform_core.dart';
import '../globalization/globalization_accessibility_platform.dart';
import '../health_data/unified_health_data_integration.dart';
import '../intelligence/global_health_evidence_graph.dart';
import '../fitness_devices/fitness_device_platform.dart';
import '../plugins/plugin_platform.dart';
import '../professional/professional_platform.dart';
import '../reports/scientific_reports_platform.dart';
import '../vision/computer_vision_platform.dart';
import '../wearables/wearables_platform.dart';

enum GlobalModuleExecutionStatus {
  completed,
  optionalDisabled,
  consentRequired,
  noWork,
  degraded,
  blocked,
}

final class GlobalModuleExecution {
  const GlobalModuleExecution({
    required this.module,
    required this.status,
    required this.evidenceCount,
    required this.detail,
  });

  final GlobalModule module;
  final GlobalModuleExecutionStatus status;
  final int evidenceCount;
  final String detail;

  bool get operational =>
      status == GlobalModuleExecutionStatus.completed ||
      status == GlobalModuleExecutionStatus.optionalDisabled;
}

final class GlobalVisionWork {
  const GlobalVisionWork({
    required this.id,
    required this.kind,
    required this.bytes,
    required this.consent,
    this.locale = 'en',
  });

  final String id;
  final VisionJobKind kind;
  final List<int> bytes;
  final GlobalConsentGrant consent;
  final String locale;
}

final class GlobalProfessionalProbe {
  const GlobalProfessionalProbe({
    required this.subjectId,
    required this.workspaceId,
    required this.scope,
  });

  final String subjectId;
  final String workspaceId;
  final String scope;
}

final class GlobalCommerceProbe {
  const GlobalCommerceProbe({required this.accountId, required this.feature});
  final String accountId;
  final String feature;
}

final class GlobalExpansionWorkload {
  const GlobalExpansionWorkload({
    this.vision,
    this.cloudAiRequest,
    this.cloudAiConsent,
    this.localOnlyCloudAi = true,
    this.report,
    this.professionalProbe,
    this.commerceProbe,
  });

  final GlobalVisionWork? vision;
  final CloudAiRequest? cloudAiRequest;
  final GlobalConsentGrant? cloudAiConsent;
  final bool localOnlyCloudAi;
  final ScientificReport? report;
  final GlobalProfessionalProbe? professionalProbe;
  final GlobalCommerceProbe? commerceProbe;
}

final class GlobalProductExpansionState {
  const GlobalProductExpansionState({
    required this.status,
    required this.healthSignals,
    required this.fitnessMeasurements,
    required this.activePlugins,
    required this.failures,
    required this.capabilityCount,
    required this.auditCount,
    required this.productStates,
    required this.executions,
    required this.evidenceGraph,
    required this.generatedArtifacts,
  });

  final GlobalRuntimeStatus status;
  final List<GlobalHealthSignal> healthSignals;
  final List<FitnessMeasurement> fitnessMeasurements;
  final int activePlugins;
  final int capabilityCount;
  final int auditCount;
  final List<GlobalFailure> failures;
  final Map<GlobalModule, String> productStates;
  final Map<GlobalModule, GlobalModuleExecution> executions;
  final GlobalEvidenceGraphSnapshot evidenceGraph;
  final List<GlobalBinaryArtifact> generatedArtifacts;
}

final class BilGlobalProductExpansionRuntime {
  BilGlobalProductExpansionRuntime({
    required this.health,
    required this.wearables,
    required this.fitness,
    required this.vision,
    required this.cloudAi,
    required this.plugins,
    required this.reports,
    required this.professional,
    required this.commerce,
    required this.globalization,
    required this.audit,
    required this.evidenceGraphEngine,
  });

  final UnifiedHealthDataRuntime health;
  final WearableRuntime wearables;
  final FitnessDeviceRuntime fitness;
  final VisionRuntime vision;
  final OptionalCloudAiRuntime cloudAi;
  final PluginRegistry plugins;
  final ScientificReportRuntime reports;
  final ProfessionalRuntime professional;
  final CommerceRuntime commerce;
  final GlobalizationRuntime globalization;
  final GlobalAuditSink audit;
  final BilGlobalHealthEvidenceGraphEngine evidenceGraphEngine;

  Future<GlobalProductExpansionState> synchronize({
    required DateTime asOf,
    required GlobalConsentGrant healthConsent,
    GlobalExpansionWorkload workload = const GlobalExpansionWorkload(),
  }) async {
    final utcAsOf = asOf.toUtc();
    final failures = <GlobalFailure>[];
    final signals = <GlobalHealthSignal>[];
    final executions = <GlobalModule, GlobalModuleExecution>{};
    final artifacts = <GlobalBinaryArtifact>[];

    if (!healthConsent.permits) {
      executions[GlobalModule.appleHealth] = const GlobalModuleExecution(
        module: GlobalModule.appleHealth,
        status: GlobalModuleExecutionStatus.consentRequired,
        evidenceCount: 0,
        detail: 'Health read consent is required.',
      );
      executions[GlobalModule.healthConnect] = const GlobalModuleExecution(
        module: GlobalModule.healthConnect,
        status: GlobalModuleExecutionStatus.consentRequired,
        evidenceCount: 0,
        detail: 'Health read consent is required.',
      );
    } else {
      try {
        final imported = await health.synchronize(
          asOf: utcAsOf,
          consent: healthConsent,
        );
        signals.addAll(imported);
        final hasAppleBridge = health.bridges.any((bridge) {
          final id = bridge.id.toLowerCase();
          return id.contains('apple') || id.contains('healthkit');
        });
        final hasAndroidBridge = health.bridges.any((bridge) {
          final id = bridge.id.toLowerCase();
          return id.contains('android') || id.contains('healthconnect');
        });
        final appleEvidence = imported.where((signal) {
          final id = signal.provenance.providerId.toLowerCase();
          return id.contains('apple') || id.contains('healthkit');
        }).length;
        final androidEvidence = imported.where((signal) {
          final id = signal.provenance.providerId.toLowerCase();
          return id.contains('android') || id.contains('healthconnect');
        }).length;
        executions[GlobalModule.appleHealth] = GlobalModuleExecution(
          module: GlobalModule.appleHealth,
          status: hasAppleBridge
              ? GlobalModuleExecutionStatus.completed
              : GlobalModuleExecutionStatus.noWork,
          evidenceCount: appleEvidence,
          detail: hasAppleBridge
              ? 'Incremental HealthKit synchronization completed.'
              : 'No HealthKit bridge is registered.',
        );
        executions[GlobalModule.healthConnect] = GlobalModuleExecution(
          module: GlobalModule.healthConnect,
          status: hasAndroidBridge
              ? GlobalModuleExecutionStatus.completed
              : GlobalModuleExecutionStatus.noWork,
          evidenceCount: androidEvidence,
          detail: hasAndroidBridge
              ? 'Incremental Health Connect synchronization completed.'
              : 'No Health Connect bridge is registered.',
        );
      } catch (error) {
        failures.add(
          const GlobalFailure(
            module: GlobalModule.appleHealth,
            kind: GlobalFailureKind.unavailable,
            code: 'health-sync',
            retryable: true,
          ),
        );
        executions[GlobalModule.appleHealth] = GlobalModuleExecution(
          module: GlobalModule.appleHealth,
          status: GlobalModuleExecutionStatus.degraded,
          evidenceCount: 0,
          detail: error.runtimeType.toString(),
        );
        executions[GlobalModule.healthConnect] = GlobalModuleExecution(
          module: GlobalModule.healthConnect,
          status: GlobalModuleExecutionStatus.degraded,
          evidenceCount: 0,
          detail: error.runtimeType.toString(),
        );
      }
    }

    try {
      final imported = await wearables.synchronize(utcAsOf);
      signals.addAll(imported);
      executions[GlobalModule.wearables] = GlobalModuleExecution(
        module: GlobalModule.wearables,
        status: GlobalModuleExecutionStatus.completed,
        evidenceCount: imported.length,
        detail: 'Provider reconciliation and cursor persistence completed.',
      );
    } catch (error) {
      failures.add(
        const GlobalFailure(
          module: GlobalModule.wearables,
          kind: GlobalFailureKind.unavailable,
          code: 'wearable-sync',
          retryable: true,
        ),
      );
      executions[GlobalModule.wearables] = GlobalModuleExecution(
        module: GlobalModule.wearables,
        status: GlobalModuleExecutionStatus.degraded,
        evidenceCount: 0,
        detail: error.runtimeType.toString(),
      );
    }

    var measurements = const <FitnessMeasurement>[];
    try {
      measurements = await fitness.ingest(utcAsOf);
      executions[GlobalModule.fitnessDevices] = GlobalModuleExecution(
        module: GlobalModule.fitnessDevices,
        status: GlobalModuleExecutionStatus.completed,
        evidenceCount: measurements.length,
        detail:
            'Validated fitness measurements ingested with device provenance.',
      );
    } catch (error) {
      failures.add(
        const GlobalFailure(
          module: GlobalModule.fitnessDevices,
          kind: GlobalFailureKind.invalidData,
          code: 'fitness-ingest',
          retryable: true,
        ),
      );
      executions[GlobalModule.fitnessDevices] = GlobalModuleExecution(
        module: GlobalModule.fitnessDevices,
        status: GlobalModuleExecutionStatus.degraded,
        evidenceCount: 0,
        detail: error.runtimeType.toString(),
      );
    }

    if (workload.vision == null) {
      executions[GlobalModule.vision] = const GlobalModuleExecution(
        module: GlobalModule.vision,
        status: GlobalModuleExecutionStatus.noWork,
        evidenceCount: 0,
        detail: 'No user-authorized vision job was queued.',
      );
    } else {
      final request = workload.vision!;
      final result = await vision.submit(
        id: request.id,
        kind: request.kind,
        bytes: request.bytes,
        at: utcAsOf,
        consent: request.consent,
        locale: request.locale,
      );
      executions[GlobalModule.vision] = GlobalModuleExecution(
        module: GlobalModule.vision,
        status: result.status == VisionJobStatus.failed
            ? GlobalModuleExecutionStatus.degraded
            : GlobalModuleExecutionStatus.completed,
        evidenceCount: result.findings.length,
        detail: result.status.name,
      );
      if (result.status == VisionJobStatus.failed) {
        failures.add(
          const GlobalFailure(
            module: GlobalModule.vision,
            kind: GlobalFailureKind.unavailable,
            code: 'vision-job',
            retryable: true,
          ),
        );
      }
    }

    if (workload.cloudAiRequest == null || workload.localOnlyCloudAi) {
      executions[GlobalModule.cloudAi] = const GlobalModuleExecution(
        module: GlobalModule.cloudAi,
        status: GlobalModuleExecutionStatus.optionalDisabled,
        evidenceCount: 0,
        detail:
            'Local-only mode retained BIL local intelligence as the decision authority.',
      );
    } else {
      final response = await cloudAi.run(
        request: workload.cloudAiRequest!,
        consent:
            workload.cloudAiConsent ??
            GlobalConsentGrant(
              scope: 'cloud-ai',
              state: GlobalConsentState.denied,
              updatedAt: utcAsOf,
            ),
        localOnly: false,
        at: utcAsOf,
      );
      executions[GlobalModule.cloudAi] = GlobalModuleExecution(
        module: GlobalModule.cloudAi,
        status: response == null
            ? GlobalModuleExecutionStatus.consentRequired
            : GlobalModuleExecutionStatus.completed,
        evidenceCount: response == null ? 0 : 1,
        detail:
            response?.provenance ??
            'Cloud AI request was safely refused or abstained.',
      );
    }

    await plugins.restore();
    executions[GlobalModule.plugins] = GlobalModuleExecution(
      module: GlobalModule.plugins,
      status: GlobalModuleExecutionStatus.completed,
      evidenceCount: plugins.active.length,
      detail:
          'Versioned plugin registry restored with compatibility and security review gates.',
    );

    if (workload.report == null) {
      executions[GlobalModule.reports] = const GlobalModuleExecution(
        module: GlobalModule.reports,
        status: GlobalModuleExecutionStatus.noWork,
        evidenceCount: 0,
        detail: 'No report generation request was queued.',
      );
    } else {
      final report = workload.report!;
      artifacts.add(
        GlobalBinaryArtifact(
          mimeType: 'application/pdf',
          fileName: '${report.id}.pdf',
          bytes: reports.pdf(report),
        ),
      );
      artifacts.add(
        GlobalBinaryArtifact(
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: '${report.id}.xlsx',
          bytes: reports.xlsx(report),
        ),
      );
      artifacts.add(
        GlobalBinaryArtifact(
          mimeType: 'text/csv',
          fileName: '${report.id}.csv',
          bytes: reports.csv(report),
        ),
      );
      artifacts.add(
        GlobalBinaryArtifact(
          mimeType: 'application/json',
          fileName: '${report.id}.json',
          bytes: reports.json(report),
        ),
      );
      executions[GlobalModule.reports] = GlobalModuleExecution(
        module: GlobalModule.reports,
        status: GlobalModuleExecutionStatus.completed,
        evidenceCount: artifacts.length,
        detail: 'Deterministic PDF, XLSX, CSV, and JSON artifacts generated.',
      );
    }

    if (workload.professionalProbe == null) {
      executions[GlobalModule.professional] = const GlobalModuleExecution(
        module: GlobalModule.professional,
        status: GlobalModuleExecutionStatus.noWork,
        evidenceCount: 0,
        detail: 'No professional access evaluation was requested.',
      );
    } else {
      final probe = workload.professionalProbe!;
      final allowed = await professional.permits(
        probe.subjectId,
        probe.workspaceId,
        probe.scope,
        utcAsOf,
      );
      executions[GlobalModule.professional] = GlobalModuleExecution(
        module: GlobalModule.professional,
        status: allowed
            ? GlobalModuleExecutionStatus.completed
            : GlobalModuleExecutionStatus.blocked,
        evidenceCount: allowed ? 1 : 0,
        detail: allowed
            ? 'Revocable scoped access grant validated.'
            : 'Access denied by durable RBAC and consent state.',
      );
    }

    if (workload.commerceProbe == null) {
      executions[GlobalModule.commerce] = const GlobalModuleExecution(
        module: GlobalModule.commerce,
        status: GlobalModuleExecutionStatus.noWork,
        evidenceCount: 0,
        detail: 'No entitlement evaluation was requested.',
      );
    } else {
      final probe = workload.commerceProbe!;
      final entitled = await commerce.has(
        probe.accountId,
        probe.feature,
        utcAsOf,
      );
      executions[GlobalModule.commerce] = GlobalModuleExecution(
        module: GlobalModule.commerce,
        status: entitled
            ? GlobalModuleExecutionStatus.completed
            : GlobalModuleExecutionStatus.blocked,
        evidenceCount: entitled ? 1 : 0,
        detail: entitled
            ? 'Verified durable entitlement is active.'
            : 'Feature remains safely unavailable without entitlement.',
      );
    }

    final localizationFailures = globalization.validate();
    executions[GlobalModule.globalization] = GlobalModuleExecution(
      module: GlobalModule.globalization,
      status: localizationFailures.isEmpty
          ? GlobalModuleExecutionStatus.completed
          : GlobalModuleExecutionStatus.degraded,
      evidenceCount: globalization.catalogs.length,
      detail: localizationFailures.isEmpty
          ? 'Locale catalogs, RTL direction, units, and accessibility policy validated.'
          : localizationFailures.join(','),
    );

    final graph = await evidenceGraphEngine.build(signals);
    final completedCount = executions.values
        .where((execution) => execution.operational)
        .length;
    final blockedByConsent = executions.values.any(
      (execution) =>
          execution.status == GlobalModuleExecutionStatus.consentRequired,
    );
    final degraded = executions.values.any(
      (execution) => execution.status == GlobalModuleExecutionStatus.degraded,
    );
    final mandatoryModules = <GlobalModule>{
      GlobalModule.appleHealth,
      GlobalModule.healthConnect,
      GlobalModule.wearables,
      GlobalModule.fitnessDevices,
      GlobalModule.vision,
      GlobalModule.plugins,
      GlobalModule.reports,
      GlobalModule.professional,
      GlobalModule.commerce,
      GlobalModule.globalization,
    };
    final missingMandatoryProof = mandatoryModules.any(
      (module) =>
          executions[module]?.status != GlobalModuleExecutionStatus.completed,
    );
    final status = blockedByConsent
        ? GlobalRuntimeStatus.consentRequired
        : degraded
        ? GlobalRuntimeStatus.degraded
        : missingMandatoryProof
        ? GlobalRuntimeStatus.blocked
        : GlobalRuntimeStatus.ready;
    final productStates = <GlobalModule, String>{
      for (final entry in executions.entries)
        entry.key: entry.value.status.name,
    };

    await audit.record(
      GlobalAuditEvent(
        action: 'global.runtime.completed',
        subjectId: healthConsent.scope,
        at: utcAsOf,
        metadata: <String, Object?>{
          'signals': graph.selectedSignals.length,
          'fitness': measurements.length,
          'plugins': plugins.active.length,
          'failures': failures.length,
          'completedModules': completedCount,
          'evidenceConfidence': graph.confidence,
        },
      ),
    );

    return GlobalProductExpansionState(
      status: status,
      healthSignals: graph.selectedSignals,
      fitnessMeasurements: measurements,
      activePlugins: plugins.active.length,
      failures: List<GlobalFailure>.unmodifiable(failures),
      capabilityCount: completedCount,
      auditCount: audit is InMemoryGlobalAuditSink
          ? (audit as InMemoryGlobalAuditSink).events.length
          : 0,
      productStates: Map<GlobalModule, String>.unmodifiable(productStates),
      executions: Map<GlobalModule, GlobalModuleExecution>.unmodifiable(
        executions,
      ),
      evidenceGraph: GlobalEvidenceGraphSnapshot(graph: graph),
      generatedArtifacts: List<GlobalBinaryArtifact>.unmodifiable(artifacts),
    );
  }
}

final class BilGlobalProductExpansionCompositionRoot {
  const BilGlobalProductExpansionCompositionRoot();

  BilGlobalProductExpansionRuntime create({
    required UnifiedHealthDataRuntime health,
    required WearableRuntime wearables,
    required FitnessDeviceRuntime fitness,
    required VisionRuntime vision,
    required OptionalCloudAiRuntime cloudAi,
    required PluginRegistry plugins,
    required ScientificReportRuntime reports,
    required ProfessionalRuntime professional,
    required CommerceRuntime commerce,
    required GlobalizationRuntime globalization,
    required GlobalAuditSink audit,
    required GlobalDurableStore store,
  }) => BilGlobalProductExpansionRuntime(
    health: health,
    wearables: wearables,
    fitness: fitness,
    vision: vision,
    cloudAi: cloudAi,
    plugins: plugins,
    reports: reports,
    professional: professional,
    commerce: commerce,
    globalization: globalization,
    audit: audit,
    evidenceGraphEngine: BilGlobalHealthEvidenceGraphEngine(
      memory: SourceReliabilityMemory(store: store),
    ),
  );
}
