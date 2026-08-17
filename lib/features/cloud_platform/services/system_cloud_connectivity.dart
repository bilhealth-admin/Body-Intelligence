import 'package:connectivity_plus/connectivity_plus.dart';

import 'cloud_platform_ports.dart';

/// One-shot system connectivity snapshot for a future live cloud-sync run.
///
/// Phase 3D-A deliberately prepares this adapter without wiring it into the
/// production coordinator. The active runtime continues to use
/// [CloudTransportActivationLock] until the live-sync gate is explicitly
/// opened in a later phase.
final class SystemCloudConnectivitySnapshot implements CloudConnectivity {
  const SystemCloudConnectivitySnapshot._(this.isOnline);

  @override
  final bool isOnline;

  factory SystemCloudConnectivitySnapshot.fromResults(
    Iterable<ConnectivityResult> results,
  ) {
    final values = results.toSet();
    return SystemCloudConnectivitySnapshot._(
      values.isNotEmpty &&
          values.any((result) => result != ConnectivityResult.none),
    );
  }

  static Future<SystemCloudConnectivitySnapshot> current({
    Connectivity? connectivity,
  }) async {
    final results = await (connectivity ?? Connectivity()).checkConnectivity();
    return SystemCloudConnectivitySnapshot.fromResults(results);
  }
}
