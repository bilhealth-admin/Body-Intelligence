import 'package:body_intelligence_log/features/intelligence_center/services/coach_catalog_grounding.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/recipe_coach_lookup.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _physicalPrompt =
    'Reply in English. Show a two-row Markdown table comparing a planned '
    'workout with a completed workout. Do not save or change any data.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'physical1186 table prompt is reasoning rather than a row catalog lookup',
    () async {
      final probe = _Probe();
      final answer = await probe.grounding.answer(
        question: _physicalPrompt,
        locale: 'en',
      );
      expect(
        answer,
        isNull,
        reason:
            'The local bullet/video shortcut cannot answer this comparison.',
      );
      expect(probe.workoutLoads, 0);
      expect(probe.recipes.loads, 0);
    },
  );

  final reasoning = <String, String>{
    'ar-ui-english-exact': _physicalPrompt,
    'en-recipe-table':
        'Show a two-row table comparing a recipe and a logged meal.',
    'ar-recipe-table':
        'اعرض جدولًا يقارن وصفة مقترحة بوجبة تم تناولها دون تسجيل شيء.',
    'en-format-columns':
        'Explain workouts using two columns: Status and Evidence.',
    'en-layout-without-markdown':
        'Show a table with two rows and three columns about workouts.',
    'en-row-column':
        'Compare planned vs completed workouts in two rows and three columns.',
    'en-comparison':
        'How is a planned workout different from a completed workout?',
    'en-versus':
        'Planned training versus completed training: what is the difference?',
    'en-definition':
        'What does completed workout mean? Explain without logging it.',
    'en-columns-first':
        'Columns and rows should describe a planned exercise and an exercise actually done.',
    'ar-format':
        'اعرض جدولًا من صفين يقارن تمرينًا مخططًا بتمرين مكتمل. لا تحفظ أي بيانات.',
    'ar-comparison': 'ما الفرق بين التمرين المخطط والتمرين المنجز؟',
    'ar-columns': 'قارن بين التدريب المخطط والمنجز في عمودين.',
    'ar-layout': 'اكتب عن التمرين في صفين وعمودين فقط.',
    'ar-table-columns': 'أريد شرح أعمدة جدول التمارين: الحالة والدليل.',
    'ar-definition': 'ما معنى تمرين مكتمل؟ لا تسجل أي شيء.',
    'en-follow-up': 'Put that in a table with two rows and columns.',
    'ar-follow-up': 'قارنهم في جدول من صفين.',
  };
  for (final entry in reasoning.entries) {
    test(
      '${entry.key} passes through without invented catalog facts or actions',
      () async {
        final probe = _Probe();
        final answer = await probe.grounding.answer(
          question: entry.value,
          locale: entry.key.startsWith('ar') ? 'ar' : 'en',
        );
        expect(answer, isNull);
        expect(probe.workoutLoads, 0);
        expect(probe.recipes.loads, 0);
      },
    );
  }

  final lookups = <String, String>{
    'en-video-translation':
        'Show me a renegade row exercise video with an Arabic translation.',
    'ar-explanatory-video': 'اعرض فيديو شرح تمرين السحب بالدمبل',
    'en-no-comparison':
        'Show me a renegade row exercise video, no comparison needed.',
    'en-specific-row': 'Show me a renegade row from knees exercise video.',
    'en-chest-row': 'Find a chest-supported dumbbell row workout.',
    'en-row-count': 'Show me two row exercises.',
    'en-table-furniture': 'Show me a row exercise under a table.',
    'en-tabletop': 'Show me a tabletop row exercise.',
    'ar-pull': 'أريد تمارين السحب بالدمبل',
    'ar-exact-row': 'اعرض تمرين السحب بالدمبل',
    'mixed-row': 'اعرض تمرين renegade row from knees',
  };
  for (final entry in lookups.entries) {
    test(
      '${entry.key} retains verified workout lookup and playable routes',
      () async {
        final probe = _Probe();
        final answer = await probe.grounding.answer(
          question: entry.value,
          locale: entry.key.startsWith('ar') ? 'ar' : 'en',
        );
        expect(answer, isNotNull);
        expect(answer!.links, isNotEmpty);
        expect(answer.links.every((link) => link.isTrustedLocalRoute), isTrue);
        expect(answer.links.every((link) => _ids.contains(link.id)), isTrue);
        expect(
          answer.evidence.every(
            (entry) => entry.startsWith('workout_catalog:'),
          ),
          isTrue,
        );
        expect(probe.workoutLoads, 1);
        expect(probe.recipes.loads, 0);
        if (entry.key == 'en-specific-row' || entry.key == 'mixed-row') {
          expect(answer.links.single.label, 'Renegade row from knees');
        }
      },
    );
  }
}

class _RecipeBundleProbe extends CachingAssetBundle {
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    throw StateError('Unexpected recipe asset load for a workout-only request');
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

const _ids = <String>{
  'test:deadlift-row',
  'test:renegade-row',
  'test:chest-row',
  'test:under-table-row',
  'test:tabletop-row',
  'test:arabic-row',
};

final _catalog = <WellnessContentItem>[
  _workout('deadlift-row', 'Dumbbell deadlift to row'),
  _workout('renegade-row', 'Renegade row from knees'),
  _workout('chest-row', 'Chest-supported dumbbell row'),
  _workout('under-table-row', 'Under table row'),
  _workout('tabletop-row', 'Tabletop row'),
  _workout('arabic-row', 'تمرين السحب بالدمبل'),
];

WellnessContentItem _workout(String id, String title) => WellnessContentItem(
  id: id,
  type: WellnessContentType.workouts,
  locale: 'en',
  title: title,
  description: '$title instructions',
  publisher: 'BIL test fixture',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/$id'),
  licenseName: 'BIL test fixture',
  verified: true,
  videoMedia: WellnessMediaAsset(
    url: Uri.parse('https://bilhealth.com/media/$id.mp4'),
    mimeType: 'video/mp4',
    sha256: List<String>.filled(64, 'a').join(),
    sizeBytes: 2048,
  ),
  category: 'Strength',
  releaseKey: 'test:$id',
);
