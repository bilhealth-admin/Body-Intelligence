import '../domain/intelligence_message.dart';
import '../../wellness/repositories/recipe_release_repository.dart';

final class RecipeCoachAnswer {
  const RecipeCoachAnswer({
    required this.recipeIds,
    required this.text,
    required this.links,
  });

  final List<String> recipeIds;
  final String text;
  final List<IntelligenceMessageLink> links;

  String get recipeId => recipeIds.first;
}

/// Offline, catalog-grounded recipe lookup for BIL AI Coach.
///
/// Named requests return the verified recipe; partial or broad requests return
/// a short list of real catalog options. No title or route is model-invented.
final class RecipeCoachLookup {
  RecipeCoachLookup({RecipeReleaseRepository? repository})
    : _repository = repository ?? RecipeReleaseRepository();

  final RecipeReleaseRepository _repository;
  final Map<String, Future<_RecipeSearchIndex>> _searchIndices = {};

  Future<RecipeCoachAnswer?> answer({
    required String question,
    required String locale,
  }) async {
    final normalizedQuestion = _normalize(question);
    final questionTokens = _tokens(normalizedQuestion);
    if (!_hasRecipeIntent(questionTokens)) return null;

    final language = _supportedLocale(locale);
    final searchIndex = await _searchIndices.putIfAbsent(
      language,
      () => _buildSearchIndex(language),
    );
    final scored = <({RecipeCatalogSummary recipe, int score})>[];
    final meaningfulQuestionTokens = questionTokens.difference(_ignoredTokens);
    final matchingIndices = <int>{};
    for (final token in meaningfulQuestionTokens) {
      matchingIndices.addAll(searchIndex.byToken[token] ?? const <int>[]);
      for (final entry in searchIndex.entries.indexed) {
        if (entry.$2.tokens.any(
          (candidate) =>
              candidate.startsWith(token) || token.startsWith(candidate),
        )) {
          matchingIndices.add(entry.$1);
        }
      }
    }
    if (meaningfulQuestionTokens.isEmpty) {
      matchingIndices.addAll(
        List<int>.generate(searchIndex.entries.length, (index) => index),
      );
    }
    for (final index in matchingIndices) {
      final entry = searchIndex.entries[index];
      var score = 0;
      for (final candidate in entry.candidates) {
        if (candidate.length >= 4 && normalizedQuestion.contains(candidate)) {
          score = score > 120 + candidate.length
              ? score
              : 120 + candidate.length;
          continue;
        }
        final meaningful = _tokens(candidate).difference(_ignoredTokens);
        final overlap = meaningful.intersection(questionTokens);
        if (overlap.isNotEmpty) {
          final tokenScore =
              40 +
              overlap.fold<int>(0, (total, token) => total + token.length) +
              (overlap.length * 8);
          if (tokenScore > score) score = tokenScore;
        }
        for (final questionToken in meaningfulQuestionTokens) {
          if (meaningful.any(
            (token) =>
                token.startsWith(questionToken) ||
                questionToken.startsWith(token),
          )) {
            score = score > 34 + questionToken.length
                ? score
                : 34 + questionToken.length;
          }
        }
      }
      if (score > 0 || meaningfulQuestionTokens.isEmpty) {
        scored.add((recipe: entry.recipe, score: score));
      }
    }
    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder == 0 ? a.recipe.id.compareTo(b.recipe.id) : scoreOrder;
    });
    if (scored.isEmpty ||
        (meaningfulQuestionTokens.isNotEmpty && scored.first.score < 34)) {
      return null;
    }

    final ambiguous =
        meaningfulQuestionTokens.isEmpty ||
        (scored.length > 1 && scored[1].score >= scored.first.score - 6);
    if (ambiguous) {
      final options = scored.take(3).map((entry) => entry.recipe).toList();
      return RecipeCoachAnswer(
        recipeIds: options.map((recipe) => recipe.id).toList(growable: false),
        text: _optionsText(options, language),
        links: options
            .map((recipe) => _linkFor(recipe, language))
            .toList(growable: false),
      );
    }

    final summary = scored.first.recipe;
    final detail = await _repository.loadDetail(summary);
    final localization = detail.localization(language);
    final ingredients = (localization['ingredients'] as List).cast<String>();
    final steps = (localization['steps'] as List).cast<String>();
    String label(String english) => _detailLabel(english, language);
    final nutrition = detail.record['nutrition'] as Map<String, dynamic>;
    final perServing = nutrition['perServing'] as Map<String, dynamic>;
    final kcal = (perServing['kcal'] as num).round();
    final buffer = StringBuffer()
      ..writeln(localization['title'])
      ..writeln()
      ..writeln(label('Ingredients'));
    for (final ingredient in ingredients) {
      buffer.writeln('• $ingredient');
    }
    buffer
      ..writeln()
      ..writeln(label('Method'));
    for (var index = 0; index < steps.length; index++) {
      buffer.writeln('${index + 1}. ${steps[index]}');
    }
    buffer
      ..writeln()
      ..write("${label('Per serving')}: $kcal ${label('kcal')}");
    return RecipeCoachAnswer(
      recipeIds: <String>[summary.id],
      text: buffer.toString().trim(),
      links: <IntelligenceMessageLink>[_linkFor(summary, language)],
    );
  }

  static String _optionsText(
    List<RecipeCatalogSummary> recipes,
    String language,
  ) {
    return <String>[
      for (final recipe in recipes) '• ${recipe.titleFor(language)}',
    ].join('\n');
  }

  static String _detailLabel(String english, String language) {
    const labels = <String, Map<String, String>>{
      'Ingredients': <String, String>{
        'ar': 'المكوّنات',
        'fr': 'Ingrédients',
        'es': 'Ingredientes',
        'tr': 'Malzemeler',
      },
      'Method': <String, String>{
        'ar': 'الطريقة',
        'fr': 'Préparation',
        'es': 'Preparación',
        'tr': 'Hazırlanışı',
      },
      'Per serving': <String, String>{
        'ar': 'لكل حصة',
        'fr': 'Par portion',
        'es': 'Por porción',
        'tr': 'Porsiyon başına',
      },
      'kcal': <String, String>{'ar': 'سعرة حرارية'},
    };
    return labels[english]?[language] ?? english;
  }

  static IntelligenceMessageLink _linkFor(
    RecipeCatalogSummary recipe,
    String language,
  ) {
    final route = Uri(
      path: '/wellness/recipes',
      queryParameters: <String, String>{'recipe': recipe.id},
    ).toString();
    return IntelligenceMessageLink(
      id: recipe.id,
      label: recipe.titleFor(language),
      route: route,
      kind: IntelligenceMessageLinkKind.recipe,
    );
  }

  Future<_RecipeSearchIndex> _buildSearchIndex(String language) async {
    final recipes = await _repository.loadIndex();
    final entries = <_RecipeSearchEntry>[];
    final byToken = <String, List<int>>{};
    for (final recipe in recipes) {
      final rawCandidates = <String>{
        recipe.id.replaceAll('-', ' '),
        recipe.titleFor(language),
        recipe.titleFor(recipe.primaryLocale),
      };
      final candidates = rawCandidates.map(_normalize).toList(growable: false);
      final entryIndex = entries.length;
      final tokens = candidates
          .expand(_tokens)
          .toSet()
          .difference(_ignoredTokens);
      entries.add(
        _RecipeSearchEntry(
          recipe: recipe,
          candidates: candidates,
          tokens: tokens,
        ),
      );
      for (final token in tokens) {
        byToken.putIfAbsent(token, () => <int>[]).add(entryIndex);
      }
    }
    return _RecipeSearchIndex(entries: entries, byToken: byToken);
  }

  static String _supportedLocale(String value) {
    final normalized = value.replaceAll('_', '-').toLowerCase();
    for (final locale in _catalogLocales) {
      if (locale.toLowerCase() == normalized) return locale;
    }
    final language = normalized.split('-').first;
    final matches = _catalogLocales
        .where(
          (locale) =>
              locale.toLowerCase() == language ||
              locale.toLowerCase().startsWith('$language-'),
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : 'en';
  }

  static bool _hasRecipeIntent(Set<String> tokens) =>
      tokens.any(_recipeIntentTokens.contains);

  static Set<String> _tokens(String value) => value
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((token) => token.length >= 2)
      .toSet();

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}

