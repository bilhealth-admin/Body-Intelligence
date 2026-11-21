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
      final continuity = File(
        'lib/features/commerce/repositories/server_entitlement_grant_continuity.dart',
      ).readAsStringSync();
      expect(
        repository,
        contains("part 'server_entitlement_grant_continuity.dart';"),
      );
      final storeContinuity = File(
        'lib/features/commerce/repositories/server_entitlement_store_continuity.dart',
      ).readAsStringSync();
      expect(
        repository,
        contains("part 'server_entitlement_store_continuity.dart';"),
      );
      final closedTestBranch = repository.indexOf('if (closedTestActive) {');
      final subscriptionQuery = repository.indexOf(
        ".from('bil_subscriptions')",
      );
      final verifiedFree = repository.indexOf(
        RegExp(
          r'_verifiedFree\(\s*verifiedAt:\s*verifiedAt,\s*serverRevision:\s*revision',
        ),
      );
      expect(closedTestBranch, greaterThanOrEqualTo(0));
      expect(subscriptionQuery, greaterThan(closedTestBranch));
      expect(verifiedFree, greaterThan(subscriptionQuery));
      final closedTestBody = repository.substring(
        closedTestBranch,
        subscriptionQuery,
      );
      // Awaiting secure continuity must not bypass a newer revocation or the
      // real grant expiry. The exact local variable name is irrelevant.
      expect(
        closedTestBody,
        contains(
          RegExp(
            r'final\s+(\w+)\s*=\s*await\s+_remember\('
            r'[\s\S]*?_closedTestState\([\s\S]*?\);\s*'
            r'return\s+_revalidateClosedTestObservation\(\s*'
            r'user\.id,\s*\1,\s*closedTestReadGeneration,?\s*\);',
          ),
        ),
      );
      // A canonical Free result retains its store-terminal evidence, while
      // inactive/expired observations also retain renewal metadata. Neither
      // adds a paid entitlement or turns offline fallback into verified Free.
      expect(
        repository,
        contains(
          RegExp(
            r'_remember\(\s*user\.id,\s*_verifiedFree\(\s*'
            r'verifiedAt:\s*verifiedAt,\s*serverRevision:\s*revision,\s*storeDefinitive:\s*'
            r"providerValue\s*==\s*'google'\s*\|\|\s*"
            r"providerValue\s*==\s*'apple',\s*\),\s*now,\s*\)",
          ),
        ),
      );
      expect(
        repository,
        contains(
          RegExp(
            r'_remember\(\s*user\.id,\s*_verifiedFree\(\s*'
            r'verifiedAt:\s*verifiedAt,\s*serverRevision:\s*revision,\s*storeRenewal:\s*storeRenewal,\s*'
            r'storeDefinitive:\s*storeDefinitive,\s*\),\s*now,\s*\)',
          ),
        ),
      );
      final constructorStart = continuity.indexOf(
        'SubscriptionState _verifiedFree(',
      );
      final constructorEnd = continuity.indexOf(
        'SubscriptionState _closedTestState(',
      );
      expect(constructorStart, greaterThanOrEqualTo(0));
      expect(constructorEnd, greaterThan(constructorStart));
      final verifiedFreeConstructor = continuity.substring(
        constructorStart,
        constructorEnd,
      );
      expect(verifiedFreeConstructor, contains('plan: CommercePlan.free'));
      expect(
        verifiedFreeConstructor,
        contains('serverRevision: serverRevision'),
      );
      expect(
        verifiedFreeConstructor,
        contains('storeRenewalObservation: storeRenewal'),
      );
      expect(
        verifiedFreeConstructor,
        contains('storeRenewalDefinitivelyInactive: storeDefinitive'),
      );
      expect(
        verifiedFreeConstructor,
        contains('entitlements: FreePlan.entitlements'),
      );
      expect(
        verifiedFreeConstructor,
        contains('authority: EntitlementAuthority.verifiedServer'),
      );
      final fallbackStart = continuity.indexOf(
        'Future<SubscriptionState> _transientFallback(',
      );
      final fallbackEnd = continuity.indexOf(
        'SubscriptionState _withClosedTestContinuity(',
      );
      expect(fallbackStart, greaterThanOrEqualTo(0));
      expect(fallbackEnd, greaterThan(fallbackStart));
      final fallbackBody = continuity.substring(fallbackStart, fallbackEnd);
      expect(fallbackBody, contains('CommunityOwnerOperation.checkCurrent();'));
      expect(fallbackBody, contains(RegExp(r'_sessionCache\.fallbackFor\(')));
      expect(
        fallbackBody,
        contains(
          RegExp(r'inMemory\s*!=\s*null\s*&&\s*inMemory\.provider\s*!=\s*null'),
        ),
      );
      expect(
        fallbackBody,
        contains('final persisted = await _subscriptionStore.read('),
      );
      expect(
        fallbackBody,
        contains('final restored = _restoreStoreProof(ownerId, persisted);'),
      );
      final restoreStart = storeContinuity.indexOf(
        'SubscriptionState? _restoreStoreProof(',
      );
      final restoreEnd = storeContinuity.indexOf(
        'SubscriptionState _survivingStoreProof(',
      );
      expect(restoreStart, greaterThanOrEqualTo(0));
      expect(restoreEnd, greaterThan(restoreStart));
      final restoreBody = storeContinuity.substring(restoreStart, restoreEnd);
      expect(
        restoreBody,
        contains(
          RegExp(
            r'persisted\s*==\s*null\s*\|\|\s*persisted\.provider\s*==\s*null',
          ),
        ),
      );
      expect(
        restoreBody,
        contains('final current = _survivingStoreProof(ownerId)'),
      );
      expect(
        restoreBody,
        contains('if (current.provider != null) return current'),
      );
      expect(restoreBody, contains('final now = _now();'));
      expect(restoreBody, contains('!boundary.isAfter(now)'));
      expect(
        restoreBody,
        contains('(persisted.startedAt?.toUtc().isAfter(now)'),
      );
      expect(restoreBody, contains('_storeObservationIsCurrent('));
      expect(restoreBody, contains('allowIndependentPriorLease: true'));
      expect(restoreBody, isNot(contains('_verifiedFree(')));
      expect(fallbackBody, isNot(contains('_verifiedFree(')));
      expect(
        fallbackBody,
        contains('_storeProofSurvivesDenial(ownerId, inMemory)'),
      );
      expect(
        restoreBody,
        contains('_storeProofSurvivesDenial(ownerId, persisted)'),
      );
      expect(
        fallbackBody,
        contains(
          RegExp(
            r'return\s+_withClosedTestContinuity\(\s*ownerId,\s*'
            r'FreePlan\.createState\(\)\s*\);',
          ),
        ),
      );
      final revalidationStart = continuity.indexOf(
        'SubscriptionState _revalidateClosedTestObservation(',
      );
      expect(revalidationStart, greaterThanOrEqualTo(0));
      expect(constructorStart, greaterThan(revalidationStart));
      final revalidationBody = continuity.substring(
        revalidationStart,
        constructorStart,
      );
      expect(
        revalidationBody,
        contains('CommunityOwnerOperation.checkCurrent();'),
      );
      expect(
        revalidationBody,
        contains('_storeProofSurvivesDenial(ownerId, state)'),
      );
      expect(
        revalidationBody,
        contains('_storeObservationIsCurrent(ownerId, state)'),
      );
      expect(
        revalidationBody,
        contains('verifiedSubscriptionPeriodAt(state, now)'),
      );
      expect(
        revalidationBody,
        contains(
          'allowContinuity ? _survivingStoreProof(ownerId) : FreePlan.createState()',
        ),
      );
      expect(revalidationBody, contains('_settledClosedTestReadGeneration'));
      expect(revalidationBody, contains('boundary.isAfter(_now())'));
      expect(revalidationBody, isNot(contains('_verifiedFree(')));
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
