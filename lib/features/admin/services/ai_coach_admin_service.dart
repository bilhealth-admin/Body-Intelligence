import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/security/bil_mobile_integrity_service.dart';

abstract interface class AiCoachAdminGateway {
  Stream<String?> watchSignedInUserId();

  Future<bool> canManageAiCoach();

  Future<AiCoachGlobalResetResult> globalReset({
    required String message,
    required String idempotencyKey,
  });

  Future<bool> individualReset({
    required String email,
    required String reason,
    required String message,
    required String idempotencyKey,
  });

  Future<AiCoachAdminNotificationResult> sendNotification({
    required AiCoachAdminNotificationKind kind,
    required AiCoachAdminNotificationAudience audience,
    String? email,
    String? message,
    required String idempotencyKey,
  });
}

enum AiCoachAdminNotificationKind {
  compensation('compensation'),
  gift('gift'),
  custom('custom');

  const AiCoachAdminNotificationKind(this.wireValue);

  final String wireValue;
}

enum AiCoachAdminNotificationAudience {
  all('all'),
  email('email');

  const AiCoachAdminNotificationAudience(this.wireValue);

  final String wireValue;
}

final class SupabaseAiCoachAdminGateway implements AiCoachAdminGateway {
  const SupabaseAiCoachAdminGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<String?> watchSignedInUserId() async* {
    var previous = _client.auth.currentUser?.id;
    yield previous;
    await for (final state in _client.auth.onAuthStateChange) {
      final ownerId = state.session?.user.id;
      if (ownerId == previous) continue;
      previous = ownerId;
      yield ownerId;
    }
  }

  @override
  Future<bool> canManageAiCoach() async {
    if (_client.auth.currentSession == null) return false;
    final value = await _client.rpc('bil_can_manage_ai_coach');
    return value == true;
  }

  @override
  Future<AiCoachGlobalResetResult> globalReset({
    required String message,
    required String idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'operation': 'global',
      'message': message.trim(),
      'idempotency_key': idempotencyKey,
    };
    final protectedBody = await BilMobileIntegrityService.instance
        .protect(action: 'admin.ai_coach.global_reset', payload: body)
        .timeout(const Duration(seconds: 12));
    final response = await _client.functions
        .invoke('ai-coach-global-reset', body: protectedBody)
        .timeout(const Duration(seconds: 20));
    if (response.status != 200 || response.data is! Map) {
      throw StateError('ai_coach_global_reset_failed');
    }
    return AiCoachGlobalResetResult.fromJson(
      Map<String, Object?>.from(response.data as Map),
    );
  }

  @override
  Future<bool> individualReset({
    required String email,
    required String reason,
    required String message,
    required String idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'operation': 'individual',
      'email': email.trim().toLowerCase(),
      'reason': reason.trim(),
      'message': message.trim(),
      'idempotency_key': idempotencyKey,
    };
    final protectedBody = await BilMobileIntegrityService.instance
        .protect(action: 'admin.ai_coach.individual_reset', payload: body)
        .timeout(const Duration(seconds: 12));
    final response = await _client.functions
        .invoke('ai-coach-global-reset', body: protectedBody)
        .timeout(const Duration(seconds: 20));
    if (response.status != 200 || response.data is! Map) {
      throw StateError('ai_coach_individual_reset_failed');
    }
    final data = Map<String, Object?>.from(response.data as Map);
    final matched = data['matched'];
    if (matched is! bool) {
      throw StateError('ai_coach_individual_reset_failed');
    }
    return matched;
  }

  @override
  Future<AiCoachAdminNotificationResult> sendNotification({
    required AiCoachAdminNotificationKind kind,
    required AiCoachAdminNotificationAudience audience,
    String? email,
    String? message,
    required String idempotencyKey,
  }) async {
    final body = <String, Object?>{
      'operation': 'notification',
      'notification_kind': kind.wireValue,
      'audience': audience.wireValue,
      if (audience == AiCoachAdminNotificationAudience.email)
        'email': email?.trim().toLowerCase(),
      if (message?.trim().isNotEmpty == true) 'message': message!.trim(),
      'idempotency_key': idempotencyKey,
    };
    final protectedBody = await BilMobileIntegrityService.instance
        .protect(action: 'admin.ai_coach.notification', payload: body)
        .timeout(const Duration(seconds: 12));
    final response = await _client.functions
        .invoke('ai-coach-global-reset', body: protectedBody)
        .timeout(const Duration(seconds: 20));
    if (response.status != 200 || response.data is! Map) {
      throw StateError('ai_coach_admin_notification_failed');
    }
    return AiCoachAdminNotificationResult.fromJson(
      Map<String, Object?>.from(response.data as Map),
    );
  }
}

