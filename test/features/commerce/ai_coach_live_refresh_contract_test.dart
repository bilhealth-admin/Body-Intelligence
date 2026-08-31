import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach access refreshes after usage, purchase, and restore', () {
    final providers = File(
      'lib/features/commerce/providers/commerce_providers.dart',
    ).readAsStringSync();
    final query = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_query_flow.dart',
    ).readAsStringSync();
    final plans = File(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/intelligence_center/presentation/'
      'ai_coach_settings_page.dart',
    ).readAsStringSync();

    expect(
      providers,
      contains(
        'aiCoachCreditAccessProvider = FutureProvider.autoDispose<bool>',
      ),
    );
    expect(providers, contains("credits['total_remaining']"));
    expect(query, contains('ref.invalidate(aiCoachCreditAccessProvider);'));
    expect(plans, contains('store.state == VerifiedStoreState.verified'));
    expect(plans, contains('ref.invalidate(aiCoachCreditAccessProvider);'));
    expect(settings, contains('boost.state == AiBoostPurchaseState.verified'));
    expect(settings, contains('ref.invalidate(aiCoachCreditAccessProvider);'));
  });

  test('exhaustion routes stay scoped to AI Coach and Boost', () {
    final actions = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_action_flow.dart',
    ).readAsStringSync();
    final offers = File(
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
    ).readAsStringSync();

    expect(actions, contains("context.push('/plans?focus=ai-coach')"));
    expect(actions, contains("context.push('/plans?focus=boost')"));
    expect(offers, contains("widget.initialFocus == 'ai-coach'"));
    expect(offers, contains("widget.initialFocus == 'boost'"));
    expect(offers, contains('do not silently select ordinary Premium'));
  });
}
