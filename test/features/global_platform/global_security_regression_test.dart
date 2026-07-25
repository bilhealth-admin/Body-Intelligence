import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure fingerprints are SHA-256 and deterministic', () {
    final first = SecureFingerprint.ofText('receipt-payload');
    final second = SecureFingerprint.ofText('receipt-payload');
    final changed = SecureFingerprint.ofText('receipt-payload-2');
    expect(first, second);
    expect(first, hasLength(64));
    expect(first, isNot(changed));
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(first), isTrue);
  });
}
