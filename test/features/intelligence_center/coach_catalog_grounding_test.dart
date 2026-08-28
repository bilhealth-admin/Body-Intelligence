import 'package:body_intelligence_log/features/intelligence_center/services/coach_catalog_grounding.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'partial workout request returns only verified playable catalog items',
    () async {
      final grounding = CoachCatalogGrounding(
        workoutLoader: (_) async => <WellnessContentItem>[
          _workout(
            id: 'lower-body-flow',
            title: 'Lower body strength flow',
            category: 'Strength',
          ),
          _workout(
            id: 'morning-yoga',
            title: 'Morning yoga',
            category: 'Mobility',
          ),
        ],
      );

      final result = await grounding.answer(
        question: 'Show me a lower body workout',
        locale: 'en',
      );

      expect(result, isNotNull);
      expect(result!.links, hasLength(1));
      expect(result.links.single.id, 'release:lower-body-flow');
      expect(result.links.single.label, 'Lower body strength flow');
      expect(result.links.single.isTrustedLocalRoute, isTrue);
      expect(result.evidence, ['workout_catalog:release:lower-body-flow']);
      expect(result.text, isNot(contains('Morning yoga')));
    },
  );

  test(
    'Arabic workout request keeps a real Arabic title and trusted route',
    () async {
      final grounding = CoachCatalogGrounding(
        workoutLoader: (_) async => <WellnessContentItem>[
          _workout(
            id: 'arabic-strength',
            title: 'تمرين قوة كامل الجسم',
            category: 'قوة',
          ),
        ],
      );

      final result = await grounding.answer(
        question: 'أريد تمرين قوة',
        locale: 'ar',
      );

      expect(result, isNotNull);
      expect(result!.links.single.label, 'تمرين قوة كامل الجسم');
      expect(result.links.single.isTrustedLocalRoute, isTrue);
    },
  );

  test(
    'unrelated health question does not load or invent catalog items',
    () async {
      var loads = 0;
      final grounding = CoachCatalogGrounding(
        workoutLoader: (_) async {
          loads += 1;
          return <WellnessContentItem>[];
        },
      );

      final result = await grounding.answer(
        question: 'Why is my weight stable?',
        locale: 'en',
      );

      expect(result, isNull);
      expect(loads, 0);
    },
  );
}

WellnessContentItem _workout({
  required String id,
  required String title,
  required String category,
}) => WellnessContentItem(
  id: id,
  type: WellnessContentType.workouts,
  locale: 'en',
  title: title,
  description: '$title instructions',
  publisher: 'BIL',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts/$id'),
  licenseName: 'BIL test license',
  verified: true,
  videoMedia: WellnessMediaAsset(
    url: Uri.parse('https://bilhealth.com/media/$id.mp4'),
    mimeType: 'video/mp4',
    sha256: List<String>.filled(64, 'a').join(),
    sizeBytes: 2048,
  ),
  category: category,
  releaseKey: 'release:$id',
);
