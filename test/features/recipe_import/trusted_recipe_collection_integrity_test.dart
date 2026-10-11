import 'dart:convert';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_parser.dart';

void main() {
  late AppDatabase db;
  late PreferencesRepository prefs;
  late TrustedRecipeRepository recipes;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = PreferencesRepository(db);
    recipes = TrustedRecipeRepository(prefs);
  });
  tearDown(() => db.close());
  TrustedRecipeDraft draft(String name) => TrustedRecipeParser.parse(
    jsonEncode({
      'name': name,
      'servings': 1,
      'prepMinutes': 1,
      'cookMinutes': 1,
      'ingredients': [
        {'name': 'Oats', 'quantity': 100, 'unit': 'g'},
      ],
      'steps': ['Mix.'],
    }),
  );
  test(
    'corrupt storage is an error and cannot be overwritten by a new recipe',
    () async {
      await prefs.set(TrustedRecipeRepository.storageKey, '{corrupt');
      await expectLater(
        recipes.load(),
        throwsA(isA<RecipeCollectionUnavailable>()),
      );
      await expectLater(
        recipes.saveReviewed(draft('A')),
        throwsA(isA<RecipeCollectionUnavailable>()),
      );
      expect(await prefs.get(TrustedRecipeRepository.storageKey), '{corrupt');
    },
  );
  test('concurrent saves retain both recipes', () async {
    final other = TrustedRecipeRepository(prefs);
    await Future.wait([
      recipes.saveReviewed(draft('A')),
      other.saveReviewed(draft('B')),
    ]);
    expect((await recipes.load()).map((row) => row.recipe.name).toSet(), {
      'A',
      'B',
    });
  });
  test(
    'collection stream reflects save and delete without page reentry',
    () async {
      final saved = await recipes.saveReviewed(draft('A'));
      expect(await recipes.watch().first, hasLength(1));
      await recipes.delete(saved.id);
      expect(await recipes.watch().first, isEmpty);
    },
  );
}
