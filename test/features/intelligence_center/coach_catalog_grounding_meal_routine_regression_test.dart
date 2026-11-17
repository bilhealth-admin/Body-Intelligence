import 'package:body_intelligence_log/features/intelligence_center/services/coach_catalog_grounding.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/recipe_coach_lookup.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _actualMealTimingQuestion =
    'QA test only. Suggest a simple meal timing routine for my maintain-weight '
    'goal using only my synthetic profile. No medical advice.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final deferred = <String, String>{
    'native46-meal-timing-question': _actualMealTimingQuestion,
    'en-meal-routine':
        'Suggest a meal timing routine for maintaining my weight.',
    'ar-meal-routine': 'اقترح روتين مواعيد وجبات للحفاظ على وزني.',
    'es-meal-routine': 'Sugiere una rutina de comidas para mantener mi peso.',
    'en-ambiguous-routine-needs-clarification': 'routine',
    'ar-ambiguous-routine-needs-clarification': 'روتين',
    'es-ambiguous-routine-needs-clarification': 'rutina',
    'en-no-workouts':
        'No workouts. Suggest a meal timing routine for maintaining my weight.',
    'en-do-not-show-exercises':
        'Do not show me exercises; suggest a meal timing routine for my weight.',
    'en-without-exercise':
        'Without exercise, suggest a meal timing routine for my weight.',
    'en-curly-apostrophe-denial':
        'Don’t show me exercises; suggest a meal timing routine for my weight.',
    'ar-no-exercise-cards':
        'لا تعرض تمارين؛ اقترح روتين مواعيد وجبات للحفاظ على وزني.',
  };
  for (final entry in deferred.entries) {
    test('${entry.key} cannot invent a local workout answer', () async {
      final probe = _Probe();
      final answer = await probe.grounding.answer(
        question: entry.value,
        locale: entry.key.startsWith('ar') ? 'ar' : 'en',
      );
      // Null delegates the original question to the existing Coach path. A
      // catalog cannot answer nutrition guidance or resolve an unspecified
      // routine by silently choosing the workout domain.
      expect(answer, isNull);
      expect(probe.workoutLoads, 0);
      expect(probe.recipes.loads, 0);
    });
  }

  final explicitWorkouts = <String, String>{
    'en-workout-routine': 'Show me a workout routine.',
    'en-specific-video': 'Show me a Bear plank shoulder tap exercise video.',
    'ar-explicit-workout': 'اعرض تمرين Bear plank shoulder tap',
    'meal-context-does-not-veto-workout':
        'Show me a Bear plank shoulder tap exercise video after a meal.',
    'nutrition-denial-does-not-veto-workout':
        'No meal plans; show me a Bear plank shoulder tap exercise video.',
    'comparison-denial-does-not-veto-workout':
        'Show me a Bear plank shoulder tap exercise video, no comparison needed.',
  };
  for (final entry in explicitWorkouts.entries) {
    test('${entry.key} retains verified playable workout lookup', () async {
      final probe = _Probe();
      final answer = await probe.grounding.answer(
        question: entry.value,
        locale: entry.key.startsWith('ar') ? 'ar' : 'en',
      );
      expect(answer, isNotNull);
      expect(probe.workoutLoads, 1);
      expect(probe.recipes.loads, 0);
      expect(answer!.links, isNotEmpty);
      expect(answer.links.every((link) => link.isTrustedLocalRoute), isTrue);
      expect(
        answer.links.every(
          (link) => _catalog.any((item) => item.stableId == link.id),
        ),
        isTrue,
      );
      expect(
        answer.evidence,
        answer.links.map((link) => 'workout_catalog:${link.id}').toList(),
      );
      if (entry.key != 'en-workout-routine') {
        expect(answer.links.single.label, 'Bear plank shoulder tap');
      }
    });
  }
}

class _RecipeBundleProbe extends CachingAssetBundle {
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    throw StateError('These questions do not request a recipe lookup');
  }
}

class _Probe {
  final recipes = _RecipeBundleProbe();
  int workoutLoads = 0;
  late final grounding = CoachCatalogGrounding(
    recipes: RecipeCoachLookup(
      repository: RecipeReleaseRepository(bundle: recipes),
    ),
    workoutLoader: (_) async {
      workoutLoads++;
      return _catalog;
    },
  );
}

// Controlled verified fixtures, not a readback of the device's catalog. Their
// body-weight description exposes why a non-workout "weight" request must never
// reach the workout scorer; IDs/publisher deliberately contain no "QA"/"test".
final _catalog = <WellnessContentItem>[
  _workout('bear-plank-shoulder-tap', 'Bear plank shoulder tap'),
  _workout('bent-knee-leg-lower', 'Bent-knee leg lower'),
  _workout('bicycle-crunch', 'Bicycle crunch'),
];

WellnessContentItem _workout(String id, String title) => WellnessContentItem(
  id: id,
  type: WellnessContentType.workouts,
  locale: 'en',
  title: title,
  description: '$title body weight movement instructions',
  publisher: 'BIL',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/$id'),
  licenseName: 'BIL fixture',
  verified: true,
  videoMedia: WellnessMediaAsset(
    url: Uri.parse('https://bilhealth.com/media/$id.mp4'),
    mimeType: 'video/mp4',
    sha256: List<String>.filled(64, 'a').join(),
    sizeBytes: 2048,
  ),
  category: 'Core stability',
  releaseKey: 'release:$id',
);
