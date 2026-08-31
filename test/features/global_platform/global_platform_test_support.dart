import 'package:body_intelligence_log/features/global_platform/cloud_ai/optional_cloud_ai_platform.dart';
import 'package:body_intelligence_log/features/global_platform/commerce/commerce_platform.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/fitness_device_platform.dart';
import 'package:body_intelligence_log/features/global_platform/plugins/plugin_platform.dart';
import 'package:body_intelligence_log/features/global_platform/vision/computer_vision_platform.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/wearables_platform.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:body_intelligence_log/features/global_platform/cloud_ai/optional_cloud_ai_platform.dart';
export 'package:body_intelligence_log/features/global_platform/commerce/commerce_platform.dart';
export 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
export 'package:body_intelligence_log/features/global_platform/globalization/globalization_accessibility_platform.dart';
export 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
export 'package:body_intelligence_log/features/global_platform/fitness_devices/fitness_device_platform.dart';
export 'package:body_intelligence_log/features/global_platform/plugins/plugin_platform.dart';
export 'package:body_intelligence_log/features/global_platform/professional/professional_platform.dart';
export 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
export 'package:body_intelligence_log/features/global_platform/runtime/bil_global_product_expansion_runtime.dart';
export 'package:body_intelligence_log/features/global_platform/vision/computer_vision_platform.dart';
export 'package:body_intelligence_log/features/global_platform/wearables/wearables_platform.dart';
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';

final class TestHealthBridge implements NativeHealthBridge {
  @override
  String get id => 'test-health';
  @override
  Future<void> delete(List<String> recordIds) async {}
  @override
  Future<Map<String, bool>> permissions() async => {
    'weight': true,
    'steps': true,
  };
  @override
  Future<void> request(Set<String> types, {required bool write}) async {}
  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => NativeHealthPage(
    records: [
      NativeHealthRecord(
        id: 'w1',
        type: HealthDataType.weight,
        value: 220.46226218,
        unit: 'lb',
        observedAt: asOf.subtract(const Duration(days: 1)),
        sourceId: 'device',
        deviceId: 'watch',
        confidence: .9,
        providerId: id,
      ),
    ],
    deletedIds: const [],
    nextAnchor: 'a1',
    hasMore: false,
  );
  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}
}

final class TestWearable implements WearableProvider {
  @override
  String get id => 'garmin';
  @override
  Future<Set<String>> capabilities() async => {'steps', 'sleep'};
  @override
  Future<WearableSyncBatch> pull({
    required String? cursor,
    required DateTime asOf,
  }) async => WearableSyncBatch(
    deletedIds: const [],
    signals: [
      GlobalHealthSignal(
        key: 'steps',
        canonicalValue: 8000,
        canonicalUnit: 'count',
        provenance: GlobalProvenance(
          providerId: id,
          sourceId: 'watch',
          recordId: 's1',
          observedAt: asOf.subtract(const Duration(hours: 2)),
          confidence: .85,
          deviceId: 'g1',
        ),
      ),
    ],
    nextCursor: 'c1',
    hasMore: false,
  );
  @override
  Future<void> revoke() async {}
}

final class TestFitness implements FitnessDeviceProvider {
  @override
  String get id => 'fitness';
  @override
  Future<List<FitnessDeviceIdentity>> discover() async => const [
    FitnessDeviceIdentity(
      id: 'scale1',
      kind: 'weight_scale',
      manufacturer: 'BIL',
      calibrationState: 'calibrated',
    ),
  ];
  @override
  Future<List<FitnessMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  }) async => [
    FitnessMeasurement(
      deviceId: deviceId,
      kind: 'weight',
      value: 80,
      unit: 'kg',
      observedAt: asOf.subtract(const Duration(minutes: 1)),
      confidence: .95,
      calibrated: true,
      provenance: 'bluetooth',
      sampleId: 'm1',
    ),
  ];
}

final class TestVision implements VisionProvider {
  @override
  String get id => 'vision';
  @override
  Set<VisionJobKind> get capabilities => VisionJobKind.values.toSet();
  @override
  Future<List<VisionFinding>> analyze(
    VisionJobKind kind,
    List<int> bytes, {
    required String locale,
  }) async => const [
    VisionFinding(
      key: 'food',
      value: 'chicken',
      confidence: .91,
      provenance: 'vision:1',
      rangeMin: 120,
      rangeMax: 180,
    ),
  ];
}

final class TestCloudAi implements CloudAiProvider {
  @override
  String get id => 'cloud';
  @override
  Set<String> get capabilities => {'summary'};
  @override
  Future<CloudAiResponse> execute(CloudAiRequest request) async =>
      const CloudAiResponse(
        providerId: 'cloud',
        modelId: 'm',
        output: 'summary',
        usageTokens: 20,
        provenance: 'cloud:m:1',
        safe: true,
      );
}

final class TestLifecycle implements PluginLifecycle {
  @override
  String get pluginId => 'p';
  bool started = false;
  @override
  Future<void> migrate(String fromVersion, String toVersion) async {}
  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }
}

final class TestVerifier implements StoreReceiptVerifier {
  @override
  String get providerId => 'store';
  @override
  Future<List<List<int>>> restore(String accountId) async => const [];
  @override
  Future<ReceiptVerificationResult> verify(List<int> receipt) async =>
      ReceiptVerificationResult(
        valid: true,
        transactionId: 't1',
        accountId: 'a1',
        productId: 'premium',
        expiresAt: DateTime.utc(2030),
        revoked: false,
      );
}
