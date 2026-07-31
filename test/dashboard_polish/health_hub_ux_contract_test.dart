import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health Hub empty state is complete and truthful', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(card, contains("tr('Health Hub', 'المركز الصحي')"));
    expect(card, contains("tr('Connect now', 'ربط الآن')"));
    expect(card, contains('No connected sources'));
    expect(card, contains('قراءة الساعة الذكية'));
    expect(card, contains(' Health'));
    expect(card, contains('Health Connect'));
    expect(card, contains("Key('health-hub-empty-state')"));
    expect(card, contains("Key('health-hub-connect-button')"));
    expect(card, contains('Icons.watch_outlined'));
    expect(card, contains('_WatchPainter'));
  });

  test('Health Hub polish remains presentation-only', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/connected_health/connected_health_page.dart',
    ).readAsStringSync();

    expect(card, contains('connectedHealthProvider'));
    expect(card, contains("context.go('/connected-health')"));
    expect(card, isNot(contains('TruthEngine')));
    expect(card, isNot(contains('BodyTwin')));
    expect(card, isNot(contains('OneBestAction')));
    expect(page, contains("tr('Health Hub', 'المركز الصحي')"));
  });

  test('connected state keeps carousel and source management', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(card, contains('DashboardCarousel('));
    expect(card, contains("tr('Manage sources', 'إدارة المصادر')"));
    expect(card, contains("tr('Not connected', 'غير متصل')"));
    expect(card, contains('_displaySource'));
  });
}
