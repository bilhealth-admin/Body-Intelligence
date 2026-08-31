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

enum BilAdminNoticeKind {
  compensation,
  gift,
  custom;

  static BilAdminNoticeKind? fromWire(String value) => switch (value) {
    'compensation' => BilAdminNoticeKind.compensation,
    'gift' => BilAdminNoticeKind.gift,
    'custom' => BilAdminNoticeKind.custom,
    _ => null,
  };
}

final class BilAdminNotice {
  const BilAdminNotice({
    required this.ownerId,
    required this.notificationId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String ownerId;
  final String notificationId;
  final BilAdminNoticeKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
}

abstract interface class BilAdminNoticeGateway {
  Future<BilAdminNotice?> newestUnseen();

  Future<void> dismiss(BilAdminNotice notice);
}

final class SupabaseBilAdminNoticeGateway implements BilAdminNoticeGateway {
  const SupabaseBilAdminNoticeGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<BilAdminNotice?> newestUnseen() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return null;
    final row = await _client
        .from('bil_admin_notices')
        .select(
          'owner_id,notification_id,notification_kind,title,body,created_at',
        )
        .eq('owner_id', ownerId)
        .isFilter('seen_at', null)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null || row['owner_id']?.toString() != ownerId) return null;
    final notificationId = row['notification_id']?.toString() ?? '';
    final kind = BilAdminNoticeKind.fromWire(
      row['notification_kind']?.toString() ?? '',
    );
    final title = row['title']?.toString().trim() ?? '';
    final body = row['body']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (notificationId.isEmpty ||
        kind == null ||
        title.isEmpty ||
        body.isEmpty ||
        createdAt == null) {
      throw const FormatException('invalid_admin_notice');
    }
    return BilAdminNotice(
      ownerId: ownerId,
      notificationId: notificationId,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt.toUtc(),
    );
  }

  @override
  Future<void> dismiss(BilAdminNotice notice) async {
    if (_client.auth.currentUser?.id != notice.ownerId) {
      throw StateError('authentication_required');
    }
    final changed = await _client.rpc(
      'bil_dismiss_admin_notice',
      params: <String, Object?>{
        'p_owner_id': notice.ownerId,
        'p_notification_id': notice.notificationId,
      },
    );
    if (changed != true) throw StateError('admin_notice_not_dismissed');
  }
}

final bilAdminNoticeGatewayProvider = Provider<BilAdminNoticeGateway>((ref) {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return const _UnavailableBilAdminNoticeGateway();
  }
  return SupabaseBilAdminNoticeGateway(Supabase.instance.client);
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

final class _UnavailableBilAdminNoticeGateway implements BilAdminNoticeGateway {
  const _UnavailableBilAdminNoticeGateway();

  @override
  Future<void> dismiss(BilAdminNotice notice) async {}

  @override
  Future<BilAdminNotice?> newestUnseen() async => null;
}
