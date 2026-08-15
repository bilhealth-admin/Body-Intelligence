import 'dart:io';

import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan route is fail-closed when owner store IDs are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BilStorePlansPage(connectToDeviceStore: false)),
    );
    await tester.pump();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsOneWidget);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(3));
    expect(find.textContaining('Loading price'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('legacy glass paywall is not imported by the production plan route', () {
    final routeSource = File(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    ).readAsStringSync();
    expect(routeSource, isNot(contains('glass_store_offer.dart')));
    expect(routeSource, contains('BilDynamicStoreOffers'));
  });
}
