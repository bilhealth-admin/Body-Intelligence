import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_loading_skeleton.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today loading state preserves structure without a spinner', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: DashboardLoadingSkeleton()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'جارٍ تحميل لوحة اليوم' &&
            widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test(
    'dashboard pull is elastic only and has no synchronization callback',
    () {
      final page = File(
        'lib/features/dashboard/dashboard_page.dart',
      ).readAsStringSync();
      final shell = File(
        'lib/features/dashboard/widgets/dashboard_shell.dart',
      ).readAsStringSync();

      expect(shell, isNot(contains('DashboardScrollPhysics')));
      expect(shell, isNot(contains('AlwaysScrollableScrollPhysics')));
      expect(shell, isNot(contains('BouncingScrollPhysics')));
      expect(shell, isNot(contains('onRefresh')));
      expect(shell, isNot(contains('_ElasticDashboardRefresh')));
      expect(page, isNot(contains('refreshDailyActivity(force: true)')));
      expect(page, isNot(contains('onRefresh:')));
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: dashboard stretches at both edges without chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const DashboardShell(child: SizedBox(height: 2000)),
        ),
      );
      final target = find.byKey(const Key('dashboard-scroll-view'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: target, matching: find.byType(Scrollable)),
          )
          .position;

      if (platform == TargetPlatform.iOS) {
        expect(position.physics, isA<BouncingScrollPhysics>());
      } else {
        expect(position.physics, isA<ClampingScrollPhysics>());
      }
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.drag(target, const Offset(0, 300));
      await tester.pump();
      if (platform == TargetPlatform.iOS) {
        expect(position.pixels, lessThan(position.minScrollExtent));
      } else {
        expect(position.pixels, closeTo(position.minScrollExtent, .5));
      }
      await tester.pumpAndSettle();

      position.jumpTo(position.maxScrollExtent);
      await tester.drag(target, const Offset(0, -300));
      await tester.pump();
      if (platform == TargetPlatform.iOS) {
        expect(position.pixels, greaterThan(position.maxScrollExtent));
      } else {
        expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      }
      await tester.pumpAndSettle();
    });
  }

  test('dashboard editor exposes current cards only', () {
    final provider = File(
      'lib/features/dashboard/providers/dashboard_preferences_provider.dart',
    ).readAsStringSync();
    final catalog = File(
      'lib/features/dashboard/presentation/dashboard_preferences_catalog.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/dashboard/presentation/dashboard_preferences_page.dart',
    ).readAsStringSync();

    expect(provider, isNot(contains("'daily_intelligence'")));
    expect(catalog, isNot(contains('Daily intelligence')));
    expect(page, isNot(contains('dashboard-edit-step-goal')));
    expect(page, isNot(contains('dashboard-edit-exercise-settings')));
    expect(page, contains('dashboard-edit-nutrition-goals'));
  });
}
