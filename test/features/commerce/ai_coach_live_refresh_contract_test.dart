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
    final appPurchases = File(
      'lib/features/commerce/providers/app_purchase_providers.dart',
    ).readAsStringSync();
    final resetNotices = File(
      'lib/features/notifications/presentation/'
      'ai_coach_reset_notice_coordinator.dart',
    ).readAsStringSync();

    expect(
      providers,
      contains('aiCoachCreditAccessProvider = FutureProvider<bool>'),
    );
    expect(
      providers,
      isNot(
        contains(
          'aiCoachCreditAccessProvider = FutureProvider.autoDispose<bool>',
        ),
      ),
    );
    expect(
      providers,
      contains('ref.watch(verifiedEntitlementOwnerIdProvider);'),
    );
    expect(providers, contains("credits['total_remaining']"));
    expect(query, contains('ref.invalidate(aiCoachCreditAccessProvider);'));
    expect(plans, contains('store.state == VerifiedStoreState.verified'));
    expect(plans, contains('ref.invalidate(aiCoachCreditAccessProvider);'));
    // The owner-scoped app service now refreshes every reader even after
    // Settings/Plans closes. Do not demand a second page-owned receipt listener.
    expect(
      settings,
      contains(
        'ref.read(appBoostPurchaseProvider)..addListener(_boostChanged)',
      ),
    );
    expect(settings, isNot(contains('AiBoostPurchaseService()')));
    expect(settings, contains('boost.removeListener(_boostChanged)'));
    expect(settings, isNot(contains('boost.dispose()')));
    expect(plans, contains('ref.read(appBoostPurchaseProvider)'));
    expect(
      appPurchases,
      contains('ref.watch(verifiedEntitlementOwnerIdProvider)'),
    );
    expect(
      appPurchases,
      contains('revision == service.verifiedCreditsRevision'),
    );
    expect(
      appPurchases,
      contains('revision = service.verifiedCreditsRevision;'),
    );
    expect(
      appPurchases,
      contains('ref.read(verifiedEntitlementOwnerIdProvider) != owner'),
    );
    expect(
      appPurchases,
      contains('ref.invalidate(aiVisionCreditStateProvider);'),
    );
    expect(
      appPurchases,
      contains('ref.invalidate(aiCoachCreditAccessProvider);'),
    );
    expect(appPurchases, contains('.requestAuthoritativeReload();'));
    expect(
      resetNotices,
      contains('ref.invalidate(aiCoachCreditAccessProvider);'),
    );
    expect(resetNotices, contains('.requestAuthoritativeReload();'));
    expect(settings, contains('ref.listen<int>(aiCoachUsageRefreshProvider'));
    expect(settings, contains('usage = _startUsageLoad();'));
  });

  test('exhaustion routes stay scoped to AI Coach and Boost', () {
    final actions = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_action_flow.dart',
    ).readAsStringSync();
    final offers = File(
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
    ).readAsStringSync();

    expect(
      actions,
      contains("_openCoachRoute('/plans?focus=ai-coach', push: true)"),
    );
    expect(
      actions,
      contains("_openCoachRoute('/plans?focus=boost', push: true)"),
    );
    expect(offers, contains("widget.initialFocus == 'ai-coach'"));
    expect(offers, contains("widget.initialFocus == 'boost'"));
    expect(offers, contains('do not silently select ordinary Premium'));
  });
}
