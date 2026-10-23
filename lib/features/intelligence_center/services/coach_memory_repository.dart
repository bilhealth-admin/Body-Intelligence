import 'dart:convert';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/preferences_repository.dart';
import '../../community/services/community_owner_operation.dart';
import 'remote_ai_consent_coordinator.dart';
import 'coach_memory_sync_protocol.dart';

part 'coach_memory_owner_sync.dart';
part 'coach_memory_sync_readback.dart';
part 'coach_memory_sync_merge.dart';
part 'coach_memory_sync_review.dart';

class CoachMemoryVersionConflict implements Exception {
  const CoachMemoryVersionConflict(this.id);
  final String id;

  @override
  String toString() => 'CoachMemoryVersionConflict($id)';
}

class CoachMemorySelection {
  const CoachMemorySelection({
    required this.id,
    required this.expectedUpdatedAt,
  });

  final String id;
  final String expectedUpdatedAt;
}

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
          .where((item) => isCurrentConfirmedCoachMemory(item, DateTime.now()))
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
      return jsonEncode(_retainMemoryState(entries));
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
          .map(
            (item) => item['id'] == id ? _memoryDeletionTombstone(item) : item,
          )
          .toList(growable: false);
      return jsonEncode(entries);
    });
    CommunityOwnerOperation.checkCurrent();
    await syncCommittedChange(id: id, expectedLocal: null);
  });

  /// Deletes only memories the user explicitly selected from a reviewed
  /// snapshot. Each selection carries the row's updatedAt token so a newer
  /// edit cannot be silently removed by an older confirmation dialog.
  Future<List<String>> deleteSelected(
    List<CoachMemorySelection> selections, {
    bool Function()? isCurrentOwner,
  }) async {
    if (selections.isEmpty) return const <String>[];
    final ids = selections.map((item) => item.id).toList(growable: false);
    if (ids.any((id) => id.trim().isEmpty) ||
        ids.toSet().length != ids.length) {
      throw ArgumentError.value(selections, 'selections');
    }
    if (isCurrentOwner?.call() == false) {
      throw const CommunityOwnerOperationCancelled();
    }
    final deleted = await _runForMemoryOwner(() async {
      if (isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
      await preferences.update(storageKey, (raw) {
        CommunityOwnerOperation.checkCurrent();
        if (isCurrentOwner?.call() == false) {
          throw const CommunityOwnerOperationCancelled();
        }
        final entries = _strictMemoryEntries(raw);
        for (final selection in selections) {
          final matches = entries.where((item) => item['id'] == selection.id);
          if (matches.length != 1 ||
              matches.single['updatedAt']?.toString() !=
                  selection.expectedUpdatedAt) {
            throw CoachMemoryVersionConflict(selection.id);
          }
        }
        return jsonEncode(
          _retainMemoryState(
            entries
                .map(
                  (item) => ids.contains(item['id'])
                      ? _memoryDeletionTombstone(item)
                      : item,
                )
                .toList(growable: false),
          ),
        );
      });
      CommunityOwnerOperation.checkCurrent();
      if (isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
      final readback = _strictMemoryEntries(await preferences.get(storageKey));
      if (readback.any(
        (item) => ids.contains(item['id']) && item['status'] != 'deleted',
      )) {
        throw StateError('Selected Coach memories were not deleted');
      }
      return List<String>.unmodifiable(ids);
    }, isCurrentOwner: isCurrentOwner);
    for (final id in deleted) {
      await syncCommittedChange(
        id: id,
        expectedLocal: null,
        isCurrentOwner: isCurrentOwner,
      );
    }
    return deleted;
  }

  Future<void> mergeFromCloud() async {
    try {
      await _runForMemoryOwner(_mergeFromCloud);
    } on Object {
      // A stale owner and an offline connection leave the local snapshot alone.
    }
  }

  Future<void> _mergeFromCloud() => _mergeMemoryCloudWithCheckpoints();

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
