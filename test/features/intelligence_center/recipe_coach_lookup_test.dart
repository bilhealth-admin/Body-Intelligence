import 'package:body_intelligence_log/features/intelligence_center/services/recipe_coach_lookup.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns the named recipe in each authored language', () async {
    final lookup = RecipeCoachLookup();
    final cases = <(String, String, String, String)>[
      ('Give me the shakshuka recipe', 'en', 'Herbed shakshuka', 'Method'),
      ('اعطني طريقة شكشوكه', 'ar', 'شكشوكة بالأعشاب', 'الطريقة'),
      ('Recette de chakchouka', 'fr', 'Chakchouka aux herbes', 'Préparation'),
      ('Receta de shakshuka', 'es', 'Shakshuka con hierbas', 'Preparación'),
      ('Shakshuka tarifi', 'tr', 'Otlu shakshuka', 'Hazırlanışı'),
    ];
    for (final (question, locale, title, methodLabel) in cases) {
      final answer = await lookup.answer(question: question, locale: locale);
      expect(answer, isNotNull, reason: locale);
      expect(answer!.recipeId, 'shakshuka', reason: locale);
      expect(answer.text, contains(title), reason: locale);
      expect(answer.text, contains(methodLabel), reason: locale);
    }
  });

  test('an English user receives a Moroccan recipe fully in English', () async {
    final answer = await RecipeCoachLookup().answer(
      question: 'Show me the Moroccan harira recipe',
      locale: 'en-US',
    );
    expect(answer, isNotNull);
    expect(answer!.recipeId, 'moroccan-harira');
    expect(answer.text, contains('Moroccan harira'));
    expect(answer.text, contains('Ingredients'));
    expect(answer.text, contains('Method'));
    expect(answer.text, isNot(contains('المكوّنات')));
  });

  test('does not confuse Algerian chakhchoukha with shakshuka', () async {
    final answer = await RecipeCoachLookup().answer(
      question: 'اريد وصفة الشخشوخة الجزائرية',
      locale: 'ar',
    );
    expect(answer, isNotNull);
    expect(answer!.recipeId, 'algerian-chakhchoukha-chicken');
    expect(answer.text, contains('الشخشوخة الجزائرية بالدجاج'));
    expect(answer.text, isNot(contains('شكشوكة بالأعشاب')));
  });

  test(
    'broad recipe request returns real catalog choices without guessing',
    () async {
      final answer = await RecipeCoachLookup().answer(
        question: 'Give me a chicken recipe',
        locale: 'en',
      );
      expect(answer, isNotNull);
      expect(answer!.recipeIds.length, inInclusiveRange(2, 3));
      expect(answer.links, hasLength(answer.recipeIds.length));
      for (final link in answer.links) {
        expect(link.isTrustedLocalRoute, isTrue);
        expect(link.route, contains('/wellness/recipes?recipe='));
      }
    },
  );

  test(
    'resolves localized recipe names and details in all 25 locales',
    () async {
      const locales = <String>[
        'ar',
        'en',
        'fr',
        'es',
        'tr',
        'de',
        'it',
        'pt-BR',
        'pt-PT',
        'ur',
        'fa',
        'hi',
        'id',
        'ms',
        'ja',
        'ko',
        'zh-Hans',
        'zh-Hant',
        'ru',
        'bn',
        'vi',
        'th',
        'pl',
        'nl',
        'uk',
      ];
      final repository = RecipeReleaseRepository();
      final summary = (await repository.loadIndex()).singleWhere(
        (recipe) => recipe.id == 'shakshuka',
      );
      final detail = await repository.loadDetail(summary);
      final lookup = RecipeCoachLookup(repository: repository);

      for (final locale in locales) {
        final resolved = detail.resolveLocalization(locale);
        expect(resolved.isFallback, isFalse, reason: locale);
        final title = resolved.value['title'] as String;
        final ingredients = (resolved.value['ingredients'] as List)
            .cast<String>();
        final steps = (resolved.value['steps'] as List).cast<String>();
        final answer = await lookup.answer(
          question: 'recipe $title',
          locale: locale,
        );
        expect(answer, isNotNull, reason: locale);
        expect(answer!.recipeId, summary.id, reason: locale);
        expect(answer.text, contains(title), reason: locale);
        expect(answer.text, contains(ingredients.first), reason: locale);
        expect(answer.text, contains(steps.first), reason: locale);
      }
    },
  );
}
