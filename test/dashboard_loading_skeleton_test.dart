import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_loading_skeleton.dart';
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

  test('pull to refresh awaits providers and handles both outcomes', () {
    final source = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'Future<void> refresh(BuildContext context, WidgetRef ref) async',
      ),
    );
    expect(source, contains('await Future.wait(['));
    expect(source, contains("context.strings.text('Today is up to date.')"));
    expect(source, contains("'Some local Today data could not be refreshed.'"));
    expect(source, contains('if (context.mounted)'));
    expect(source, contains('onRefresh: () => refresh(context, ref)'));
  });
}
