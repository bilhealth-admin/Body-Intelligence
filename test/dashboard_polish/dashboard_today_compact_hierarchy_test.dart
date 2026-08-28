import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Today keeps coach, watch, then nutrition in the first-glance order', () {
    final phone = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final health = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final cards = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
    ).readAsStringSync();
    final goals = File(
      'lib/features/dashboard/widgets/dashboard_reference_goal_components.dart',
    ).readAsStringSync();

    final layout = phone.substring(phone.indexOf('return Column('));
    final coach = layout.indexOf('_ReferenceAiCoachCard(arabic: arabic)');
    final watch = layout.indexOf('connectedHealth!');
    final nutrition = layout.indexOf('_OverviewCardsCarousel(');

    expect(coach, greaterThanOrEqualTo(0));
    expect(watch, greaterThan(coach));
    expect(nutrition, greaterThan(watch));
    expect(goals, contains("Key('dashboard-reference-calories-card')"));
    expect(goals, contains("Key('dashboard-reference-macros-card')"));
    expect(phone, contains("Key('dashboard-heart-circle-card')"));
    expect(cards, contains('viewportFraction: 1'));
    expect(cards, isNot(contains('viewportFraction: .94')));
    expect(cards, contains('padEnds: false'));
    expect(health, contains("Key('dashboard-health-device-pager')"));
    expect(health, contains('height: 188'));
    expect(health, contains('maxWidth: 188, maxHeight: 188'));
    expect(health, contains('compact: true'));
    expect(health, isNot(contains('child: FittedBox(')));
    expect(cards, contains('(224 +'));
    expect(cards, contains('MediaQuery.textScalerOf(context)'));

    final discover = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
    ).readAsStringSync();
    expect(discover, contains('dashboard-discover-balanced-final-tile'));
    expect(discover, contains('pairedItemCount'));
  });

  testWidgets('premium loading skeleton mirrors the compact Today hierarchy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: SingleChildScrollView(child: DashboardLoadingSkeleton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final coach = find.byKey(const Key('dashboard-loading-coach'));
    final watch = find.byKey(const Key('dashboard-loading-watch'));
    final nutrition = find.byKey(const Key('dashboard-loading-nutrition'));
    expect(coach, findsOneWidget);
    expect(watch, findsOneWidget);
    expect(nutrition, findsOneWidget);
    expect(tester.getTopLeft(coach).dy, lessThan(tester.getTopLeft(watch).dy));
    expect(
      tester.getTopLeft(watch).dy,
      lessThan(tester.getTopLeft(nutrition).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
