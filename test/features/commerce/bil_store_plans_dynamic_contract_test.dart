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
    expect(find.text('Premium AI Coach'), findsNothing);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(2));
    expect(find.textContaining('Loading price'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan route respects dark interface and 200% text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const BilStorePlansPage(connectToDeviceStore: false),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(Colors.white));
    expect(find.byTooltip('Close'), findsOneWidget);
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
