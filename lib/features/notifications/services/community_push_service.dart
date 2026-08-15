import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/community_push_preferences.dart';

abstract interface class PushTokenProvider {
  Future<String?> requestToken();
  Future<void> deleteToken();
}

class NativePushTokenProvider implements PushTokenProvider {
  const NativePushTokenProvider();

  static const _channel = MethodChannel('bil/push');

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
}
