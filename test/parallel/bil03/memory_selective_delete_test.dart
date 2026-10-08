import 'dart:convert';

import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleteSelected removes only explicitly reviewed memory', () async {
    final preferences = _FakePreferences({
      CoachMemoryRepository.storageKey: jsonEncode([
        _memory('m1', 'Likes walnuts', '2026-10-07T09:00:00Z'),
        _memory('m2', 'Goal is 79 kg', '2026-10-07T09:05:00Z'),
      ]),
    });
    final repository = CoachMemoryRepository(preferences: preferences);

    final deleted = await repository.deleteSelected(const [
      CoachMemorySelection(id: 'm1', expectedUpdatedAt: '2026-10-07T09:00:00Z'),
    ]);

    expect(deleted, ['m1']);
    final rows = await repository.readLocal();
    expect(rows.map((row) => row['id']), ['m2']);
  });

  test(
    'version mismatch rejects deletion without touching any memory',
    () async {
      final original = [
        _memory('m1', 'Likes walnuts', '2026-10-07T09:10:00Z'),
        _memory('m2', 'Goal is 79 kg', '2026-10-07T09:05:00Z'),
      ];
      final preferences = _FakePreferences({
        CoachMemoryRepository.storageKey: jsonEncode(original),
      });
      final repository = CoachMemoryRepository(preferences: preferences);

      await expectLater(
        repository.deleteSelected(const [
          CoachMemorySelection(
            id: 'm1',
            expectedUpdatedAt: '2026-10-07T09:00:00Z',
          ),
        ]),
        throwsA(
          isA<CoachMemoryVersionConflict>().having(
            (error) => error.id,
            'id',
            'm1',
          ),
        ),
      );
      expect((await repository.readLocal()).map((row) => row['id']), [
        'm1',
        'm2',
      ]);
    },
  );

  test(
    'owner change during reviewed delete cancels before persistence',
    () async {
      final preferences = _FakePreferences({
        CoachMemoryRepository.storageKey: jsonEncode([
          _memory('m1', 'Likes walnuts', '2026-10-07T09:00:00Z'),
        ]),
      });
      final repository = CoachMemoryRepository(preferences: preferences);
      var checks = 0;

      await expectLater(
        repository.deleteSelected(const [
          CoachMemorySelection(
            id: 'm1',
            expectedUpdatedAt: '2026-10-07T09:00:00Z',
          ),
        ], isCurrentOwner: () => ++checks < 4),
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      expect((await repository.readLocal()).single['id'], 'm1');
    },
  );
}

Map<String, Object?> _memory(String id, String text, String updatedAt) => {
  'id': id,
  'text': text,
  'kind': 'preference',
  'status': 'confirmed',
  'confidence': 1.0,
  'savedAt': updatedAt,
  'updatedAt': updatedAt,
  'source': 'explicit_user_confirmation',
};

class _FakePreferences implements PreferencesRepository {
  _FakePreferences(Map<String, String> seed) : values = {...seed};
  final Map<String, String> values;

  @override
  String? get localOwnerId => 'owner-a';

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<String> update(
    String key,
    String Function(String? current) derive,
  ) async {
    final next = derive(values[key]);
    values[key] = next;
    return next;
  }

  @override
  Future<void> setMany(Map<String, String> next) async => values.addAll(next);

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> next) async =>
      values.addAll(next);

  @override
  Future<void> removeMany(Iterable<String> keys) async {
    for (final key in keys) {
      values.remove(key);
    }
  }

  @override
  Future<void> removeManyInCurrentTransaction(Iterable<String> keys) =>
      removeMany(keys);

  @override
  Future<void> mutate({
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) async {
    values.addAll(set);
    for (final key in remove) {
      if (!set.containsKey(key)) values.remove(key);
    }
  }

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) async {
    for (final entry in expected.entries) {
      if (values[entry.key] != entry.value) return false;
    }
    values.addAll(set);
    for (final key in remove) {
      if (!set.containsKey(key)) values.remove(key);
    }
    return true;
  }

  @override
  Stream<String?> watch(String key) => Stream<String?>.value(values[key]);
}
