import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'saved Dashboard view uses a real neutral pending read, then renders its preset',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final held = StreamController<String?>();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await held.close();
          await database.close();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              dashboardSelectedPresetProvider.overrideWith((_) => held.stream),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(FreePlan.createState()),
              ),
              for (final section in DashboardSectionIds.all)
                dashboardSectionVisibleProvider(
                  section,
                ).overrideWith((_) => Stream.value(true)),
              dashboardNutrientGoalCardsProvider.overrideWith(
                (_) => Stream.value(<String>{}),
              ),
            ],
            child: MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: const DashboardPreferencesPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final pending = find.bySemanticsLabel('Loading saved view');
        expect(pending, findsOneWidget);
        final wait = find.descendant(
          of: pending,
          matching: find.byType(CupertinoActivityIndicator),
        );
        expect(wait, findsOneWidget);
        expect(
          tester.widget<CupertinoActivityIndicator>(wait).color,
          const Color(0xFF697178),
        );
        expect(find.byType(BilSplashCapsuleProgress), findsNothing);
        held.add('calorie');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(pending, findsNothing);
        expect(
          find.byKey(const Key('dashboard-preset-carousel')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
