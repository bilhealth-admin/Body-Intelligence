import '../../../data/repositories/preferences_repository.dart';
import '../domain/dietary_preferences.dart';

final class DietaryPreferencesRepository {
  const DietaryPreferencesRepository(this._preferences);

  final PreferencesRepository _preferences;

  Future<DietaryPreferences> read() async => DietaryPreferences.decode(
    await _preferences.get(DietaryPreferences.storageKey),
    legacyApproach: await _preferences.get('dietApproach'),
  );

  Stream<DietaryPreferences> watch() async* {
    await for (final value in _preferences.watch(
      DietaryPreferences.storageKey,
    )) {
      yield DietaryPreferences.decode(
        value,
        legacyApproach: await _preferences.get('dietApproach'),
      );
    }
  }

  /// Keeps the old profile key synchronized while every new consumer reads the
  /// versioned contract. One transaction prevents split-brain profile state.
  Future<void> save(DietaryPreferences value) => _preferences.setMany({
    DietaryPreferences.storageKey: value.encode(),
    'dietApproach': value.approach,
  });

  /// Persists the canonical and compatibility keys inside a transaction
  /// already owned by a higher-level save workflow.
  Future<void> saveInCurrentTransaction(DietaryPreferences value) =>
      _preferences.setManyInCurrentTransaction({
        DietaryPreferences.storageKey: value.encode(),
        'dietApproach': value.approach,
      });
}
