import 'dart:async';

import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'remote AI consent read fails closed after the bounded timeout',
    () async {
      final gateway = BoundedOnboardingRemoteAiGateway(
        _HangingRemoteAiGateway(),
        timeout: const Duration(milliseconds: 1),
      );

      expect(await gateway.read(), OnboardingRemoteAiResult.failed);
    },
  );

  test(
    'remote AI consent write fails closed after the bounded timeout',
    () async {
      final gateway = BoundedOnboardingRemoteAiGateway(
        _HangingRemoteAiGateway(),
        timeout: const Duration(milliseconds: 1),
      );

      expect(await gateway.setGranted(true), OnboardingRemoteAiResult.failed);
    },
  );

  test('bounded gateway preserves a completed consent result', () async {
    final gateway = BoundedOnboardingRemoteAiGateway(
      const _CompletedRemoteAiGateway(),
      timeout: const Duration(seconds: 1),
    );

    expect(await gateway.read(), OnboardingRemoteAiResult.declined);
    expect(await gateway.setGranted(true), OnboardingRemoteAiResult.granted);
  });
}

final class _HangingRemoteAiGateway implements OnboardingRemoteAiGateway {
  @override
  Future<OnboardingRemoteAiResult> read() =>
      Completer<OnboardingRemoteAiResult>().future;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) =>
      Completer<OnboardingRemoteAiResult>().future;
}

final class _CompletedRemoteAiGateway implements OnboardingRemoteAiGateway {
  const _CompletedRemoteAiGateway();

  @override
  Future<OnboardingRemoteAiResult> read() async =>
      OnboardingRemoteAiResult.declined;

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async => granted
      ? OnboardingRemoteAiResult.granted
      : OnboardingRemoteAiResult.declined;
}
