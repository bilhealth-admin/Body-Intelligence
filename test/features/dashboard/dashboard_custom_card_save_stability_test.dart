import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final section in DashboardSectionIds.all) {
      for (final failSave in [false, true]) {
        testWidgets('$locale $section ${failSave ? 'failure' : 'success'} '
            'does not flash unrelated controls or move the page', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          final repository = _PendingSectionRepository(database, failSave);
          addTearDown(() async {
            if (!repository.release.isCompleted) repository.release.complete();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            await database.close();
          });
          await repository.set('dashboard.preset', 'calorie');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                preferencesRepositoryProvider.overrideWithValue(repository),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(FreePlan.createState()),
                ),
              ],
              child: MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: BilFlagshipTheme.light().copyWith(
                  platform: TargetPlatform.iOS,
                ),
                home: const DashboardPreferencesPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(Key('dashboard-section-$section'));
          final pageScroll = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(card, 240, scrollable: pageScroll);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final scrollPosition = tester
              .state<ScrollableState>(pageScroll)
              .position;
          final savedOffset = scrollPosition.pixels;
          final savedRect = tester.getRect(card);
          final savedElement = tester.element(card);
          final before = {
            for (final id in DashboardSectionIds.all)
              id: tester
                  .widget<SwitchListTile>(
                    find.byKey(Key('dashboard-section-$id')),
                  )
                  .value,
          };
          await tester.tap(card);
          for (final elapsed in [
            Duration.zero,
            const Duration(milliseconds: 16),
            const Duration(milliseconds: 200),
            const Duration(seconds: 2),
          ]) {
            await tester.pump(elapsed);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(
              find.byKey(Key('dashboard-section-$section-saving')),
              findsOneWidget,
            );
            expect(tester.element(card), same(savedElement));
            expect(tester.getRect(card), savedRect);
            expect(scrollPosition.pixels, closeTo(savedOffset, .1));
            for (final id in DashboardSectionIds.all) {
              final tile = tester.widget<SwitchListTile>(
                find.byKey(Key('dashboard-section-$id')),
              );
              expect(
                tile.onChanged,
                isNotNull,
                reason: '$id must not dim while $section saves',
              );
              expect(
                tile.value,
                before[id],
                reason: 'Only committed preferences change',
              );
            }
            final done = tester.widget<FilledButton>(
              find.byKey(const Key('dashboard-preferences-done')),
            );
            expect(
              done.onPressed,
              isNotNull,
              reason: 'Done keeps its enabled appearance',
            );
            done.onPressed!(); // The handler still prevents leaving mid-commit.
            expect(find.byType(DashboardPreferencesPage), findsOneWidget);
            expect(
              tester.widget<PopScope>(find.byType(PopScope)).canPop,
              isFalse,
            );
          }
          final other = DashboardSectionIds.all.firstWhere(
            (id) => id != section,
          );
          tester
              .widget<SwitchListTile>(
                find.byKey(Key('dashboard-section-$other')),
              )
              .onChanged!(!before[other]!);
          tester.widget<SwitchListTile>(card).onChanged!(!before[section]!);
          expect(
            repository.writeCount,
            1,
            reason: 'No duplicate or conflicting writes',
          );
          repository.release.complete();
          await tester.pumpAndSettle();
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.getRect(card), savedRect);
          expect(scrollPosition.pixels, closeTo(savedOffset, .1));
          expect(
            tester.widget<SwitchListTile>(card).value,
            failSave ? before[section] : !before[section]!,
          );
          expect(
            await repository.get('dashboard.preset'),
            failSave ? 'calorie' : 'custom',
          );
          expect(
            await repository.get('dashboard.section.$section'),
            failSave ? isNull : (!before[section]!).toString(),
          );
          expect(
            find.byType(SnackBar),
            failSave ? findsOneWidget : findsNothing,
          );
          expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
          expect(tester.takeException(), isNull);
          // Dispose streams before Flutter checks for pending timers;
          // addTearDown runs after that invariant check.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}

class _PendingSectionRepository extends PreferencesRepository {
  _PendingSectionRepository(super.database, this.failSave);
  final bool failSave;
  final release = Completer<void>();
  int writeCount = 0;

  @override
  Future<void> setMany(Map<String, String> values) async {
    writeCount++;
    await release.future;
    if (failSave) throw StateError('simulated disk write failure');
    await super.setMany(values);
  }
}
