import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/community_push_preferences.dart';

abstract interface class PushTokenProvider {
  Future<PushProviderCapability> capability();
  Future<String?> requestToken();
  Future<void> deleteToken();
}

class PushProviderCapability {
  const PushProviderCapability({
    required this.configured,
    required this.tokenRegistration,
    required this.remoteTapRouting,
    required this.provider,
  });

  const PushProviderCapability.unavailable()
    : configured = false,
      tokenRegistration = false,
      remoteTapRouting = false,
      provider = 'unavailable';

  factory PushProviderCapability.fromMap(Map<Object?, Object?> map) =>
      PushProviderCapability(
        configured: map['configured'] == true,
        tokenRegistration: map['tokenRegistration'] == true,
        remoteTapRouting: map['remoteTapRouting'] == true,
        provider: map['provider']?.toString().trim() ?? 'unknown',
      );

  final bool configured;
  final bool tokenRegistration;
  final bool remoteTapRouting;
  final String provider;

  bool get ready => configured && tokenRegistration && remoteTapRouting;
}

class NativePushTokenProvider implements PushTokenProvider {
  const NativePushTokenProvider();

  static const _channel = MethodChannel('bil/push');

  @override
  Future<PushProviderCapability> capability() async {
    try {
      final status = await _channel.invokeMethod<Map<Object?, Object?>>(
        'providerStatus',
      );
      if (status == null) return const PushProviderCapability.unavailable();
      return PushProviderCapability.fromMap(status);
    } on MissingPluginException {
      return const PushProviderCapability.unavailable();
    } on PlatformException {
      return const PushProviderCapability.unavailable();
    }
  }

  @override
  Future<String?> requestToken() =>
      _channel.invokeMethod<String>('requestToken');

  @override
  Future<void> deleteToken() => _channel.invokeMethod<void>('deleteToken');
}

class CommunityPushService {
  CommunityPushService(this._client, {PushTokenProvider? tokenProvider})
    : _tokenProvider = tokenProvider ?? const NativePushTokenProvider();

  final SupabaseClient _client;
  final PushTokenProvider _tokenProvider;

  static bool get isAvailable =>
      AppEnvironment.pushConfigured && (Platform.isAndroid || Platform.isIOS);

  Future<void> setEnabled(bool enabled) async {
    if (!isAvailable) throw StateError('Push is not configured');
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign-in required');
    if (!enabled) {
      await _client.rpc('bil_disable_push_tokens');
      await _tokenProvider.deleteToken();
      return;
    }
    if (Platform.isAndroid && !await _androidProviderReady()) {
      throw StateError('Android push provider is not ready');
    }
    final token = await _tokenProvider.requestToken();
    if (token == null || token.isEmpty) {
      throw StateError('Push permission or native configuration unavailable');
    }
    final local = await FlutterTimezone.getLocalTimezone();
    await _client.rpc(
      'bil_register_push_token',
      params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'apns' : 'fcm',
        'p_timezone': local.identifier,
        'p_sensitive_preview_allowed': false,
      },
    );
  }

  Future<void> setSensitivePreviewAllowed(bool allowed) => _client.rpc(
    'bil_set_sensitive_push_previews',
    params: {'p_allowed': allowed},
  );

  Future<CommunityPushPreferences> loadPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null || !isAvailable) {
      return const CommunityPushPreferences(enabled: false, timeZone: 'UTC');
    }
    if (Platform.isAndroid && !await _androidProviderReady()) {
      return const CommunityPushPreferences(
        enabled: false,
        timeZone: 'UTC',
        providerReady: false,
      );
    }
    final response = await _client.rpc('bil_get_push_preferences');
    final rows = (response as List).cast<Map<String, dynamic>>();
    final row = rows.isEmpty ? null : rows.first;
    return CommunityPushPreferences(
      enabled: row?['enabled'] as bool? ?? false,
      timeZone: row?['timezone'] as String? ?? 'UTC',
      sensitivePreviewAllowed:
          row?['sensitive_preview_allowed'] as bool? ?? false,
    );
  }

  Future<bool> _androidProviderReady() async {
    final capability = await _tokenProvider.capability();
    return capability.ready;
  }
}
