import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/security/bil_mobile_integrity_service.dart';
import 'ai_coach_admin_service.dart';

class AdminSubscriptionEntry {
  const AdminSubscriptionEntry({
    required this.id,
    required this.email,
    required this.planId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });
  factory AdminSubscriptionEntry.fromJson(Map<String, Object?> row) {
    final id = row['id'];
    final email = row['email'];
    final plan = row['plan_id'];
    final status = row['status'];
    final created = DateTime.tryParse('${row['created_at']}');
    final expires = row['expires_at'] == null
        ? null
        : DateTime.tryParse('${row['expires_at']}');
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        email is! String ||
        email.isEmpty ||
        !['premium', 'premium_ai_coach'].contains(plan) ||
        !['active', 'expired', 'revoked'].contains(status) ||
        created == null ||
        (row['expires_at'] != null && expires == null)) {
      throw const FormatException('invalid_admin_subscription_entry');
    }
    return AdminSubscriptionEntry(
      id: id,
      email: email,
      planId: plan as String,
      createdAt: created,
      expiresAt: expires,
      status: status as String,
    );
  }
  final String id, email, planId, status;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class AdminSubscriptionPageResult {
  const AdminSubscriptionPageResult(this.rows, this.hasMore);
  final List<AdminSubscriptionEntry> rows;
  final bool hasMore;
  factory AdminSubscriptionPageResult.fromJson(Object? value) {
    if (value is! Map || value['rows'] is! List || value['has_more'] is! bool) {
      throw const FormatException('invalid_admin_subscription_list');
    }
    final rows = value['rows'] as List;
    if (rows.length > 50) {
      throw const FormatException('invalid_admin_subscription_list');
    }
    return AdminSubscriptionPageResult(
      List.unmodifiable(
        rows.map((row) {
          if (row is! Map) {
            throw const FormatException('invalid_admin_subscription_entry');
          }
          return AdminSubscriptionEntry.fromJson(
            Map<String, Object?>.from(row),
          );
        }),
      ),
      value['has_more'] as bool,
    );
  }
}

class AdminSubscriptionReceipt {
  const AdminSubscriptionReceipt({
    required this.matched,
    required this.changed,
  });
  final bool matched, changed;
  factory AdminSubscriptionReceipt.fromJson(Object? value) {
    if (value is! Map ||
        value['matched'] is! bool ||
        value['changed'] is! bool ||
        (value['matched'] == false && value['changed'] == true)) {
      throw const FormatException('invalid_admin_subscription_receipt');
    }
    return AdminSubscriptionReceipt(
      matched: value['matched'] as bool,
      changed: value['changed'] as bool,
    );
  }
}

abstract interface class AdminSubscriptionGateway {
  Future<AdminSubscriptionPageResult> list(int offset);
  Future<AdminSubscriptionReceipt> grant({
    required String email,
    required String planId,
    required int? durationDays,
    required String reason,
    required String idempotencyKey,
  });
  Future<AdminSubscriptionReceipt> revoke({
    required String grantId,
    required String idempotencyKey,
  });
}

class SupabaseAdminSubscriptionGateway implements AdminSubscriptionGateway {
  const SupabaseAdminSubscriptionGateway(this.client);
  final SupabaseClient? client;
  Future<Object?> _invoke(
    String operation,
    String key,
    Map<String, Object?> fields,
  ) async {
    final activeClient = client;
    final owner = activeClient?.auth.currentUser?.id;
    if (activeClient == null || owner == null) {
      throw StateError('admin_subscription_unavailable');
    }
    final body = <String, Object?>{
      'operation': 'subscription_$operation',
      'idempotency_key': key,
      ...fields,
    };
    final protected = await BilMobileIntegrityService.instance
        .protect(action: 'admin.subscriptions.$operation', payload: body)
        .timeout(const Duration(seconds: 12));
    if (activeClient.auth.currentUser?.id != owner) {
      throw StateError('admin_session_changed');
    }
    final response = await activeClient.functions
        .invoke('ai-coach-global-reset', body: protected)
        .timeout(const Duration(seconds: 20));
    if (activeClient.auth.currentUser?.id != owner) {
      throw StateError('admin_session_changed');
    }
    if (response.status != 200) throw StateError('admin_subscription_failed');
    return response.data;
  }

  @override
  Future<AdminSubscriptionPageResult> list(int offset) async =>
      AdminSubscriptionPageResult.fromJson(
        await _invoke('list', const Uuid().v4(), {'offset': offset}),
      );
  @override
  Future<AdminSubscriptionReceipt> grant({
    required String email,
    required String planId,
    required int? durationDays,
    required String reason,
    required String idempotencyKey,
  }) async => AdminSubscriptionReceipt.fromJson(
    await _invoke('grant', idempotencyKey, {
      'email': email.trim().toLowerCase(),
      'plan_id': planId,
      'duration_days': durationDays,
      'reason': reason.trim(),
    }),
  );
  @override
  Future<AdminSubscriptionReceipt> revoke({
    required String grantId,
    required String idempotencyKey,
  }) async => AdminSubscriptionReceipt.fromJson(
    await _invoke('revoke', idempotencyKey, {'grant_id': grantId}),
  );
}

final adminSubscriptionGatewayProvider = Provider<AdminSubscriptionGateway>(
  (ref) => SupabaseAdminSubscriptionGateway(
    AppEnvironment.supabaseRuntimeReady ? Supabase.instance.client : null,
  ),
);
final adminSubscriptionListProvider = FutureProvider.autoDispose
    .family<AdminSubscriptionPageResult, int>((ref, offset) async {
      ref.watch(aiCoachAdminSessionProvider);
      if (!await ref.watch(aiCoachAdminAccessProvider.future)) {
        throw StateError('administrator_required');
      }
      return ref.watch(adminSubscriptionGatewayProvider).list(offset);
    });
