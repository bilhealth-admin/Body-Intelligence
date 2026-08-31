import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';

final class AiCoachResetNotice {
  const AiCoachResetNotice({required this.ownerId, required this.resetId});

  final String ownerId;
  final String resetId;
}

abstract interface class AiCoachResetNoticeGateway {
  Stream<String?> watchSignedInUserId();

  Future<AiCoachResetNotice?> newestUnseen();

  Future<void> dismiss(AiCoachResetNotice notice);
}

final class SupabaseAiCoachResetNoticeGateway
    implements AiCoachResetNoticeGateway {
  const SupabaseAiCoachResetNoticeGateway(this._client);

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
  Future<AiCoachResetNotice?> newestUnseen() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return null;
    final row = await _client
        .from('bil_ai_coach_reset_notices')
        .select('reset_id')
        .eq('owner_id', ownerId)
        .isFilter('seen_at', null)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final resetId = row?['reset_id']?.toString();
    return resetId == null || resetId.isEmpty
        ? null
        : AiCoachResetNotice(ownerId: ownerId, resetId: resetId);
  }

  @override
  Future<void> dismiss(AiCoachResetNotice notice) async {
    if (_client.auth.currentUser == null) {
      throw StateError('authentication_required');
    }
    final changed = await _client.rpc(
      'bil_dismiss_ai_coach_reset_notice',
      params: <String, Object?>{
        'p_owner_id': notice.ownerId,
        'p_reset_id': notice.resetId,
      },
    );
    if (changed != true) throw StateError('reset_notice_not_dismissed');
  }
}

final aiCoachResetNoticeGatewayProvider = Provider<AiCoachResetNoticeGateway>((
  ref,
) {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return const _UnavailableAiCoachResetNoticeGateway();
  }
  return SupabaseAiCoachResetNoticeGateway(Supabase.instance.client);
});

final class _UnavailableAiCoachResetNoticeGateway
    implements AiCoachResetNoticeGateway {
  const _UnavailableAiCoachResetNoticeGateway();

  @override
  Future<void> dismiss(AiCoachResetNotice notice) async {}

  @override
  Future<AiCoachResetNotice?> newestUnseen() async => null;

  @override
  Stream<String?> watchSignedInUserId() => Stream<String?>.value(null);
}
