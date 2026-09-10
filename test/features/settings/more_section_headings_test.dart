import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/admin/services/ai_coach_admin_service.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_copy.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('administration heading has reviewed core-locale translations', () {
    const translations = {
      'ar': 'الإدارة',
      'fr': 'Administration',
      'es': 'Administración',
      'tr': 'Yönetim',
    };
    for (final entry in translations.entries) {
      expect(
        ReferenceSettingsCopy.resolve('Administration', entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
        '${platform.name}/${locale.languageCode} More headings are text-only while action icons remain',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(FreePlan.createState()),
                ),
                aiCoachAdminAccessProvider.overrideWith((ref) async => true),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const SettingsPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final copy = ReferenceSettingsCopy.of(
            tester.element(find.byType(SettingsPage)),
          );
          final sectionTitles = [
            'Account & profile',
            'Diary & goals',
            'Health preferences',
            if (AppEnvironment.communityConfigured) 'Community',
            'Privacy & notifications',
            'Help',
            'Administration',
          ];
          for (final title in sectionTitles) {
            final localizedTitle = copy(title);
            final heading = find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data == localizedTitle &&
                  widget.style?.fontWeight == FontWeight.w800,
              description: 'More section heading: $title',
            );
            await tester.scrollUntilVisible(heading, 250);
            expect(heading, findsOneWidget);
            expect(
              Directionality.of(tester.element(heading)),
              locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            );

            final headerPadding = tester
                .element(heading)
                .findAncestorWidgetOfExactType<Padding>()!;
            expect(
              find.descendant(
                of: find.byWidget(headerPadding),
                matching: find.byType(BilSemanticIconBadge),
              ),
              findsNothing,
              reason: '$title must not repeat the action-row icon',
            );

            final section = find.ancestor(
              of: heading,
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MoreSection',
              ),
            );
            final rows = tester.widgetList<ListTile>(
              find.descendant(of: section, matching: find.byType(ListTile)),
            );
            expect(rows, isNotEmpty, reason: '$title keeps its action rows');
            for (final row in rows) {
              expect(row.leading, isA<BilSemanticIconBadge>());
              expect(row.onTap, isNotNull);
            }
            expect(tester.takeException(), isNull);
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
