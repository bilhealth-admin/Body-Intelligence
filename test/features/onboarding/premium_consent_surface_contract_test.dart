import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('third-party consent entry points share the premium trust surface', () {
    final onboarding = File(
      'lib/features/onboarding/onboarding_detail_steps.dart',
    ).readAsStringSync();
    final coach = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();
    final vision = File(
      'lib/features/nutrition/presentation/meal_vision_consent_gate.dart',
    ).readAsStringSync();
    final privacy = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();
    final shared = File(
      'lib/shared/widgets/bil_premium_trust_surface.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_usage_widgets.dart',
    ).readAsStringSync();

    expect(onboarding, contains('showBilPremiumAiConsentSheet('));
    expect(onboarding, contains("Key('onboarding-ai-consent-decline')"));
    expect(onboarding, contains("Key('onboarding-ai-consent-accept')"));
    expect(coach, contains('showBilPremiumAiConsentSheet('));
    expect(vision, contains('BilPremiumTrustSurface('));
    expect(vision, contains("Key('meal-vision-consent-decline')"));
    expect(vision, contains("Key('meal-vision-consent-accept')"));
    expect(privacy, contains('BilPremiumConsentToggle('));
    expect(privacy, contains("Key('meal-vision-ai-consent')"));
    expect(settings, contains('BilPremiumConsentToggle('));
    expect(shared, contains('class _BilPremiumAiConsentSheet'));
    expect(shared, contains('SingleChildScrollView('));
    expect(shared, contains('Color(0xFF64D8FF)'));
    expect(shared, contains('Color(0xFF7568FF)'));
  });
}
