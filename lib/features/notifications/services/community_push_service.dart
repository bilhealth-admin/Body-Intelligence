import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../community/services/community_owner_operation.dart';
import '../domain/community_push_preferences.dart';
import '../domain/community_push_delivery_categories.dart';
import '../domain/notification_delivery_preferences.dart';

abstract interface class PushTokenProvider {
  Future<PushProviderCapability> capability();
  Future<String?> existingPermissionToken();
  Future<String?> requestToken();
  Future<void> deleteToken();
}

class PushProviderCapability {
  const PushProviderCapability({
    required this.configured,
    required this.tokenRegistration,
    required this.remoteTapRouting,
    required this.permissionGranted,
    required this.provider,
  });

  const PushProviderCapability.unavailable()
    : configured = false,
      tokenRegistration = false,
      remoteTapRouting = false,
      permissionGranted = false,
      provider = 'unavailable';

  factory PushProviderCapability.fromMap(Map<Object?, Object?> map) =>
      PushProviderCapability(
        configured: map['configured'] == true,
        tokenRegistration: map['tokenRegistration'] == true,
        remoteTapRouting: map['remoteTapRouting'] == true,
        permissionGranted: map['permissionGranted'] == true,
        provider: map['provider']?.toString().trim() ?? 'unknown',
      );

  final bool configured;
  final bool tokenRegistration;
  final bool remoteTapRouting;
  final bool permissionGranted;
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
  Future<String?> existingPermissionToken() =>
      _channel.invokeMethod<String>('existingPermissionToken');

  @override
  Future<String?> requestToken() =>
      _channel.invokeMethod<String>('requestToken');

  @override
  Future<void> deleteToken() => _channel.invokeMethod<void>('deleteToken');
}

class CommunityPushRegistrationPolicyStore {
  const CommunityPushRegistrationPolicyStore();

  static const _prefix = 'bil.community-push-explicit-opt-out.v1.';

  Future<bool> isExplicitlyDisabled(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('$_prefix$userId') ?? false;
  }

  Future<void> setExplicitlyDisabled(String userId, bool disabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_prefix$userId', disabled);
  }
}

class CommunityPushService {
  CommunityPushService(
    this._client, {
    PushTokenProvider? tokenProvider,
    CommunityPushRegistrationPolicyStore? registrationPolicyStore,
    bool Function()? availability,
    Future<String> Function()? timeZoneIdentifier,
  }) : _tokenProvider = tokenProvider ?? const NativePushTokenProvider(),
       _registrationPolicyStore =
           registrationPolicyStore ??
           const CommunityPushRegistrationPolicyStore(),
       _availability = availability ?? (() => isAvailable),
       _timeZoneIdentifier = timeZoneIdentifier ?? _deviceTimeZoneIdentifier;

  final SupabaseClient _client;
  final PushTokenProvider _tokenProvider;
  final CommunityPushRegistrationPolicyStore _registrationPolicyStore;
  final bool Function() _availability;
  final Future<String> Function() _timeZoneIdentifier;

  static Future<String> _deviceTimeZoneIdentifier() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  Future<T> _forOwner<T>(
    Future<T> Function(CommunityOwnerOperation operation) action,
  ) => CommunityOwnerOperation.run(
    client: _client,
    ownerId: _categoryOwner(),
    action: action,
  );

  static bool get isAvailable =>
      AppEnvironment.pushConfigured && (Platform.isAndroid || Platform.isIOS);

  Future<void> setEnabled(
    bool enabled, {
    required NotificationDeliveryPreferences deliveryPreferences,
  }) async {
    if (!_availability()) throw StateError('Push is not configured');
    await _forOwner<void>((operation) async {
      final owner = operation.ownerId!;
      if (!enabled) {
        try {
          await _registrationPolicyStore.setExplicitlyDisabled(owner, true);
          operation.check();
          await _client.rpc('bil_disable_push_tokens');
        } on Object {
          await _registrationPolicyStore.setExplicitlyDisabled(owner, false);
          rethrow;
        }
        operation.check();
        try {
          await _tokenProvider.deleteToken();
        } on Object {
          // Cloud delivery is already disabled and the durable opt-out prevents
          // a later resume from silently registering a replacement token.
        }
        return;
      }
      await _registrationPolicyStore.setExplicitlyDisabled(owner, false);
      operation.check();
      final capability = await _tokenProvider.capability();
      operation.check();
      if (!capability.ready) throw StateError('Push provider is not ready');
      await _requestAndRegisterCurrentToken(deliveryPreferences, operation);
    });
  }

