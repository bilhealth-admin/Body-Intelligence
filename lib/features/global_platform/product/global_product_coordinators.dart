import '../cloud_ai/optional_cloud_ai_platform.dart';
import '../commerce/commerce_platform.dart';
import '../core/global_platform_core.dart';
import '../health_data/apple_health_platform.dart';
import '../health_data/android_health_connect_platform.dart';
import '../fitness_devices/fitness_device_platform.dart';
import '../plugins/plugin_platform.dart';
import '../professional/professional_platform.dart';
import '../reports/scientific_reports_platform.dart';
import '../reports/world_class_report_platform.dart';
import '../globalization/globalization_accessibility_platform.dart';
import '../vision/computer_vision_platform.dart';
import '../wearables/wearables_platform.dart';

enum GlobalProductCapabilityStatus {
  available,
  configurationRequired,
  unavailable,
}

final class GlobalProductCapabilityState {
  const GlobalProductCapabilityState({
    required this.status,
    required this.code,
  });

  final GlobalProductCapabilityStatus status;
  final String code;

  bool get available => status == GlobalProductCapabilityStatus.available;
}

final class GlobalProductFlows {
  GlobalProductFlows({
    required this.appleHealth,
    required this.healthConnect,
    required this.plugins,
    required this.globalization,
    required this.vision,
    required this.cloudAi,
    required this.wearables,
    required this.fitness,
    required this.reports,
    required this.professional,
    required this.commerce,
    required this.store,
    required this.audit,
    required Map<String, GlobalProductCapabilityState> capabilities,
  }) : capabilities = Map<String, GlobalProductCapabilityState>.unmodifiable(
         capabilities,
       );

  final AppleHealthRuntime appleHealth;
  final HealthConnectRuntime healthConnect;
  final PluginRegistry plugins;
  final GlobalizationRuntime globalization;
  final VisionRuntime? vision;
  final OptionalCloudAiRuntime? cloudAi;
  final WearableRuntime wearables;
  final FitnessDeviceRuntime fitness;
  final WorldClassReportRuntime reports;
  final ProfessionalRuntime professional;
  final CommerceRuntime? commerce;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final Map<String, GlobalProductCapabilityState> capabilities;

  Future<Map<String, Object?>> synchronizeHealth(DateTime asOf) async {
    final wearable = await wearables.synchronize(asOf);
    final measurements = await fitness.ingest(asOf);
    await store.put('product_flow_state', 'health_sync', <String, Object?>{
      'at': asOf.toUtc().toIso8601String(),
      'wearable': wearable.length,
      'fitness': measurements.length,
    });
    return <String, Object?>{'wearable': wearable, 'fitness': measurements};
  }

  Future<VisionJob> submitMealVision({
    required String jobId,
    required List<int> bytes,
    required DateTime at,
    required GlobalConsentGrant consent,
    String locale = 'en',
  }) {
    final runtime = vision;
    if (runtime == null) {
      throw StateError(capabilities['vision']?.code ?? 'vision_unavailable');
    }
    return runtime.submit(
      id: jobId,
      kind: VisionJobKind.meal,
      bytes: bytes,
      at: at,
      consent: consent,
      locale: locale,
    );
  }

  Future<CloudAiResponse?> optionalAssistant({
    required CloudAiRequest request,
    required GlobalConsentGrant consent,
    required bool localOnly,
    required DateTime at,
  }) {
    final runtime = cloudAi;
    if (runtime == null) {
      return Future<CloudAiResponse?>.value(null);
    }
    return runtime.run(
      request: request,
      consent: consent,
      localOnly: localOnly,
      at: at,
    );
  }

  Future<ReportRenderResult> generateReport(
    ScientificReport report, {
    required bool rtl,
  }) => reports.render(
    report,
    theme: ReportTheme(
      rtl: rtl,
      locale: report.locale,
      title: rtl ? 'تقرير BIL الصحي' : 'BIL Health Report',
      footer: 'BIL • evidence-first',
    ),
  );

  Future<Map<String, Object?>> synchronizeAppleHealth(
    DateTime asOf, {
    required GlobalConsentGrant consent,
  }) async {
    final result = await appleHealth.synchronize(asOf: asOf, consent: consent);
    return <String, Object?>{'records': result.length};
  }

  Future<Map<String, Object?>> synchronizeHealthConnect(
    DateTime asOf, {
    required GlobalConsentGrant consent,
  }) async {
    final result = await healthConnect.synchronize(
      asOf: asOf,
      consent: consent,
    );
    return <String, Object?>{'records': result.length};
  }

  String localize(String locale, String key) => globalization.text(locale, key);

  bool get hasActiveBuiltInPlugin =>
      plugins.active.any((record) => record.manifest.id == 'bil.core.evidence');

  Future<bool> canShare({
    required String subject,
    required String workspace,
    required String scope,
    required DateTime at,
  }) => professional.permits(subject, workspace, scope, at);

  Future<bool> hasEntitlement({
    required String account,
    required String feature,
    required DateTime at,
  }) {
    final runtime = commerce;
    if (runtime == null) {
      return Future<bool>.value(false);
    }
    return runtime.has(account, feature, at);
  }
}
