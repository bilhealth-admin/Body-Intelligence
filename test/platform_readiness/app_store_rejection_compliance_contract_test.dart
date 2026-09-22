import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS onboarding does not re-request identity or stage HealthKit', () {
    final onboarding = File(
      'lib/features/onboarding/onboarding_page.dart',
    ).readAsStringSync();
    final completion = File(
      'lib/features/onboarding/domain/onboarding_completion_service.dart',
    ).readAsStringSync();

    expect(
      onboarding,
      contains("if (defaultTargetPlatform != TargetPlatform.iOS) 'name'"),
    );
    expect(
      onboarding,
      contains(
        "if (defaultTargetPlatform != TargetPlatform.iOS) 'integrations'",
      ),
    );
    expect(completion, isNot(contains('preferred_name_required')));
    expect(completion, contains('if (preferredName.isNotEmpty)'));
    expect(
      completion,
      contains('...DisplayNameSync.localEdit(preferredName),'),
    );
  });

  test('camera requests do not use a dismissible pre-permission prompt', () {
    final profile = File(
      'lib/features/profile/premium_profile_actions.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final coachPermissions = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_conversation_voice.dart',
    ).readAsStringSync();

    for (final source in <String>[profile, dashboard]) {
      expect(source, isNot(contains('Allow camera for this action?')));
      expect(source, contains('request(BilRuntimeCapability.camera)'));
      expect(source, contains('BilRuntimePermissionState.permanentlyDenied'));
    }
    expect(coachPermissions, isNot(contains('final continueRequest =')));
    expect(coachPermissions, isNot(contains('Allow camera for this action?')));
    expect(coachPermissions, contains('policy.request(effectiveCapability)'));
  });

  test(
    'iOS voice requests native permission without a pre-permission prompt',
    () {
      final voice = File(
        'lib/features/nutrition/services/meal_voice_input_service.dart',
      ).readAsStringSync();
      final nativeRequestStart = voice.lastIndexOf(
        'if (defaultTargetPlatform == TargetPlatform.iOS) {',
      );
      final prePermissionStart = voice.indexOf(
        'final continueRequest = await showDialog<bool>(',
      );

      expect(nativeRequestStart, greaterThanOrEqualTo(0));
      expect(prePermissionStart, greaterThan(nativeRequestStart));
      final nativeRequest = voice.substring(
        nativeRequestStart,
        prePermissionStart,
      );
      expect(nativeRequest, contains('await policy.request(capability)'));
      expect(nativeRequest, isNot(contains('showDialog')));
    },
  );

  test('health recommendation surfaces expose reviewable sources', () {
    final route = File('lib/app/router/app_router.dart').readAsStringSync();
    final plan = File(
      'lib/features/onboarding/onboarding_detail_steps.dart',
    ).readAsStringSync();
    final coach = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_center_message_widgets.dart',
    ).readAsStringSync();
    final sources = File(
      'lib/features/settings/health_information_sources_page.dart',
    ).readAsStringSync();
    final sourceCatalog = File(
      'lib/core/health_evidence/health_evidence_catalog.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final referenceSettings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();
    final help = File(
      'lib/features/settings/help_center_page.dart',
    ).readAsStringSync();
    final profilePlan = File(
      'lib/features/profile/plan_page.dart',
    ).readAsStringSync();
    final nutritionAnalytics = File(
      'lib/features/analytics/nutrition_analytics_page.dart',
    ).readAsStringSync();
    final weeklyReport = File(
      'lib/features/analytics/weekly_report_page.dart',
    ).readAsStringSync();
    final dietPlan = File(
      'lib/features/nutrition_plans/presentation/diet_plan_editor_page.dart',
    ).readAsStringSync();
    final dietPlanComponents = File(
      'lib/features/nutrition_plans/presentation/'
      'diet_plan_editor_components.dart',
    ).readAsStringSync();
    final coachHealthTools = File(
      'lib/features/intelligence_center/services/coach_health_tools.dart',
    ).readAsStringSync();
    final coachServer = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    final sleep = File(
      'lib/features/wellness/presentation/sleep_tracker_experience.dart',
    ).readAsStringSync();
    final fasting = File(
      'lib/features/wellness/presentation/fasting_timer_page.dart',
    ).readAsStringSync();
    final exercise = File(
      'lib/features/wellness/presentation/workout_library_selection.dart',
    ).readAsStringSync();
    final professional = File(
      'lib/features/wellness/presentation/'
      'professional_content_library_page.dart',
    ).readAsStringSync();
    final dashboardExplanation = File(
      'lib/features/dashboard/presentation/'
      'dashboard_decision_explanation_page.dart',
    ).readAsStringSync();

    expect(route, contains("path: '/health-information-sources'"));
    expect(plan, contains("context.push('/health-information-sources')"));
    expect(coach, contains("path: '/health-information-sources'"));
    expect(coach, contains("'sources': message.citationIds.join(',')"));
    for (final surface in <String>[
      settings,
      referenceSettings,
      help,
      profilePlan,
      nutritionAnalytics,
      weeklyReport,
      dietPlan,
    ]) {
      expect(surface, contains('/health-information-sources'));
    }
    expect(settings, contains("Key('settings-health-sources-entry')"));
    expect(profilePlan, contains("Key('plan-health-sources')"));
    expect(nutritionAnalytics, contains("Key('nutrition-health-sources')"));
    expect(weeklyReport, contains("Key('weekly-report-health-sources')"));
    expect(dietPlan, contains("Key('diet-plan-health-sources')"));
    expect(
      dietPlanComponents,
      contains("Key('pregnancy-nutrition-references')"),
    );
    expect(
      dietPlanComponents,
      contains('health-information-sources?topic=pregnancy'),
    );
    expect(profilePlan, contains("Key('recommended-targets-sources')"));
    expect(
      sourceCatalog,
      contains('cdc.gov/healthy-weight-growth/losing-weight'),
    );
    expect(sourceCatalog, contains('pubmed.ncbi.nlm.nih.gov/2305711'));
    expect(sourceCatalog, contains('pubmed.ncbi.nlm.nih.gov/29073398'));
    expect(sourceCatalog, contains('physical-activity-guidelines'));
    expect(sourceCatalog, contains('healthy-weight-growth/healthy-eating'));
    expect(sources, contains('Check with a doctor'));
    expect(sourceCatalog, contains('9789241501996'));
    expect(sourceCatalog, contains('9789241550451'));
    expect(sourceCatalog, contains('WHO-statement-IDD-pregnantwomen-children'));
    expect(sourceCatalog, contains('NBK32812'));
    expect(sourceCatalog, contains('bmi/adult-calculator/bmi-categories'));
    expect(sourceCatalog, contains('waist-to-height-ratio'));
    expect(coachHealthTools, contains("'healthCitationIds'"));
    expect(coachHealthTools, contains('HealthEvidenceCatalog.validateIds'));
    expect(coachHealthTools, isNot(contains("'healthReferences'")));
    expect(coachServer, contains('healthCitationCatalogContract'));
    expect(coachServer, contains('allowedHealthCitationIds'));
    expect(coachServer, contains('citations'));
    expect(coachServer, contains('Only make numeric health claims supported'));
    expect(coachServer, contains('must never be used as a substitute'));
    expect(sleep, contains("Key('sleep-health-sources')"));
    expect(fasting, contains("Key('fasting-health-sources')"));
    expect(exercise, contains("Key('exercise-met-health-sources')"));
    expect(professional, contains("Key('professional-content-source-link')"));
    expect(professional, contains('LaunchMode.externalApplication'));
    expect(dashboardExplanation, contains("Key('decision-health-sources')"));
  });
}