  /// Reconciles a durable provider token after sign-in, token rotation,
  /// restart, or resume. This path never requests notification permission.
  /// An explicit master-toggle opt-out is durable per account on this device.
  Future<void> refreshRegistrationIfEnabled({
    required NotificationDeliveryPreferences deliveryPreferences,
  }) async {
    if (!_availability() || _client.auth.currentUser == null) return;
    await _forOwner<void>((operation) async {
      final disabled = await _registrationPolicyStore.isExplicitlyDisabled(
        operation.ownerId!,
      );
      operation.check();
      if (disabled) return;
      final capability = await _tokenProvider.capability();
      operation.check();
      if (!capability.ready || !capability.permissionGranted) return;
      final token = await _tokenProvider.existingPermissionToken();
      operation.check();
      if (token == null || token.isEmpty) return;
      await _registerToken(token, deliveryPreferences, operation);
    });
  }

  Future<CommunityPushDeliveryCategories> syncDeliveryPreferences(
    NotificationDeliveryPreferences deliveryPreferences, {
    required CommunityPushDeliveryCategories expectedState,
  }) => _forOwner((operation) async {
    final owner = operation.ownerId!;
    if (owner != expectedState.ownerId) {
      throw const AuthException('Notification owner changed');
    }
    final response = await _client.rpc(
      'bil_set_my_push_delivery_categories_v1',
      params: {
        ..._categoryParams(deliveryPreferences),
        'p_expected_revision': expectedState.revision,
      },
    );
    _verifyCategoryOwner(owner);
    final receipt = CommunityPushDeliveryCategories.fromReceipt(
      response,
      expectedOwnerId: owner,
    );
    final desired = deliveryPreferences.enabledCategories
        .where(NotificationDeliveryPreferences.supportedCategories.contains)
        .toSet();
    final previous = expectedState.desired;
    final unchanged =
        previous != null &&
        previous.length == desired.length &&
        previous.containsAll(desired);
    final expectedRevision = expectedState.revision + (unchanged ? 0 : 1);
    if (!receipt.verified ||
        receipt.revision != expectedRevision ||
        receipt.desired!.length != desired.length ||
        !receipt.desired!.containsAll(desired)) {
      throw StateError('Notification category save was not verified');
    }
    return receipt;
  });

  Future<CommunityPushDeliveryCategories> loadDeliveryCategories() =>
      _forOwner((operation) async {
        final owner = operation.ownerId!;
        final response = await _client.rpc(
          'bil_get_my_push_delivery_categories_v1',
        );
        _verifyCategoryOwner(owner);
        return CommunityPushDeliveryCategories.fromReceipt(
          response,
          expectedOwnerId: owner,
        );
      });

  String _categoryOwner() {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign-in required');
    return owner;
  }

  void _verifyCategoryOwner(String owner) {
    if (_client.auth.currentUser?.id != owner) {
      throw const AuthException('Notification owner changed');
    }
  }

  Future<void> setSensitivePreviewAllowed(bool allowed) => _forOwner<void>(
    (_) => _client.rpc(
      'bil_set_sensitive_push_previews',
      params: {'p_allowed': allowed},
    ),
  );

  Future<CommunityPushPreferences> loadPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null || !_availability()) {
      return const CommunityPushPreferences(enabled: false, timeZone: 'UTC');
    }
    return _forOwner((operation) async {
      final capability = await _tokenProvider.capability();
      operation.check();
      if (!capability.ready) {
        return const CommunityPushPreferences(
          enabled: false,
          timeZone: 'UTC',
          providerReady: false,
        );
      }
      final response = await _client.rpc('bil_get_push_preferences');
      operation.check();
      final categories = await loadDeliveryCategories();
      _verifyCategoryOwner(user.id);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final row = rows.isEmpty ? null : rows.first;
      return CommunityPushPreferences(
        enabled: row?['enabled'] as bool? ?? false,
        timeZone: row?['timezone'] as String? ?? 'UTC',
        sensitivePreviewAllowed:
            row?['sensitive_preview_allowed'] as bool? ?? false,
        deliveryCategories: categories,
      );
    });
  }

  Map<String, bool> _categoryParams(
    NotificationDeliveryPreferences deliveryPreferences,
  ) => deliveryPreferences.pushCategoryParameters;

  Future<void> _requestAndRegisterCurrentToken(
    NotificationDeliveryPreferences deliveryPreferences,
    CommunityOwnerOperation operation,
  ) async {
    final capability = await _tokenProvider.capability();
    operation.check();
    if (!capability.ready) throw StateError('Push provider is not ready');
    final token = await _tokenProvider.requestToken();
    operation.check();
    if (token == null || token.isEmpty) {
      throw StateError('Push permission or native configuration unavailable');
    }
    await _registerToken(token, deliveryPreferences, operation);
  }

  Future<void> _registerToken(
    String token,
    NotificationDeliveryPreferences deliveryPreferences,
    CommunityOwnerOperation operation,
  ) async {
    final identifier = await _timeZoneIdentifier();
    operation.check();
    await _client.rpc(
      'bil_register_push_token_v2',
      params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'apns' : 'fcm',
        'p_timezone': identifier,
        'p_sensitive_preview_allowed': false,
        ..._categoryParams(deliveryPreferences),
      },
    );
  }
}

