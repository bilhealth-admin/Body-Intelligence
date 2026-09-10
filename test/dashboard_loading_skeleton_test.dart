import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
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
    'pull to refresh keeps the complete local provider refresh contract',
    () {
      final source = File(
        'lib/features/dashboard/dashboard_page.dart',
      ).readAsStringSync();

      for (final refresh in const <String>[
        'ref.refresh(latestWeightProvider.future)',
        'ref.refresh(weightHistoryProvider.future)',
        'ref.refresh(userProfileProvider.future)',
        'ref.refresh(todayMealsProvider.future)',
        'ref.refresh(todayWaterProvider.future)',
        'ref.refresh(allMealsProvider.future)',
        'ref.refresh(allWaterProvider.future)',
        'ref.refresh(weightReminderSkippedTodayProvider.future)',
        'ref.refresh(todayLifeContextProvider.future)',
      ]) {
        expect(
          source,
          contains(refresh),
          reason: 'Missing refresh contract: $refresh',
        );
      }
    },
  );

  test(
    'pull to refresh settles sources independently without false errors',
    () {
      final source = File(
        'lib/features/dashboard/dashboard_page.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'Future<void> refresh(BuildContext context, WidgetRef ref) async',
        ),
      );
      expect(source, contains('await Future.wait<bool>(['));
      expect(source, contains('_settleDashboardRefresh'));
      expect(source, contains('dashboardSourceRefreshMaximum'));
      expect(source, contains('refreshed.every((succeeded) => !succeeded)'));
      expect(
        source,
        isNot(contains("context.strings.text('Today is up to date.')")),
      );
      expect(
        source,
        contains("'Some local Today data could not be refreshed.'"),
      );
      expect(source, contains('if (context.mounted)'));
      expect(source, contains('onRefresh: () => refresh(context, ref)'));
      expect(source, contains('await Future.any<void>(['));
      expect(
        dashboardRefreshIndicatorMaximum,
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    },
  );

  testWidgets('dashboard refresh gesture updates without spinner chrome', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardShell(
          onRefresh: () async {
            refreshes += 1;
          },
          child: const SizedBox(height: 1200),
        ),
      ),
    );

    expect(
      find.byKey(const Key('dashboard-background-refresh')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, 420),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('a slow refresh never pins the dashboard below its top edge', (
    tester,
  ) async {
    final refresh = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardShell(
          onRefresh: () => refresh.future,
          child: const SizedBox(height: 1200),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('dashboard-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, closeTo(0, 0.5));
    expect(refresh.isCompleted, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    refresh.complete();
    await tester.pumpAndSettle();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: reversing a pull does not refresh on release', (
      tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: DashboardShell(
            onRefresh: () async {
              refreshes++;
            },
            child: const SizedBox(height: 2000),
          ),
        ),
      );
      final target = find.byKey(const Key('dashboard-scroll-view'));
      final gesture = await tester.startGesture(tester.getCenter(target));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -400));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshes, 0);

      final position = tester
          .state<ScrollableState>(
            find.descendant(of: target, matching: find.byType(Scrollable)),
          )
          .position;
      var bounces = false;
      for (
        ScrollPhysics? physics = position.physics;
        physics != null;
        physics = physics.parent
      ) {
        bounces |= physics is BouncingScrollPhysics;
      }
      expect(
        bounces,
        platform == TargetPlatform.iOS,
        reason: 'Use the same native platform physics as More',
      );
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
