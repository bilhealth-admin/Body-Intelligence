import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/system_cloud_connectivity.dart';

void main() {
  test('none and empty snapshots are offline', () {
    expect(
      SystemCloudConnectivitySnapshot.fromResults(const []).isOnline,
      isFalse,
    );
    expect(
      SystemCloudConnectivitySnapshot.fromResults(const [
        ConnectivityResult.none,
      ]).isOnline,
      isFalse,
    );
  });

  test('any usable transport marks the snapshot online', () {
    expect(
      SystemCloudConnectivitySnapshot.fromResults(const [
        ConnectivityResult.wifi,
      ]).isOnline,
      isTrue,
    );
    expect(
      SystemCloudConnectivitySnapshot.fromResults(const [
        ConnectivityResult.none,
        ConnectivityResult.mobile,
      ]).isOnline,
      isTrue,
    );
  });
}
