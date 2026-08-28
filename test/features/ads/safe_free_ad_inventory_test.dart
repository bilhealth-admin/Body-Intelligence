import 'dart:io';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safe Free ad inventory', () {
    test('only reviewed discovery surfaces own anchors', () {
      final anchorFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) {
            final normalized = file.path.replaceAll('\\', '/');
            if (normalized.endsWith(
              '/features/ads/presentation/safe_free_ad_anchor.dart',
            )) {
              return false;
            }
            return file.readAsStringSync().contains('SafeFreeAdAnchor(');
          })
          .map((file) => file.path.replaceAll('\\', '/'))
          .toSet();

      expect(anchorFiles, {
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
        'lib/features/daily_log/daily_log_page.dart',
        'lib/features/history/progress_page.dart',
        'lib/features/settings/settings_page.dart',
        'lib/features/wellness/presentation/wellness_library_page.dart',
      });
    });

    test('native slot is reachable only through SafeFreeAdAnchor', () {
      final directSlotFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) {
            final normalized = file.path.replaceAll('\\', '/');
            if (normalized.endsWith(
              '/features/ads/presentation/safe_contextual_banner_slot.dart',
            )) {
              return false;
            }
            return file.readAsStringSync().contains(
              'SafeContextualBannerSlot(',
            );
          })
          .map((file) => file.path.replaceAll('\\', '/'))
          .toSet();

      expect(directSlotFiles, {
        'lib/features/ads/presentation/safe_free_ad_anchor.dart',
      });
    });

    test(
      'anchors use generic placement and render no fake placeholder copy',
      () {
        final anchor = File(
          'lib/features/ads/presentation/safe_free_ad_anchor.dart',
        ).readAsStringSync();
        expect(anchor, contains('placement: AdPlacement.generalDiscovery'));
        expect(anchor, isNot(contains('AdPlacement.dashboard')));
        expect(anchor, isNot(contains('AdPlacement.dailyLog')));
        expect(anchor, isNot(contains("Text('Ad')")));
        expect(anchor, isNot(contains("Text('Advertisement')")));
        expect(anchor, isNot(contains('Container(color: Colors.grey')));
      },
    );

    test('gateway contract accepts placement only, never private context', () {
      final gateway = File(
        'lib/features/ads/services/contextual_ad_gateway.dart',
      ).readAsStringSync();
      expect(
        gateway,
        contains(
          'Future<ContextualBannerHandle?> loadBanner(AdPlacement placement);',
        ),
      );
      expect(gateway, isNot(contains('loadBanner({')));
      expect(gateway, isNot(contains('Map<String, dynamic>')));

      final adapter = File(
        'lib/features/ads/services/admob_contextual_ad_gateway.dart',
      ).readAsStringSync();
      expect(adapter, contains('AdRequest(nonPersonalizedAds: true)'));
      expect(adapter, isNot(contains('keywords:')));
      expect(adapter, isNot(contains('contentUrl:')));
      expect(adapter, isNot(contains('neighboringContentUrls:')));
    });

    test('server distinguishes verified Free from offline fallback Free', () {
      final repository = File(
        'lib/features/commerce/repositories/server_entitlement_repository.dart',
      ).readAsStringSync();
      expect(repository, contains('if (!closedTestActive) {'));
      expect(repository, contains('_remember(user.id, _verifiedFree(), now)'));
      expect(
        repository,
        contains('authority: EntitlementAuthority.verifiedServer'),
      );
      expect(repository, contains('return _sessionCache.fallbackFor('));
      expect(repository, contains('??\n          FreePlan.createState();'));
    });
  });

  group('eligibility matrix', () {
    const policy = AdPolicy();
    final free = SubscriptionState(
      plan: CommercePlan.free,
      entitlements: const {},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: false,
      canRestorePurchases: false,
    );

    AdPolicyDecision decide({
      SubscriptionState? subscription,
      AdAgeEligibility age = AdAgeEligibility.adult,
      bool online = true,
      bool configured = true,
      AdPlacement placement = AdPlacement.generalDiscovery,
    }) => policy.evaluate(
      subscription: subscription ?? free,
      placement: placement,
      providerConfigured: configured,
      isOnline: online,
      ageEligibility: age,
    );

    test('verified Free plus every safety signal is the only allowed case', () {
      expect(decide().reason, AdSuppressionReason.allowed);
      expect(
        decide(
          subscription: SubscriptionState(
            plan: CommercePlan.free,
            entitlements: const {},
            authority: EntitlementAuthority.localDefault,
            isPurchasable: false,
            canRestorePurchases: false,
          ),
        ).reason,
        AdSuppressionReason.entitlementUnverified,
      );
      expect(
        decide(age: AdAgeEligibility.unknown).reason,
        AdSuppressionReason.ageUnknown,
      );
      expect(
        decide(age: AdAgeEligibility.under18).reason,
        AdSuppressionReason.underage,
      );
      expect(decide(online: false).reason, AdSuppressionReason.offline);
      expect(
        decide(configured: false).reason,
        AdSuppressionReason.providerUnavailable,
      );
      for (final sensitive in const [
        AdPlacement.wellnessLibrary,
        AdPlacement.dashboard,
        AdPlacement.dailyLog,
        AdPlacement.foodEntry,
        AdPlacement.progress,
        AdPlacement.connectedHealth,
        AdPlacement.profile,
        AdPlacement.settings,
        AdPlacement.paywall,
      ]) {
        expect(
          decide(placement: sensitive).reason,
          AdSuppressionReason.sensitiveContext,
          reason: sensitive.name,
        );
      }
    });

    test('both paid consumer plans are always suppressed', () {
      for (final plan in const [
        CommercePlan.premium,
        CommercePlan.premiumAiCoach,
      ]) {
        final paid = SubscriptionState(
          plan: plan,
          entitlements: const {},
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: true,
        );
        expect(
          decide(subscription: paid).reason,
          AdSuppressionReason.paidSubscription,
          reason: plan.name,
        );
      }
    });
  });
}
