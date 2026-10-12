import 'package:supabase_flutter/supabase_flutter.dart';
import '../../community/services/community_owner_operation.dart';
import 'cloud_restore_v2_transport.dart';

final class SupabaseCloudRestoreV2Transport implements CloudRestoreV2Transport {
  const SupabaseCloudRestoreV2Transport(
    this.client, {
    this.ownerId,
    this.isCurrent,
  });
  final SupabaseClient client;
  final String? ownerId;
  final bool Function()? isCurrent;

  Future<Map<String, Object?>> _rpc(
    String name, [
    Map<String, Object?>? args,
  ]) => CommunityOwnerOperation.run(
    client: client,
    ownerId: ownerId ?? client.auth.currentUser?.id,
    isCurrentOwner: isCurrent,
    action: (_) async {
      final value = await client
          .rpc<Object?>(name, params: args ?? const {})
          .timeout(const Duration(seconds: 20));
      if (value is! Map) {
        throw const FormatException('Invalid restore response');
      }
      return Map<String, Object?>.from(value);
    },
  );

  @override
  Future<Map<String, Object?>> capabilities() =>
      _rpc('bil_cloud_restore_capabilities_v2');

  @override
  Future<Map<String, Object?>> consent() =>
      _rpc('bil_cloud_restore_consent_v2');

  @override
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  }) => _rpc('bil_sync_records_v2', {
    'p_device_id': deviceId,
    'p_scope': scope,
    'p_cursor': cursor,
    'p_operations': operations,
    'p_limit': limit,
  });
}
