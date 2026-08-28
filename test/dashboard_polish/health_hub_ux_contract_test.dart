import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health Hub empty state is complete and truthful', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final emptyState = File(
      'lib/features/connected_health/widgets/health_hub_empty_state.dart',
    ).readAsStringSync();
    final surface = '$card\n$emptyState';

    expect(card, contains("tr('Health Hub', '"));
    expect(surface, contains("tr('Connect now', '"));
    /* Legacy encoding assertions removed.
    expect(card, contains("tr('Health Hub', 'المركز الصحي')"));
    expect(card, contains("tr('Connect now', 'ربط الآن')"));
    expect(surface, contains('Connect now'));
    expect(card, contains('قراءة الساعة الذكية'));
    expect(card, contains(' Health'));
    expect(card, contains('Health Connect'));
    */
    expect(surface, contains("Key('health-hub-empty-state')"));
    expect(surface, contains("Key('health-hub-connect-button')"));
    expect(surface, contains("Key('health-hub-device-carousel')"));
    expect(surface, contains("Key('health-hub-fixed-square-watch')"));
    expect(surface, contains('BilMedicalMonitor('));
  });

  test('Health Hub polish remains presentation-only', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/connected_health/connected_health_page.dart',
    ).readAsStringSync();

    expect(card, contains('connectedHealthProvider'));
    expect(card, contains("context.push('/connected-health')"));
    expect(card, isNot(contains('TruthEngine')));
    expect(card, isNot(contains('BodyTwin')));
    expect(card, isNot(contains('OneBestAction')));
    expect(page, contains("tr('Health Hub', '"));
    /* Legacy encoding assertion removed.
    expect(page, contains("tr('Health Hub', 'المركز الصحي')"));
    */
  });

  test('connected state keeps carousel and source management', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(card, contains('DashboardCarousel('));
    expect(card, contains("tr('Manage sources', '"));
    expect(card, contains("tr('Not connected', '"));
    /* Legacy encoding assertions removed.
    expect(card, contains("tr('Manage sources', 'إدارة المصادر')"));
    expect(card, contains("tr('Not connected', 'غير متصل')"));
    */
    expect(card, contains('_displaySource'));
  });
}
