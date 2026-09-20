import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/security/bil_mobile_integrity_service.dart';

abstract interface class CommunityModeratorAdminGateway {
  Future<List<CommunityModeratorAdminEntry>> listModerators();

  Future<CommunityModeratorAddResult> addModerator(String email);

  Future<bool> removeModerator(String userId);
}

final class CommunityModeratorAdminEntry {
  const CommunityModeratorAdminEntry({
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.protectedAdministrator,
  });

  factory CommunityModeratorAdminEntry.fromJson(Map<String, Object?> json) {
    final userId = json['user_id'];
    final email = json['email'];
    final createdAt = DateTime.tryParse('${json['created_at']}')?.toUtc();
    final protectedAdministrator = json['protected_administrator'];
    if (userId is! String ||
        !_uuid.hasMatch(userId) ||
        email is! String ||
        !_email.hasMatch(email) ||
        createdAt == null ||
        protectedAdministrator is! bool) {
      throw const FormatException('invalid_community_moderator_entry');
    }
    return CommunityModeratorAdminEntry(
      userId: userId,
      email: email.trim().toLowerCase(),
      createdAt: createdAt,
      protectedAdministrator: protectedAdministrator,
    );
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final String userId;
  final String email;
  final DateTime createdAt;
  final bool protectedAdministrator;
}

final class CommunityModeratorAddResult {
  const CommunityModeratorAddResult({
    required this.matched,
    required this.added,
  });

  factory CommunityModeratorAddResult.fromJson(Map<String, Object?> json) {
    final matched = json['matched'];
    final added = json['added'];
    if (matched is! bool || added is! bool || (!matched && added)) {
      throw const FormatException('invalid_community_moderator_add_result');
    }
    return CommunityModeratorAddResult(matched: matched, added: added);
  }

  final bool matched;
  final bool added;
}

final class SupabaseCommunityModeratorAdminGateway
    implements CommunityModeratorAdminGateway {
  const SupabaseCommunityModeratorAdminGateway(this._client);

  final SupabaseClient _client;
  static const Uuid _uuid = Uuid();

  Future<Object?> _invoke({
    required String operation,
    required String integrityAction,
    Map<String, Object?> fields = const {},
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('community_moderator_admin_unavailable');
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
      throw StateError('community_moderator_admin_failed');
    }
    return response.data;
  }

  @override
  Future<List<CommunityModeratorAdminEntry>> listModerators() async {
    final value = await _invoke(
      operation: 'moderator_list',
      integrityAction: 'admin.community.moderators.list',
    );
    if (value is! List) {
      throw const FormatException('invalid_community_moderator_list');
    }
    final entries = <CommunityModeratorAdminEntry>[];
    for (final row in value) {
      if (row is! Map) {
        throw const FormatException('invalid_community_moderator_list');
      }
      entries.add(
        CommunityModeratorAdminEntry.fromJson(Map<String, Object?>.from(row)),
      );
    }
    return List.unmodifiable(entries);
  }

  @override
  Future<CommunityModeratorAddResult> addModerator(String email) async {
    final value = await _invoke(
      operation: 'moderator_add',
      integrityAction: 'admin.community.moderators.add',
      fields: {'email': email.trim().toLowerCase()},
    );
    if (value is! Map) {
      throw const FormatException('invalid_community_moderator_add_result');
    }
    return CommunityModeratorAddResult.fromJson(
      Map<String, Object?>.from(value),
    );
  }

  @override
  Future<bool> removeModerator(String userId) async {
    final value = await _invoke(
      operation: 'moderator_remove',
      integrityAction: 'admin.community.moderators.remove',
      fields: {'user_id': userId},
    );
    if (value is! Map || value['removed'] is! bool) {
      throw const FormatException('invalid_community_moderator_remove_result');
    }
    return value['removed'] as bool;
  }
}

final communityModeratorAdminGatewayProvider =
    Provider<CommunityModeratorAdminGateway>((ref) {
      if (!AppEnvironment.supabaseRuntimeReady) {
        return const _UnavailableCommunityModeratorAdminGateway();
      }
      return SupabaseCommunityModeratorAdminGateway(Supabase.instance.client);
    });

final communityModeratorAdminListProvider =
    FutureProvider.autoDispose<List<CommunityModeratorAdminEntry>>((ref) {
      return ref.watch(communityModeratorAdminGatewayProvider).listModerators();
    });

final class _UnavailableCommunityModeratorAdminGateway
    implements CommunityModeratorAdminGateway {
  const _UnavailableCommunityModeratorAdminGateway();

  Never _unavailable() =>
      throw StateError('community_moderator_admin_unavailable');

  @override
  Future<CommunityModeratorAddResult> addModerator(String email) async =>
      _unavailable();

  @override
  Future<List<CommunityModeratorAdminEntry>> listModerators() async =>
      _unavailable();

  @override
  Future<bool> removeModerator(String userId) async => _unavailable();
}
