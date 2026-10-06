import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/preferences_repository.dart';
import '../../community/services/community_owner_operation.dart';
import 'remote_ai_consent_coordinator.dart';

part 'coach_memory_owner_sync.dart';

class CoachMemoryRepository {
  CoachMemoryRepository({required this.preferences, SupabaseClient? cloud})
    : cloud = cloud ?? _activeCloud();

  static const storageKey = 'coachExplicitMemoriesV1';
  final PreferencesRepository preferences;
  final SupabaseClient? cloud;

  static SupabaseClient? _activeCloud() {
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
  }

  Future<List<Map<String, Object?>>> readLocal() async {
    try {
      final raw = await preferences.get(storageKey);
      if (raw == null || raw.trim().isEmpty) return [];
      return (jsonDecode(raw) as List<Object?>)
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .where((item) => item['text']?.toString().trim().isNotEmpty == true)
          .take(50)
          .toList(growable: true);
    } on Object {
      return [];
    }
  }

  Future<Map<String, Object?>> saveConfirmed({
    required String text,
    String kind = 'user_fact',
  }) => _runForMemoryOwner(() => _saveConfirmed(text: text, kind: kind));

  Future<Map<String, Object?>> _saveConfirmed({
    required String text,
    required String kind,
  }) async {
    final value = text.trim();
    if (value.isEmpty || value.length > 500) {
      throw ArgumentError.value(text, 'text');
    }
    if (!const {
      'user_fact',
      'preference',
      'constraint',
      'goal',
      'routine',
    }.contains(kind)) {
      throw ArgumentError.value(kind, 'kind');
    }
    late Map<String, Object?> entry;
    await preferences.update(storageKey, (raw) {
      CommunityOwnerOperation.checkCurrent();
      final entries = _strictMemoryEntries(raw);
      final now = DateTime.now().toUtc().toIso8601String();
      final prior = entries.where(
        (item) =>
            (item['text']! as String).toLowerCase() == value.toLowerCase(),
      );
      entry = <String, Object?>{
        'id': prior.isEmpty ? const Uuid().v4() : prior.first['id'],
        'text': value,
        'kind': kind,
        'status': 'confirmed',
        'confidence': 1.0,
        'savedAt': prior.isEmpty ? now : prior.first['savedAt'] ?? now,
        'updatedAt': now,
        'source': 'explicit_user_confirmation',
      };
      entries.removeWhere(
        (item) =>
            (item['text']! as String).toLowerCase() == value.toLowerCase(),
      );
      entries.insert(0, entry);
      return jsonEncode(entries.take(50).toList(growable: false));
    });
    CommunityOwnerOperation.checkCurrent();
    final readback = _strictMemoryEntries(await preferences.get(storageKey));
    CommunityOwnerOperation.checkCurrent();
    final saved = readback.where((item) => item['id'] == entry['id']).single;
    await _upsertCloud(saved);
    return Map<String, Object?>.unmodifiable(saved);
  }

  Future<void> delete(String id) => _runForMemoryOwner(() async {
    await preferences.update(storageKey, (raw) {
      CommunityOwnerOperation.checkCurrent();
      final entries = _strictMemoryEntries(raw)
        ..removeWhere((item) => item['id'] == id);
      return jsonEncode(entries);
    });
    CommunityOwnerOperation.checkCurrent();
    await syncCommittedChange(id: id, expectedLocal: null);
  });

  Future<void> mergeFromCloud() async {
    try {
      await _runForMemoryOwner(_mergeFromCloud);
    } on Object {
      // A stale owner and an offline connection leave the local snapshot alone.
    }
  }

  Future<void> _mergeFromCloud() async {
    final client = cloud;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null || !await _remoteAiAllowed()) return;
    CommunityOwnerOperation.checkCurrent();
    try {
      final rows = await client
          .from('bil_coach_memories')
          .select(
            'id,kind,memory_text,status,source,confidence,learned_at,updated_at,expires_at',
          )
          .eq('owner_id', user.id)
          .isFilter('deleted_at', null)
          .order('updated_at', ascending: false)
          .limit(50);
      CommunityOwnerOperation.checkCurrent();
      await preferences.update(storageKey, (raw) {
        CommunityOwnerOperation.checkCurrent();
        final local = _strictMemoryEntries(raw);
        final byId = <String, Map<String, Object?>>{
          for (final item in local) item['id']! as String: item,
        };
        for (final rawRow in rows) {
          final row = Map<String, Object?>.from(rawRow);
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty || row['memory_text'] is! String) continue;
          final prior = byId[id];
          if (prior != null &&
              (prior['updatedAt']?.toString() ?? '').compareTo(
                    row['updated_at']?.toString() ?? '',
                  ) >=
                  0) {
            continue;
          }
          byId[id] = <String, Object?>{
            'id': id,
            'text': row['memory_text'],
            'kind': row['kind'],
            'status': row['status'],
            'source': row['source'],
            'confidence': row['confidence'],
            'savedAt': row['learned_at'],
            'updatedAt': row['updated_at'],
            if (row['expires_at'] != null) 'expiresAt': row['expires_at'],
          };
        }
        final merged = byId.values.toList(growable: false)
          ..sort(
            (a, b) => (b['updatedAt']?.toString() ?? '').compareTo(
              a['updatedAt']?.toString() ?? '',
            ),
          );
        return jsonEncode(merged.take(50).toList(growable: false));
      });
      CommunityOwnerOperation.checkCurrent();
    } on Object {
      // The Coach stays local-first when offline or before migration rollout.
    }
  }

  Future<void> _upsertCloud(Map<String, Object?> entry) =>
      syncCommittedChange(id: entry['id']! as String, expectedLocal: entry);

  Future<bool> _remoteAiAllowed() async {
    final client = cloud;
    if (client == null) return false;
    try {
      return await sharedRemoteAiConsentCoordinator(client).isGranted();
    } on Object {
      return false;
    }
  }
}
