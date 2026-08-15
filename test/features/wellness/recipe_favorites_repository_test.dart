import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_favorites_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late RecipeFavoritesRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecipeFavoritesRepository(PreferencesRepository(database));
  });

  tearDown(() => database.close());

  test('toggle persists a unique saved recipe collection', () async {
    expect(await repository.load(), isEmpty);
    expect(await repository.toggle('recipe-a'), {'recipe-a'});
    expect(await repository.toggle('recipe-b'), {'recipe-a', 'recipe-b'});
    expect(await repository.load(), {'recipe-a', 'recipe-b'});
    expect(await repository.toggle('recipe-a'), {'recipe-b'});
  });

  test('corrupt storage fails closed and blank ids are rejected', () async {
    await PreferencesRepository(
      database,
    ).set(RecipeFavoritesRepository.storageKey, '{not-json');
    expect(await repository.load(), isEmpty);
    expect(() => repository.toggle('  '), throwsArgumentError);
  });

  test('concurrent toggles preserve both durable updates', () async {
    await Future.wait([
      repository.toggle('recipe-a'),
      repository.toggle('recipe-b'),
    ]);
    expect(await repository.load(), {'recipe-a', 'recipe-b'});
  });
}