final class _RecipeSearchIndex {
  const _RecipeSearchIndex({required this.entries, required this.byToken});

  final List<_RecipeSearchEntry> entries;
  final Map<String, List<int>> byToken;
}

final class _RecipeSearchEntry {
  const _RecipeSearchEntry({
    required this.recipe,
    required this.candidates,
    required this.tokens,
  });

  final RecipeCatalogSummary recipe;
  final List<String> candidates;
  final Set<String> tokens;
}

const _recipeIntentTokens = <String>{
  'recipe',
  'recipes',
  'cook',
  'make',
  'وصفه',
  'طريقه',
  'اطبخ',
  'تحضير',
  'recette',
  'cuisiner',
  'préparer',
  'receta',
  'cocinar',
  'preparar',
  'tarif',
  'tarifi',
  'pişir',
  'hazırla',
  'rezept',
  'kochen',
  'zubereiten',
  'ricetta',
  'cucinare',
  'receita',
  'cozinhar',
  'نسخہ',
  'ترکیب',
  'پکائیں',
  'دستور',
  'طرز',
  'بپز',
  'रेसिपी',
  'विधि',
  'पकाएं',
  'resep',
  'masak',
  'resipi',
  'レシピ',
  '作り方',
  '레시피',
  '만드는법',
  '食谱',
  '做法',
  'рецепт',
  'приготовить',
  'রেসিপি',
  'রান্না',
  'công',
  'thức',
  'nấu',
  'สูตร',
  'วิธีทำ',
  'przepis',
  'ugotować',
  'recept',
  'koken',
  'приготувати',
};

const _ignoredTokens = <String>{
  ..._recipeIntentTokens,
  'the',
  'with',
  'and',
  'how',
  'طريقة',
  'مع',
  'من',
  'aux',
  'avec',
  'con',
  'ile',
  've',
};

const _catalogLocales = <String>{
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
};
