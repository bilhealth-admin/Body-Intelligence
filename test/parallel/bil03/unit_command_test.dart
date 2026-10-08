import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_unit_settings_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weight unit commit updates display preferences only', () async {
    final preferences = _FakePreferences({
      'units.weight': 'Kilograms',
      'units': 'metric',
      'synthetic.weight.history': '90.4,89.9,89.2',
      'profile.heightCm': '178',
    });
    final service = CoachUnitSettingsCommandService(preferences);

    final result = await service.commit(
      operationId: 'bil03-unit-weight',
      dimension: CoachUnitDimension.weight,
      value: 'Pounds',
    );

    expect(result.beforeValue, 'Kilograms');
    expect(preferences.values['units.weight'], 'Pounds');
    expect(preferences.values['units'], 'imperial');
    expect(preferences.values['synthetic.weight.history'], '90.4,89.9,89.2');
    expect(preferences.values['profile.heightCm'], '178');
  });

  test(
    'unit Undo restores exact prior values after verified readback',
    () async {
      final preferences = _FakePreferences({
        'units.weight': 'Kilograms',
        'units': 'metric',
      });
      final service = CoachUnitSettingsCommandService(preferences);
      await service.commit(
        operationId: 'bil03-unit-undo',
        dimension: CoachUnitDimension.weight,
        value: 'Stone',
      );

      final undone = await service.undo(operationId: 'bil03-unit-undo');

      expect(undone.canUndo, isFalse);
      expect(preferences.values['units.weight'], 'Kilograms');
      expect(preferences.values['units'], 'metric');
    },
  );

  test('newer unit edit blocks stale Undo', () async {
    final preferences = _FakePreferences({'units.water': 'Milliliters'});
    final service = CoachUnitSettingsCommandService(preferences);
    await service.commit(
      operationId: 'bil03-water-stale',
      dimension: CoachUnitDimension.water,
      value: 'Cups',
    );
    await preferences.set('units.water', 'Fluid ounces');

    await expectLater(
      service.undo(operationId: 'bil03-water-stale'),
      throwsA(
        isA<CoachSettingsCommandConflict>().having(
          (error) => error.reason,
          'reason',
          'newer_unit_change',
        ),
      ),
    );
    expect(preferences.values['units.water'], 'Fluid ounces');
  });

  test('owner change before mutation rejects command', () async {
    final preferences = _FakePreferences({'units.distance': 'Kilometers'});
    final service = CoachUnitSettingsCommandService(preferences);

    await expectLater(
      service.commit(
        operationId: 'bil03-unit-owner',
        dimension: CoachUnitDimension.distance,
        value: 'Miles',
        isCurrentOwner: () => false,
      ),
      throwsA(
        isA<CoachSettingsCommandConflict>().having(
          (error) => error.reason,
          'reason',
          'owner_changed',
        ),
      ),
    );
    expect(preferences.values['units.distance'], 'Kilometers');
  });

  test('write permission revoked before Undo leaves unit unchanged', () async {
    final preferences = _FakePreferences({'units.height': 'Centimeters'});
    final service = CoachUnitSettingsCommandService(preferences);
    await service.commit(
      operationId: 'bil03-unit-permission',
      dimension: CoachUnitDimension.height,
      value: 'Feet/Inches',
    );

    await expectLater(
      service.undo(
        operationId: 'bil03-unit-permission',
        checkWritePermission: () => false,
      ),
      throwsA(isA<CoachSettingsCommandConflict>()),
    );
    expect(preferences.values['units.height'], 'Feet/Inches');
  });
}

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
