import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TrustedRecipeRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TrustedRecipeRepository(PreferencesRepository(database));
  });
  tearDown(() => database.close());

  final json = jsonEncode({
    'name': 'Rice bowl',
    'servings': 1,
    'prepMinutes': 5,
    'cookMinutes': 20,
    'ingredients': [
      {'name': 'Rice', 'quantity': 100, 'unit': 'g'},
    ],
    'steps': ['Cook the rice.'],
  });

  test('persists a reviewed recipe and restores it', () async {
    await repository.saveReviewed(TrustedRecipeParser.parse(json));
    final restored = await repository.load();
    expect(restored, hasLength(1));
    expect(restored.single.recipe.name, 'Rice bowl');
  });

  test('deduplicates canonical recipe content', () async {
    final draft = TrustedRecipeParser.parse(json);
    await repository.saveReviewed(draft);
    expect(
      () => repository.saveReviewed(draft),
      throwsA(isA<DuplicateRecipeException>()),
    );
  });

  test(
    'replaces and deletes a reviewed recipe without changing identity',
    () async {
      final saved = await repository.saveReviewed(
        TrustedRecipeParser.parse(json),
      );
      final replacement = TrustedRecipeParser.parse(
        jsonEncode({
          'name': 'Updated rice bowl',
          'servings': 2,
          'prepMinutes': 6,
          'cookMinutes': 20,
          'ingredients': [
            {'name': 'Rice', 'quantity': 200, 'unit': 'g'},
          ],
          'steps': ['Cook the rice.'],
        }),
      );
      final updated = await repository.replaceReviewed(saved.id, replacement);
      expect(updated.id, saved.id);
      expect((await repository.load()).single.recipe.name, 'Updated rice bowl');
      await repository.delete(saved.id);
      expect(await repository.load(), isEmpty);
    },
  );

  test('replacement cannot collide with another saved recipe', () async {
    final first = await repository.saveReviewed(
      TrustedRecipeParser.parse(json),
    );
    final secondDraft = TrustedRecipeParser.parse(
      jsonEncode({
        'name': 'Lentil bowl',
        'servings': 1,
        'prepMinutes': 5,
        'cookMinutes': 25,
        'ingredients': [
          {'name': 'Lentils', 'quantity': 100, 'unit': 'g'},
        ],
        'steps': ['Cook the lentils.'],
      }),
    );
    final second = await repository.saveReviewed(secondDraft);

    expect(
      () => repository.replaceReviewed(second.id, first.recipe),
      throwsA(isA<DuplicateRecipeException>()),
    );
    final restored = await repository.load();
    expect(restored, hasLength(2));
    expect(
      restored.singleWhere((item) => item.id == second.id).recipe.name,
      'Lentil bowl',
    );
  });

  test('missing edit fails and missing delete is idempotent', () async {
    final draft = TrustedRecipeParser.parse(json);
    expect(
      () => repository.replaceReviewed('missing', draft),
      throwsA(isA<StateError>()),
    );
    await repository.delete('missing');
    expect(await repository.load(), isEmpty);
  });
}
