import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/security/bil_mobile_integrity_service.dart';

abstract interface class CommunityMemberAccessAdminGateway {
  Future<List<CommunitySuspendedMemberEntry>> listSuspendedMembers();

  Future<CommunityMemberSuspendResult> suspendMember({
    required String email,
    required String reason,
  });

  Future<bool> reinstateMember(String userId);
}

final class CommunitySuspendedMemberEntry {
  const CommunitySuspendedMemberEntry({
    required this.userId,
    required this.email,
    required this.reason,
    required this.suspendedAt,
  });

  factory CommunitySuspendedMemberEntry.fromJson(Map<String, Object?> json) {
    final userId = json['user_id'];
    final email = json['email'];
    final reason = json['reason'];
    final suspendedAt = DateTime.tryParse('${json['suspended_at']}')?.toUtc();
    if (userId is! String ||
        !_uuid.hasMatch(userId) ||
        email is! String ||
        !_email.hasMatch(email) ||
        reason is! String ||
        reason.trim().length < 2 ||
        reason.trim().length > 160 ||
        _control.hasMatch(reason) ||
        suspendedAt == null) {
      throw const FormatException('invalid_community_suspended_member');
    }
    return CommunitySuspendedMemberEntry(
      userId: userId,
      email: email.trim().toLowerCase(),
      reason: reason.trim(),
      suspendedAt: suspendedAt,
    );
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _control = RegExp(r'[\u0000-\u001F\u007F]');

  final String userId;
  final String email;
  final String reason;
  final DateTime suspendedAt;
}

final class CommunityMemberSuspendResult {
  const CommunityMemberSuspendResult({
    required this.matched,
    required this.active,
    required this.changed,
    required this.moderatorRemoved,
  });

  factory CommunityMemberSuspendResult.fromJson(Map<String, Object?> json) {
    final matched = json['matched'];
    final active = json['active'];
    final changed = json['changed'];
    final moderatorRemoved = json['moderator_removed'];
    if (matched is! bool ||
        active is! bool ||
        changed is! bool ||
        moderatorRemoved is! bool ||
        (!matched && (active || changed || moderatorRemoved))) {
      throw const FormatException('invalid_community_member_suspend_result');
    }
    return CommunityMemberSuspendResult(
      matched: matched,
      active: active,
      changed: changed,
      moderatorRemoved: moderatorRemoved,
    );
  }

  final bool matched;
  final bool active;
  final bool changed;
  final bool moderatorRemoved;
}

final class SupabaseCommunityMemberAccessAdminGateway
    implements CommunityMemberAccessAdminGateway {
  const SupabaseCommunityMemberAccessAdminGateway(this._client);

  final SupabaseClient _client;
  static const Uuid _uuid = Uuid();

  Future<Object?> _invoke({
    required String operation,
    required String integrityAction,
    Map<String, Object?> fields = const {},
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('community_member_admin_unavailable');
    }
    final body = <String, Object?>{
      'operation': operation,
      'idempotency_key': _uuid.v4(),
      ...fields,
    };
    final protectedBody = await BilMobileIntegrityService.instance.protect(
      action: integrityAction,
      payload: body,
    );
    final response = await _client.functions.invoke(
      'ai-coach-global-reset',
      body: protectedBody,
    );
    if (response.status != 200) {
      throw StateError('community_member_admin_failed');
    }
    return response.data;
  }

  @override
  Future<List<CommunitySuspendedMemberEntry>> listSuspendedMembers() async {
    final value = await _invoke(
      operation: 'community_member_list',
      integrityAction: 'admin.community.members.list',
    );
    if (value is! List) {
      throw const FormatException('invalid_community_suspended_member_list');
    }
    final entries = <CommunitySuspendedMemberEntry>[];
    for (final row in value) {
      if (row is! Map) {
        throw const FormatException('invalid_community_suspended_member_list');
      }
      entries.add(
        CommunitySuspendedMemberEntry.fromJson(Map<String, Object?>.from(row)),
      );
    }
    return List.unmodifiable(entries);
  }

  @override
  Future<CommunityMemberSuspendResult> suspendMember({
    required String email,
    required String reason,
  }) async {
    final value = await _invoke(
      operation: 'community_member_suspend',
      integrityAction: 'admin.community.members.suspend',
      fields: {'email': email.trim().toLowerCase(), 'reason': reason.trim()},
    );
    if (value is! Map) {
      throw const FormatException('invalid_community_member_suspend_result');
    }
    return CommunityMemberSuspendResult.fromJson(
      Map<String, Object?>.from(value),
    );
  }

  @override
  Future<bool> reinstateMember(String userId) async {
    final value = await _invoke(
      operation: 'community_member_reinstate',
      integrityAction: 'admin.community.members.reinstate',
      fields: {'user_id': userId},
    );
    if (value is! Map || value['reinstated'] is! bool) {
      throw const FormatException('invalid_community_member_reinstate_result');
    }
    return value['reinstated'] as bool;
  }
}

final communityMemberAccessAdminGatewayProvider =
    Provider<CommunityMemberAccessAdminGateway>((ref) {
      if (!AppEnvironment.supabaseRuntimeReady) {
        return const _UnavailableCommunityMemberAccessAdminGateway();
      }
      return SupabaseCommunityMemberAccessAdminGateway(
        Supabase.instance.client,
      );
    });

final communitySuspendedMemberListProvider =
    FutureProvider.autoDispose<List<CommunitySuspendedMemberEntry>>((ref) {
      return ref
          .watch(communityMemberAccessAdminGatewayProvider)
          .listSuspendedMembers();
    });

final class _UnavailableCommunityMemberAccessAdminGateway
    implements CommunityMemberAccessAdminGateway {
  const _UnavailableCommunityMemberAccessAdminGateway();

  Never _unavailable() =>
      throw StateError('community_member_admin_unavailable');

  @override
  Future<List<CommunitySuspendedMemberEntry>> listSuspendedMembers() async =>
      _unavailable();

  @override
  Future<bool> reinstateMember(String userId) async => _unavailable();

  @override
  Future<CommunityMemberSuspendResult> suspendMember({
    required String email,
    required String reason,
  }) async => _unavailable();
}
