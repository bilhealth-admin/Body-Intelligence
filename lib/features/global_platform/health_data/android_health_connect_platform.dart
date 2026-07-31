import '../core/global_platform_core.dart';
import '../platform/native_platform_bridges.dart';
import 'unified_health_data_integration.dart';

final class HealthConnectRuntime {
  HealthConnectRuntime({
    required this.bridge,
    required this.store,
    required this.audit,
  }) : integration = UnifiedHealthDataRuntime(
         bridges: <NativeHealthBridge>[bridge],
         store: store,
         audit: audit,
       );

  factory HealthConnectRuntime.methodChannel({
    required GlobalDurableStore store,
    required GlobalAuditSink audit,
  }) => HealthConnectRuntime(
    bridge: MethodChannelHealthBridge(channelName: 'bil/health_connect'),
    store: store,
    audit: audit,
  );

  final NativeHealthBridge bridge;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final UnifiedHealthDataRuntime integration;

  Future<List<GlobalHealthSignal>> synchronize({
    required DateTime asOf,
    required GlobalConsentGrant consent,
  }) => integration.synchronize(asOf: asOf, consent: consent);
}
