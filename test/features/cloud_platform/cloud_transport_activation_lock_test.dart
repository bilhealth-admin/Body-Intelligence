import 'package:body_intelligence_log/features/cloud_platform/services/cloud_transport_activation_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase 3 transport lock is always offline', () {
    expect(const CloudTransportActivationLock().isOnline, isFalse);
  });
}
