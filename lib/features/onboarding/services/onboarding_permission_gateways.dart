import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../notifications/services/bil_notification_service.dart';

enum OnboardingRemoteAiResult {
  granted,
  declined,
  authenticationRequired,
  failed,
}

abstract interface class OnboardingRemoteAiGateway {
  Future<OnboardingRemoteAiResult> read();
  Future<OnboardingRemoteAiResult> setGranted(bool granted);
}

/// Keeps onboarding usable when a remote consent endpoint or the underlying
/// network stalls. A timeout is deliberately fail-closed: cloud AI remains off
/// and the user receives the existing retry state instead of an endless busy
/// indicator.
final class BoundedOnboardingRemoteAiGateway
    implements OnboardingRemoteAiGateway {
  const BoundedOnboardingRemoteAiGateway(
    this.delegate, {
    this.timeout = const Duration(seconds: 12),
  });

  final OnboardingRemoteAiGateway delegate;
  final Duration timeout;

  @override
  Future<OnboardingRemoteAiResult> read() => _bounded(delegate.read());

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) =>
      _bounded(delegate.setGranted(granted));

  Future<OnboardingRemoteAiResult> _bounded(
    Future<OnboardingRemoteAiResult> operation,
  ) async {
    try {
      return await operation.timeout(timeout);
    } on TimeoutException {
      return OnboardingRemoteAiResult.failed;
    }
  }
}

final class SupabaseOnboardingRemoteAiGateway
    implements OnboardingRemoteAiGateway {
  const SupabaseOnboardingRemoteAiGateway();

  static const _rpcTimeout = Duration(seconds: 8);

  SupabaseClient? get _client {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    return Supabase.instance.client;
  }

  @override
  Future<OnboardingRemoteAiResult> read() async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return OnboardingRemoteAiResult.authenticationRequired;
    }
    try {
      final raw = await client!
          .rpc('bil_get_remote_ai_consent')
          .timeout(_rpcTimeout);
      if (raw is! Map) return OnboardingRemoteAiResult.failed;
      return raw['granted'] == true
          ? OnboardingRemoteAiResult.granted
          : OnboardingRemoteAiResult.declined;
    } on Object {
      return OnboardingRemoteAiResult.failed;
    }
  }

  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return OnboardingRemoteAiResult.authenticationRequired;
    }
    try {
      await client!
          .rpc(
            'bil_record_consent',
            params: <String, Object?>{
              'p_purpose': 'remote_ai',
              'p_policy_version': '2',
              'p_granted': granted,
            },
          )
          .timeout(_rpcTimeout);
      return granted
          ? OnboardingRemoteAiResult.granted
          : OnboardingRemoteAiResult.declined;
    } on Object {
      return OnboardingRemoteAiResult.failed;
    }
  }
}

final onboardingRemoteAiGatewayProvider = Provider<OnboardingRemoteAiGateway>(
  (_) => const BoundedOnboardingRemoteAiGateway(
    SupabaseOnboardingRemoteAiGateway(),
  ),
);

abstract interface class OnboardingNotificationGateway {
  Future<bool> requestPermission();
}

final class DeviceOnboardingNotificationGateway
    implements OnboardingNotificationGateway {
  DeviceOnboardingNotificationGateway()
    : _service = BilNotificationService(FlutterLocalNotificationsPlugin());

  final BilNotificationService _service;

  @override
  Future<bool> requestPermission() => _service.requestPermission();
}

final onboardingNotificationGatewayProvider =
    Provider<OnboardingNotificationGateway>(
      (_) => DeviceOnboardingNotificationGateway(),
    );
