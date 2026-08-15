import 'package:supabase_flutter/supabase_flutter.dart';

final class DiarySharingSupportRepository {
  const DiarySharingSupportRepository(this._client);

  final SupabaseClient _client;

  Future<void> setDiarySharing({
    required String visibility,
    String? accessKeySha256,
  }) async {
    await _client.rpc(
      'bil_set_diary_share_settings',
      params: {
        'p_visibility': visibility,
        'p_access_key_sha256': accessKeySha256,
      },
    );
  }

  Future<void> publishDiary({
    required DateTime day,
    required Map<String, Object?> payload,
    required int sourceRevision,
  }) async {
    await _client.rpc(
      'bil_publish_diary_snapshot',
      params: {
        'p_diary_day': _dayKey(day),
        'p_payload': payload,
        'p_source_revision': sourceRevision,
      },
    );
  }

  Future<Map<String, dynamic>?> readSharedDiary({
    required String ownerId,
    required DateTime day,
    String? accessKeySha256,
  }) async {
    final value = await _client.rpc(
      'bil_read_shared_diary',
      params: {
        'p_owner_id': ownerId,
        'p_diary_day': _dayKey(day),
        'p_access_key_sha256': accessKeySha256,
      },
    );
    if (value == null) return null;
    if (value is! Map) throw const FormatException('Invalid shared diary');
    return Map<String, dynamic>.from(value);
  }

  Future<String> createSupportRequest({
    required String category,
    required String subject,
    required String message,
    Map<String, Object?> clientContext = const {},
  }) async {
    final value = await _client.rpc(
      'bil_create_support_request',
      params: {
        'p_category': category,
        'p_subject': subject,
        'p_message': message,
        'p_client_context': clientContext,
      },
    );
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid support request identifier');
    }
    return value;
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
