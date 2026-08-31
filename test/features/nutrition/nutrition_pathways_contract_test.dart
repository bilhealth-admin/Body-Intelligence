import 'dart:io';

import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_access_policy.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition pathways cover the approved global plan set', () {
    final ids = nutritionPathways.map((plan) => plan.id).toSet();

    expect(
      ids,
      containsAll(<String>{
        'cutting',
        'carb-cycling',
        'lean-mass',
        'mediterranean',
        'high-protein',
        'plant-forward',
        'dash',
        'low-carb',
        'keto',
        'pregnancy',
      }),
    );
    expect(ids.length, nutritionPathways.length);
    expect(nutritionPathways, hasLength(10));
    expect(ids, isNot(contains('psmf')));
    expect(nutritionPathwayForExactId('psmf'), isNull);
  });

  test('higher-risk pathways cannot masquerade as standard plans', () {
    final byId = {for (final plan in nutritionPathways) plan.id: plan};

    expect(byId['pregnancy']?.safety, NutritionPathwaySafety.clinicianReview);
    expect(byId['keto']?.safety, NutritionPathwaySafety.clinicianReview);
  });

  test('release catalog does not expose the supervision-only PSMF pathway', () {
    final catalogSource = File(
      'lib/features/nutrition_plans/domain/nutrition_pathway_catalog.dart',
    ).readAsStringSync();
    final pageSource = File(
      'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
    ).readAsStringSync();

    expect(catalogSource, isNot(contains("pathways/psmf.dart")));
    expect(catalogSource, isNot(contains('psmfPathway')));
    expect(pageSource, contains('nutritionPathways'));
    expect(nutritionPathwayForExactId('psmf'), isNull);
  });

  test('carb cycling is the only free nutrition pathway', () {
    final free = nutritionPathways
        .where((plan) => plan.access == NutritionPathwayAccess.free)
        .map((plan) => plan.id)
        .toList(growable: false);

    expect(free, const ['carb-cycling']);
    expect(
      nutritionPathways.where((plan) => plan.id != 'carb-cycling'),
      everyElement(
        isA<NutritionPathway>().having(
          (plan) => plan.access,
          'access',
          NutritionPathwayAccess.premium,
        ),
      ),
    );
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
      expect(File(plan.asset).existsSync(), isTrue, reason: plan.id);
    }
  });

  test('each system is isolated in its own Dart source', () {
    const expectedFiles = <String>{
      'carb_cycling.dart',
      'smart_fat_loss.dart',
      'lean_mass.dart',
      'mediterranean.dart',
      'high_protein.dart',
      'plant_forward.dart',
      'dash.dart',
      'low_carb.dart',
      'keto.dart',
      'pregnancy.dart',
      'psmf.dart',
    };
    final actual = Directory('lib/features/nutrition_plans/domain/pathways')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(actual, expectedFiles);
  });

  test('pathways use a preview route and authorized activation command', () {
    final pathwaysPage = File(
      'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/nutrition_plans/data/diet_plan_repository.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/nutrition_plans/presentation/diet_plan_editor_page.dart',
    ).readAsStringSync();
    final accessGate = File(
      'lib/features/nutrition_plans/presentation/nutrition_pathway_access_gate.dart',
    ).readAsStringSync();
    final planPage = File(
      'lib/features/profile/plan_page.dart',
    ).readAsStringSync();

    expect(
      pathwaysPage,
      contains("'/nutrition-plans/\${Uri.encodeComponent(plan.id)}'"),
    );
    expect(router, contains("path: '/nutrition-plans'"));
    expect(router, contains("path: '/nutrition-plans/:pathwayId'"));
    expect(router, contains('NutritionPathwayAccessGate('));
    expect(
      accessGate,
      contains('feature: PremiumGateFeature.nutritionPrograms'),
    );
    expect(dashboard, contains("'/nutrition-plans'"));
    expect(dashboard, contains("_referenceText(context, 'Diet', 'الدايت')"));
    // Pathway and schedule must be committed together. A separate
    // `replaceDayTargets` write could leave an active pathway pointing at an
    // older schedule if the second preference write fails.
    expect(repository, contains('preferences.mutate'));
    expect(repository, contains('nutritionGoalSchedulePreferenceKey'));
    expect(repository, contains('activePathwayKey'));
    expect(repository, contains('NutritionPathwayActivationAuthorization._'));
    expect(repository, isNot(contains("dietPresets['mediterranean']!")));
    expect(editor, contains('dietPlanCommandProvider'));
    expect(editor, isNot(contains('dietPlanRepositoryProvider).activate')));
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
