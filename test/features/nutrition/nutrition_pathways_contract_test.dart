import 'dart:io';

import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition pathways cover the approved global plan set', () {
    final ids = nutritionPathways.map((plan) => plan.id).toSet();

    expect(
      ids,
      containsAll(<String>{
        'cutting',
        'lean-mass',
        'mediterranean',
        'high-protein',
        'plant-forward',
        'dash',
        'low-carb',
        'keto',
        'pregnancy',
        'psmf',
      }),
    );
    expect(ids.length, nutritionPathways.length);
    expect(nutritionPathways, hasLength(10));
  });

  test('higher-risk pathways cannot masquerade as standard plans', () {
    final byId = {for (final plan in nutritionPathways) plan.id: plan};

    expect(byId['pregnancy']?.safety, NutritionPathwaySafety.clinicianReview);
    expect(byId['keto']?.safety, NutritionPathwaySafety.clinicianReview);
    expect(byId['psmf']?.safety, NutritionPathwaySafety.medicalSupervision);
  });

  test('every pathway has bilingual copy and a packaged visual', () {
    for (final plan in nutritionPathways) {
      expect(plan.arTitle.trim(), isNotEmpty, reason: plan.id);
      expect(plan.enTitle.trim(), isNotEmpty, reason: plan.id);
      expect(plan.arSubtitle.trim(), isNotEmpty, reason: plan.id);
      expect(plan.enSubtitle.trim(), isNotEmpty, reason: plan.id);
      expect(
        plan.asset,
        startsWith('assets/images/nutrition_plans/'),
        reason: plan.id,
      );
    }
  });

  test('pathway selection is persisted and reviewed before plan save', () {
    final pathwaysPage = File(
      'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
    ).readAsStringSync();
    final planPage = File(
      'lib/features/profile/plan_page.dart',
    ).readAsStringSync();

    expect(pathwaysPage, contains("set('activeNutritionPathway', plan.id)"));
    expect(pathwaysPage, contains('/plan?pathway='));
    expect(
      planPage,
      contains('Selecting a pathway does not change your targets.'),
    );
    expect(
      planPage,
      contains('Clinician review is required before activation.'),
    );
  });
}
