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

    expect(route, contains("path: '/health-information-sources'"));
    expect(plan, contains("context.push('/health-information-sources')"));
    expect(coach, contains("context.push('/health-information-sources')"));
    expect(sources, contains('cdc.gov/healthy-weight-growth/losing-weight'));
    expect(sources, contains('ods.od.nih.gov/factsheets/Potassium'));
    expect(sources, contains('pubmed.ncbi.nlm.nih.gov/2305711'));
    expect(sources, contains('pubmed.ncbi.nlm.nih.gov/29073398'));
    expect(sources, contains('water-intake guidance'));
  });
}
