import '../core/global_platform_core.dart';
import '../platform/native_platform_bridges.dart';
import 'unified_health_data_integration.dart';

final class AppleHealthRuntime {
  AppleHealthRuntime({
    required this.bridge,
    required this.store,
    required this.audit,
  }) : integration = UnifiedHealthDataRuntime(
         bridges: <NativeHealthBridge>[bridge],
         store: store,
         audit: audit,
       );

  factory AppleHealthRuntime.methodChannel({
    required GlobalDurableStore store,
    required GlobalAuditSink audit,
  }) => AppleHealthRuntime(
    bridge: MethodChannelHealthBridge(channelName: 'bil/apple_health'),
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

  Future<void> export({
    required List<GlobalHealthSignal> signals,
    required GlobalConsentGrant consent,
  }) => integration.export(
    bridge: bridge,
    writeConsent: consent,
    signals: signals,
  );
}
