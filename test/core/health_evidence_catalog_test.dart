import 'dart:io';

import 'package:body_intelligence_log/core/health_evidence/health_evidence_catalog.dart';
import 'package:body_intelligence_log/engine/body_composition_engine.dart';
import 'package:body_intelligence_log/engine/body_profile.dart';
import 'package:body_intelligence_log/engine/nutrition_engine.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/pathways/psmf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approved health evidence registry has unique safe sources', () {
    final ids = HealthEvidenceCatalog.all.map((source) => source.id).toList();
    final urls = HealthEvidenceCatalog.all
        .map((source) => source.url.toString())
        .toList();

    expect(ids.toSet(), hasLength(ids.length));
    expect(urls.toSet(), hasLength(urls.length));
    for (final source in HealthEvidenceCatalog.all) {
      expect(source.id, matches(RegExp(r'^[a-z0-9_]+$')));
      expect(source.url.scheme, 'https');
      expect(source.url.host, isNotEmpty);
      expect(source.organization, isNotEmpty);
      expect(source.shortDescription, isNotEmpty);
      expect(source.methodologyNote, isNotEmpty);
    }
  });

  test('unknown or duplicated model citations are rejected', () {
    expect(
      HealthEvidenceCatalog.validateIds(const <Object?>[
        HealthEvidenceIds.cdcAdultBmi,
        'https://untrusted.example/fake-study',
        'unknown_source',
        HealthEvidenceIds.cdcAdultBmi,
      ]),
      const <String>[HealthEvidenceIds.cdcAdultBmi],
    );
  });

  test('Flutter and AI server use the same citation allow-list', () {
    final server = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    final start = server.indexOf('export const allowedHealthCitationIds');
    final end = server.indexOf(']);', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = server.substring(start, end);

    for (final source in HealthEvidenceCatalog.all) {
      expect(block, contains('"${source.id}"'));
    }
    final serverIds = RegExp(
      r'"([a-z0-9_]+)"',
    ).allMatches(block).map((match) => match.group(1)!).toSet();
    expect(
      serverIds,
      HealthEvidenceCatalog.all.map((source) => source.id).toSet(),
    );
  });

  test('pregnancy pathway exposes every numeric pregnancy reference', () {
    expect(
      HealthEvidenceCatalog.forPathway('pregnancy'),
      unorderedEquals(const <String>[
        HealthEvidenceIds.pregnancyIronFolate,
        HealthEvidenceIds.pregnancyCalcium,
        HealthEvidenceIds.pregnancyIodine,
        HealthEvidenceIds.pregnancyEnergy,
      ]),
    );
  });

  test('weight planning discloses the static energy approximation', () {
    expect(
      HealthEvidenceCatalog.forTopic('weight-planning'),
      contains(HealthEvidenceIds.weightEnergyApproximation),
    );
    final source = HealthEvidenceCatalog.byId(
      HealthEvidenceIds.weightEnergyApproximation,
    )!;
    expect(source.url.toString(), contains('pubmed.ncbi.nlm.nih.gov/13594881'));
    expect(source.methodologyNote, contains('static planning approximation'));
  });

  test('every nutrition pathway has approved source IDs', () {
    for (final pathway in nutritionPathways) {
      expect(
        pathway.sourceIds,
        isNotEmpty,
        reason: '${pathway.id} must never render uncited guidance',
      );
      expect(
        HealthEvidenceCatalog.validateIds(pathway.sourceIds),
        pathway.sourceIds,
      );
    }
    expect(
      psmfPathway.sourceIds,
      contains(HealthEvidenceIds.veryLowCalorieSupervision),
    );
  });

  test('calculated body outputs carry their exact methodology IDs', () {
    final result = BodyCompositionEngine.calculate(
      heightCm: 178,
      currentWeightKg: 87,
      age: 35,
      gender: 'male',
      waistCm: 92,
      neckCm: 39,
    );

    expect(
      result.bodyMassIndex.sourceIds,
      contains(HealthEvidenceIds.cdcAdultBmi),
    );
    expect(
      result.waistToHeightRatio.sourceIds,
      contains(HealthEvidenceIds.niceWaistToHeight),
    );
    expect(result.bodyFatPercentage.sourceIds, isNotEmpty);
  });

  test('nutrition calculations preserve values and attach methodology', () {
    const profile = BodyProfile(
      height: 178,
      weight: 87,
      targetWeight: 87,
      age: 35,
      gender: 'male',
      activityLevel: 'moderate',
      exercises: true,
    );
    final targets = NutritionEngine.calculate(profile: profile, tdee: 2700);

    expect(targets.calories, greaterThan(0));
    expect(targets.protein, greaterThan(0));
    expect(targets.sourceIds, contains(HealthEvidenceIds.mifflinStJeor));
    expect(
      targets.sourceIds,
      contains(HealthEvidenceIds.dietaryReferenceIntakes),
    );
    expect(targets.sourceIds, contains(HealthEvidenceIds.proteinExercise));
  });
}
