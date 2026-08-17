import 'cloud_platform_ports.dart';

/// Phase-3 safety lock: the production runtime may create its encrypted local
/// ledger and durable outbox, but transport stays offline until inbound
/// application/merge is closed in the next phase.
final class CloudTransportActivationLock implements CloudConnectivity {
  const CloudTransportActivationLock();

  @override
  bool get isOnline => false;
}
