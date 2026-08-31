import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';

abstract interface class AiCoachAdminGateway {
  Stream<String?> watchSignedInUserId();

  Future<bool> canManageAiCoach();

  Future<AiCoachGlobalResetResult> globalReset(String idempotencyKey);

  Future<bool> individualReset({
    required String email,
    required String reason,
    required String idempotencyKey,
  });
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
  Future<AiCoachGlobalResetResult> globalReset(String idempotencyKey) async {
    final response = await _client.functions.invoke(
      'ai-coach-global-reset',
      body: <String, Object?>{
        'operation': 'global',
        'idempotency_key': idempotencyKey,
      },
    );
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
    required String idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'ai-coach-global-reset',
      body: <String, Object?>{
        'operation': 'individual',
        'email': email.trim().toLowerCase(),
        'reason': reason.trim(),
        'idempotency_key': idempotencyKey,
      },
    );
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
    return AiCoachGlobalResetResult(
      resetId: json['reset_id']?.toString() ?? '',
      usageRowsReset: (json['usage_rows_reset'] as num?)?.toInt() ?? 0,
      monthlyRowsReset: (json['monthly_rows_reset'] as num?)?.toInt() ?? 0,
      usersNotified: (json['users_notified'] as num?)?.toInt() ?? 0,
      duplicate: json['duplicate'] == true,
    );
  }

  final String resetId;
  final int usageRowsReset;
  final int monthlyRowsReset;
  final int usersNotified;
  final bool duplicate;
}

final class _UnavailableAiCoachAdminGateway implements AiCoachAdminGateway {
  const _UnavailableAiCoachAdminGateway();

  @override
  Future<bool> canManageAiCoach() async => false;

  @override
  Stream<String?> watchSignedInUserId() => Stream<String?>.value(null);

  @override
  Future<AiCoachGlobalResetResult> globalReset(String idempotencyKey) {
    throw StateError('ai_coach_admin_unavailable');
  }

  @override
  Future<bool> individualReset({
    required String email,
    required String reason,
    required String idempotencyKey,
  }) {
    throw StateError('ai_coach_admin_unavailable');
  }
}
