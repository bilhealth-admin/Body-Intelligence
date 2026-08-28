import '../../wellness/domain/wellness_content_pack.dart';
import '../../wellness/services/wellness_content_pack_manager.dart';
import '../domain/intelligence_message.dart';
import 'recipe_coach_lookup.dart';

typedef CoachWorkoutCatalogLoader =
    Future<List<WellnessContentItem>> Function(String locale);

final class CoachCatalogGroundingResult {
  const CoachCatalogGroundingResult({
    required this.text,
    required this.links,
    required this.evidence,
  });

  final String text;
  final List<IntelligenceMessageLink> links;
  final List<String> evidence;
}

/// Resolves recipe and workout requests against locally verified catalogs.
///
/// Gemini never supplies these destinations. Every title, identifier and route
/// below comes from a trusted installed/indexed item, including when the user's
/// request is partial or ambiguous.
final class CoachCatalogGrounding {
  CoachCatalogGrounding({
    RecipeCoachLookup? recipes,
    CoachWorkoutCatalogLoader? workoutLoader,
  }) : _recipes = recipes ?? RecipeCoachLookup(),
       _workoutLoader =
           workoutLoader ??
           ((locale) => WellnessContentPackManager().loadTrustedInstalledItems(
             WellnessContentType.workouts,
             locale: locale,
           ));

  final RecipeCoachLookup _recipes;
  final CoachWorkoutCatalogLoader _workoutLoader;
  final Map<String, Future<List<WellnessContentItem>>> _workoutCatalogs = {};

  Future<CoachCatalogGroundingResult?> answer({
    required String question,
    required String locale,
  }) async {
    final recipe = await _recipes.answer(question: question, locale: locale);
    if (recipe != null) {
      return CoachCatalogGroundingResult(
        text: recipe.text,
        links: recipe.links,
        evidence: recipe.recipeIds
            .map((id) => 'recipe_catalog:$id')
            .toList(growable: false),
      );
    }
    return _workoutAnswer(question: question, locale: locale);
  }

  Future<CoachCatalogGroundingResult?> _workoutAnswer({
    required String question,
    required String locale,
  }) async {
    final normalized = _normalize(question);
    final tokens = _tokens(normalized);
    if (!tokens.any(_workoutIntentTokens.contains)) return null;
    final language = locale.replaceAll('_', '-').split('-').first.toLowerCase();
    final catalog = await _workoutCatalogs.putIfAbsent(
      language,
      () => _workoutLoader(language),
    );
    final meaningful = tokens.difference(_workoutIgnoredTokens);
    final scored = <({WellnessContentItem item, int score})>[];
    for (final item in catalog) {
      if (!item.verified ||
          item.type != WellnessContentType.workouts ||
          item.videoMedia == null) {
        continue;
      }
      final title = _normalize(item.title);
      final searchable = _normalize(
        <String>[
          item.id,
          item.stableId,
          item.title,
          item.description,
          item.category ?? '',
          item.difficulty ?? '',
          ...item.tags,
          ...item.equipment,
        ].join(' '),
      );
      final searchableTokens = _tokens(searchable);
      var score = 0;
      if (title.length >= 4 && normalized.contains(title)) {
        score = 180 + title.length;
      }
      final overlap = meaningful.intersection(searchableTokens);
      score += overlap.length * 32;
      for (final token in meaningful) {
        if (searchableTokens.any(
          (candidate) =>
              candidate.startsWith(token) || token.startsWith(candidate),
        )) {
          score += 14;
        }
      }
      if (meaningful.isEmpty) score = 1;
      if (score > 0) scored.add((item: item, score: score));
    }
    scored.sort((left, right) {
      final scoreOrder = right.score.compareTo(left.score);
      return scoreOrder == 0
          ? left.item.stableId.compareTo(right.item.stableId)
          : scoreOrder;
    });
    if (scored.isEmpty) return null;
    final bestScore = scored.first.score;
    final options = scored
        .where((entry) => entry.score >= bestScore - 20)
        .take(3)
        .map((entry) => entry.item)
        .toList(growable: false);
    final links = options
        .map(
          (item) => IntelligenceMessageLink(
            id: item.stableId,
            label: item.title,
            route: Uri(
              path: '/wellness/workouts/routines',
              queryParameters: <String, String>{'item': item.stableId},
            ).toString(),
            kind: IntelligenceMessageLinkKind.workout,
          ),
        )
        .toList(growable: false);
    return CoachCatalogGroundingResult(
      text: <String>[for (final item in options) '• ${item.title}'].join('\n'),
      links: links,
      evidence: options
          .map((item) => 'workout_catalog:${item.stableId}')
          .toList(growable: false),
    );
  }

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

const _workoutIntentTokens = <String>{
  'workout',
  'workouts',
  'exercise',
  'exercises',
  'training',
  'routine',
  'strength',
  'cardio',
  'hiit',
  'yoga',
  'stretch',
  'gym',
  'squat',
  'تمرين',
  'تمارين',
  'تدريب',
  'روتين',
  'قوه',
  'كارديو',
  'يوغا',
  'اطاله',
  'entraînement',
  'exercice',
  'entrenamiento',
  'ejercicio',
  'rutina',
  'antrenman',
  'egzersiz',
  'spor',
  'übung',
  'allenamento',
  'esercizio',
  'treino',
  'exercício',
  'ورزش',
  'تمرین',
  'व्यायाम',
  'कसरत',
  'latihan',
  'senaman',
  'トレーニング',
  '운동',
  '훈련',
  '锻炼',
  '運動',
  'тренировка',
  'упражнение',
  'ব্যায়াম',
  'tập',
  'luyện',
  'ออกกำลัง',
  'ćwiczenia',
  'trening',
  'oefening',
  'тренування',
};

const _workoutIgnoredTokens = <String>{
  'workout',
  'workouts',
  'exercise',
  'exercises',
  'routine',
  'تمرين',
  'تمارين',
  'تدريب',
  'روتين',
  'entraînement',
  'exercice',
  'entrenamiento',
  'ejercicio',
  'rutina',
  'antrenman',
  'egzersiz',
  'training',
  'übung',
  'allenamento',
  'esercizio',
  'treino',
  'exercício',
  'تمرین',
  'व्यायाम',
  'कसरत',
  'latihan',
  'senaman',
  'トレーニング',
  '運動',
  '운동',
  '훈련',
  '锻炼',
  'тренировка',
  'упражнение',
  'ব্যায়াম',
  'tập',
  'luyện',
  'ออกกำลัง',
  'ćwiczenia',
  'trening',
  'oefening',
  'тренування',
  'the',
  'and',
  'for',
  'with',
  'give',
  'show',
  'me',
  'اريد',
  'اعطني',
  'مع',
};
