import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trial and locked-card copy is complete in all 25 locales', () {
    const keys = <String>[
      '7 days free',
      'Start 7-day free trial',
      '7-day trial with 1,000 AI tokens',
      '7-day trial includes 1,000 AI tokens',
      'Watch and health sync',
      'Compatible fitness device connections',
    ];
    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in RuntimeCopy.supported) {
        final translated = RuntimeCopy.resolve(key, locale);
        expect(translated, isNotNull, reason: '$key missing for $locale');
        expect(
          translated!.trim(),
          isNotEmpty,
          reason: '$key empty for $locale',
        );
        if (locale != 'en') {
          expect(translated, isNot(key), reason: '$key fell back for $locale');
        }
      }
    }
  });

  test('watch sync is free while fitness devices remain behind glass', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final healthCard = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final health = File(
      'lib/features/connected_health/connected_health_page.dart',
    ).readAsStringSync();

    expect(
      dashboard,
      contains('visibleSections.contains(DashboardSectionIds.connectedHealth)'),
    );
    expect(dashboard, contains('connectedHealth!'));
    expect(
      dashboard,
      isNot(contains("Key('dashboard-connected-health-premium-lock')")),
    );
    expect(healthCard, contains('onSync:'));
    expect(healthCard, contains('.synchronize()'));
    expect(healthCard, isNot(contains('PremiumDashboardCardLock')));
    expect(health, contains('PremiumDashboardCardLock'));
    expect(health, contains("Key('fitness-devices-premium-gate')"));
    expect(health, contains('Premium fitness device connections'));
    expect(health, contains('Weight, body composition, and heart rate'));
  });

  test(
    'destination glass names the hidden feature without inventing a trial',
    () {
      final lock = File(
        'lib/features/dashboard/widgets/premium_dashboard_card_lock.dart',
      ).readAsStringSync();
      final routeGate = File(
        'lib/features/commerce/presentation/premium_route_glass_gate.dart',
      ).readAsStringSync();

      expect(lock, contains('PremiumLabelBadge'));
      expect(lock, contains('label: title'));
      expect(lock, isNot(contains("RuntimeCopy.resolve('7 days free'")));
      expect(lock, contains('detail'));
      expect(routeGate, contains('1,500 nutrition-aware recipes'));
      expect(routeGate, contains('Nutrition and food facts'));
      expect(routeGate, contains('Step-by-step preparation'));
      expect(routeGate, isNot(contains('Nutrition and portions included')));
      expect(routeGate, contains('10 training categories'));
      expect(routeGate, contains('My Routines'));
      expect(routeGate, isNot(contains('300+ home workout videos')));
      expect(
        routeGate,
        isNot(contains('100+ video-guided weight-training plans')),
      );
      expect(routeGate, isNot(contains('200 guided workout movements')));
      expect(routeGate, contains("? '/plans?focus=boost'"));
      expect(routeGate, contains("context.strings.text('Get AI Boost')"));
      expect(routeGate, contains("BilStoreCopy.text(storeLocale, 'plans')"));
      expect(routeGate, isNot(contains("action: t('Start 7-day free trial')")));
      expect(routeGate, contains('2,500 verified, non-expiring tokens'));
    },
  );

  test('discover destinations preserve Android back navigation', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
    ).readAsStringSync();

    expect(source, contains('onTap: () => context.push(route)'));
    expect(source, isNot(contains('onTap: () => context.go(route)')));
  });
}
