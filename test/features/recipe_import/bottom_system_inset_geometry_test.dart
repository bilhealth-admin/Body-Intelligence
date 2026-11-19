import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/presentation/trusted_recipe_import_page.dart';
import 'package:body_intelligence_log/features/recipe_import/providers/trusted_recipe_providers.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:body_intelligence_log/shared/widgets/bil_modal_bottom_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';

Widget _app({
  required Widget home,
  required TargetPlatform platform,
  required String language,
  required double scale,
  required double bottom,
}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: visualEvidenceTheme(
    BilFlagshipTheme.light(
      isArabic: language == 'ar',
    ).copyWith(platform: platform),
    fontFamily: language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: EdgeInsets.only(top: 24, bottom: bottom),
      viewPadding: EdgeInsets.only(top: 24, bottom: bottom),
      viewInsets: EdgeInsets.zero,
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: home,
);

void _fullyReachable(WidgetTester tester, Finder control, double bottom) {
  expect(control.hitTestable(), findsOneWidget);
  final rect = tester.getRect(control);
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(rect.top, greaterThanOrEqualTo(24));
  expect(
    rect.bottom,
    lessThanOrEqualTo(800 - bottom + .5),
    reason:
        'The entire action, not just its centre, stays above the reserved system navigation area.',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final bottom in [24.0, 48.0]) {
      for (final mode in [('en', 1.0), ('ar', 2.5)]) {
        final label = '${platform.name} bottom$bottom ${mode.$1} ${mode.$2}x';
        testWidgets(
          'real recipe page Review remains fully reachable with $label',
          (tester) async {
            tester.view.physicalSize = const Size(360, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            final recipes = TrustedRecipeRepository(PreferencesRepository(db));
            try {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    trustedRecipeRepositoryProvider.overrideWithValue(recipes),
                  ],
                  child: _app(
                    home: const TrustedRecipeImportPage(),
                    platform: platform,
                    language: mode.$1,
                    scale: mode.$2,
                    bottom: bottom,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final form = find.byKey(const Key('recipe-draft-form'));
              // Ordinary scrolling reaches the real end of the production form.
              await tester.drag(form, const Offset(0, -6000));
              await tester.pumpAndSettle();
              final review = find.byKey(const Key('review-imported-recipe'));
              final scrolling = tester
                  .state<ScrollableState>(
                    find
                        .descendant(of: form, matching: find.byType(Scrollable))
                        .first,
                  )
                  .position;
              // The lazy list can revise its extent after the first long drag.
              // Continue ordinary swipes until its measured real end is reached.
              for (
                var attempt = 0;
                attempt < 8 &&
                    scrolling.pixels < scrolling.maxScrollExtent - .5;
                attempt++
              ) {
                await tester.drag(form, const Offset(0, -320));
                await tester.pumpAndSettle();
              }
              expect(scrolling.pixels, closeTo(scrolling.maxScrollExtent, .5));
              expect(
                Directionality.of(tester.element(review)),
                mode.$1 == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
              _fullyReachable(tester, review, bottom);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.runAsync(db.close);
            }
          },
        );
        testWidgets(
          'existing Quick Add scroll reaches every later action with $label',
          (tester) async {
            tester.view.physicalSize = const Size(360, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final selected = <String>[];
            await tester.pumpWidget(
              _app(
                platform: platform,
                language: mode.$1,
                scale: mode.$2,
                bottom: bottom,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      key: const Key('open-owned-quick-add'),
                      onPressed: () async {
                        await showBilModalBottomSheet<void>(
                          context: context,
                          useSafeArea: true,
                          isScrollControlled: true,
                          showDragHandle: false,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BilQuickAddSheet(
                            onFood: () {},
                            onBarcode: () {},
                            onVoice: () {},
                            onPhoto: () {},
                            onExercise: () => selected.add('exercise'),
                            onNotes: () => selected.add('notes'),
                            onSearch: () => selected.add('search'),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('open-owned-quick-add')));
            await tester.pumpAndSettle();
            final scrollable = find
                .descendant(
                  of: find.byType(BilQuickAddSheet),
                  matching: find.byType(Scrollable),
                )
                .first;
            for (var index = 0; index < 3; index++) {
              final action = find.byKey(Key('quick-add-secondary-$index'));
              await tester.scrollUntilVisible(
                action,
                120,
                scrollable: scrollable,
                maxScrolls: 15,
              );
              await tester.pumpAndSettle();
              _fullyReachable(tester, action, bottom);
              await tester.tap(action);
              await tester.pump();
            }
            expect(selected, ['exercise', 'notes', 'search']);
            // Closing the actual modal also cleans its process-wide sheet lease.
            final context = tester.element(find.byType(BilQuickAddSheet));
            Navigator.of(context, rootNavigator: true).pop();
            await tester.pumpAndSettle();
            expect(find.byType(BilQuickAddSheet), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