final aiCoachAdminGatewayProvider = Provider<AiCoachAdminGateway>((ref) {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return const _UnavailableAiCoachAdminGateway();
  }
  return SupabaseAiCoachAdminGateway(Supabase.instance.client);
});

final aiCoachAdminSessionProvider = StreamProvider.autoDispose<String?>((ref) {
  return ref.watch(aiCoachAdminGatewayProvider).watchSignedInUserId();
});

final aiCoachAdminAccessProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final ownerId = ref.watch(aiCoachAdminSessionProvider).asData?.value;
  if (ownerId == null) return false;
  try {
    return await ref.watch(aiCoachAdminGatewayProvider).canManageAiCoach();
  } on Object {
    // Administration is fail-closed and never becomes discoverable when the
    // server cannot establish authority.
    return false;
  }
});

final class AiCoachGlobalResetResult {
  const AiCoachGlobalResetResult({
    required this.resetId,
    required this.usageRowsReset,
    required this.monthlyRowsReset,
    required this.usersNotified,
    required this.duplicate,
  });

  factory AiCoachGlobalResetResult.fromJson(Map<String, Object?> json) {
    final resetId = json['reset_id'];
    final usageRowsReset = _nonNegativeInteger(json['usage_rows_reset']);
    final monthlyRowsReset = _nonNegativeInteger(json['monthly_rows_reset']);
    final usersNotified = _nonNegativeInteger(json['users_notified']);
    final duplicate = json['duplicate'];
    final boostTokens = _nonNegativeInteger(json['boost_tokens_per_recipient']);
    final customMessageApplied = json['custom_message_applied'];
    if (resetId is! String ||
        resetId.trim().isEmpty ||
        usageRowsReset == null ||
        monthlyRowsReset == null ||
        usersNotified == null ||
        duplicate is! bool ||
        boostTokens != 2500 ||
        customMessageApplied != true) {
      throw const FormatException('invalid_ai_coach_global_reset_result');
    }
    return AiCoachGlobalResetResult(
      resetId: resetId,
      usageRowsReset: usageRowsReset,
      monthlyRowsReset: monthlyRowsReset,
      usersNotified: usersNotified,
      duplicate: duplicate,
    );
  }

  static int? _nonNegativeInteger(Object? value) {
    if (value is! num || !value.isFinite || value < 0 || value % 1 != 0) {
      return null;
    }
    return value.toInt();
  }

  final String resetId;
  final int usageRowsReset;
  final int monthlyRowsReset;
  final int usersNotified;
  final bool duplicate;
}

final class AiCoachAdminNotificationResult {
  const AiCoachAdminNotificationResult({
    required this.matched,
    required this.duplicate,
    required this.recipientsEnqueued,
  });

  factory AiCoachAdminNotificationResult.fromJson(Map<String, Object?> json) {
    final matched = json['matched'];
    final duplicate = json['duplicate'];
    final recipientsEnqueued = json['recipients_enqueued'];
    if (matched is! bool ||
        duplicate is! bool ||
        recipientsEnqueued is! num ||
        recipientsEnqueued < 0) {
      throw const FormatException('invalid_admin_notification_result');
    }
    return AiCoachAdminNotificationResult(
      matched: matched,
      duplicate: duplicate,
      recipientsEnqueued: recipientsEnqueued.toInt(),
    );
  }

  final bool matched;
  final bool duplicate;
  final int recipientsEnqueued;
}

final class _UnavailableAiCoachAdminGateway implements AiCoachAdminGateway {
  const _UnavailableAiCoachAdminGateway();

  @override
  Future<bool> canManageAiCoach() async => false;

  @override
  Stream<String?> watchSignedInUserId() => Stream<String?>.value(null);

  @override
  Future<AiCoachGlobalResetResult> globalReset({
    required String message,
    required String idempotencyKey,
  }) {
    throw StateError('ai_coach_admin_unavailable');
  }

  @override
  Future<bool> individualReset({
    required String email,
    required String reason,
    required String message,
    required String idempotencyKey,
  }) {
    throw StateError('ai_coach_admin_unavailable');
  }

  @override
  Future<AiCoachAdminNotificationResult> sendNotification({
    required AiCoachAdminNotificationKind kind,
    required AiCoachAdminNotificationAudience audience,
    String? email,
    String? message,
    required String idempotencyKey,
  }) {
    throw StateError('ai_coach_admin_unavailable');
  }
}
