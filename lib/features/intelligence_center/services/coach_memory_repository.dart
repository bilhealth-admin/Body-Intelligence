import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/preferences_repository.dart';

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
    final entries = await readLocal();
    final now = DateTime.now().toUtc().toIso8601String();
    final prior = entries.where(
      (item) => item['text']?.toString().toLowerCase() == value.toLowerCase(),
    );
    final entry = <String, Object?>{
      'id': prior.isEmpty
          ? const Uuid().v4()
          : prior.first['id']?.toString() ?? const Uuid().v4(),
      'text': value,
      'kind': kind,
      'status': 'confirmed',
      'confidence': 1.0,
      'savedAt': prior.isEmpty ? now : prior.first['savedAt'] ?? now,
      'updatedAt': now,
      'source': 'explicit_user_confirmation',
    };
    entries.removeWhere(
      (item) => item['text']?.toString().toLowerCase() == value.toLowerCase(),
    );
    entries.insert(0, entry);
    await _writeLocal(entries);
    await _upsertCloud(entry);
    return entry;
  }

  Future<void> delete(String id) async {
    final entries = await readLocal();
    entries.removeWhere((item) => item['id']?.toString() == id);
    await _writeLocal(entries);
    final client = cloud;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('bil_coach_memories')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('owner_id', user.id);
    } on Object {
      // Local deletion is authoritative offline; cloud sync can retry later.
    }
  }

  Future<void> mergeFromCloud() async {
    final client = cloud;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null || !await _remoteAiAllowed()) return;
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
      final local = await readLocal();
      final byId = <String, Map<String, Object?>>{
        for (final item in local)
          if (item['id']?.toString().isNotEmpty == true)
            item['id'].toString(): item,
      };
      for (final raw in rows) {
        final row = Map<String, Object?>.from(raw);
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
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
      await _writeLocal(merged);
    } on Object {
      // The Coach stays local-first when offline or before migration rollout.
    }
  }

  Future<void> _upsertCloud(Map<String, Object?> entry) async {
    final client = cloud;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null || !await _remoteAiAllowed()) return;
    try {
      await client.from('bil_coach_memories').upsert({
        'id': entry['id'],
        'owner_id': user.id,
        'kind': entry['kind'],
        'memory_text': entry['text'],
        'status': entry['status'],
        'source': entry['source'],
        'confidence': entry['confidence'],
        'learned_at': entry['savedAt'],
        'updated_at': entry['updatedAt'],
      });
    } on Object {
      // Saving locally never fails because a cloud connection is unavailable.
    }
  }

  Future<bool> _remoteAiAllowed() async {
    final client = cloud;
    if (client == null) return false;
    try {
      final raw = await client.rpc('bil_get_remote_ai_consent');
      return raw is Map && raw['granted'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> _writeLocal(List<Map<String, Object?>> entries) => preferences
      .set(storageKey, jsonEncode(entries.take(50).toList(growable: false)));
}
