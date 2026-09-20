import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_input_sections.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/quick_macro_entry_dialog.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'Daily Water semantic badge keeps a 12 px title gap in ${direction.name}',
      (tester) async {
        _setPhoneSurface(tester);
        await tester.pumpWidget(
          _localizedApp(
            direction: direction,
            home: const Scaffold(
              body: DailyWaterShortcut(entries: AsyncData([]), onTap: _noop),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shortcut = find.byKey(const Key('daily-log-water-shortcut'));
        final badge = find.descendant(
          of: shortcut,
          matching: find.byType(BilSemanticIconBadge),
        );
        final title = find.descendant(
          of: shortcut,
          matching: find.text('Water'),
        );
        final tile = find.descendant(
          of: shortcut,
          matching: find.byType(ListTile),
        );

        expect(badge, findsOneWidget);
        expect(title, findsOneWidget);
        expect(tester.widget<ListTile>(tile).horizontalTitleGap, 12);
        expect(Directionality.of(tester.element(tile)), direction);
        expect(
          _directionalGap(
            direction: direction,
            leading: tester.getRect(badge),
            title: tester.getRect(title),
          ),
          greaterThanOrEqualTo(12),
        );
      },
    );

    testWidgets(
      'More semantic rows keep a 12 px title gap in ${direction.name}',
      (tester) async {
        _setPhoneSurface(tester);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(FreePlan.createState()),
              ),
            ],
            child: _localizedApp(
              direction: direction,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final title = find.text('Settings');
        await tester.scrollUntilVisible(
          title,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final tile = find.ancestor(of: title, matching: find.byType(ListTile));
        final badge = find.descendant(
          of: tile,
          matching: find.byType(BilSemanticIconBadge),
        );

        expect(tile, findsOneWidget);
        expect(badge, findsOneWidget);
        expect(tester.widget<ListTile>(tile).horizontalTitleGap, 12);
        expect(Directionality.of(tester.element(tile)), direction);
        expect(
          _directionalGap(
            direction: direction,
            leading: tester.getRect(badge),
            title: tester.getRect(title),
          ),
          greaterThanOrEqualTo(12),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Quick Macro info tiles keep a 12 px title gap in ${direction.name}',
      (tester) async {
        _setPhoneSurface(tester);
        await tester.pumpWidget(
          _localizedApp(
            direction: direction,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showQuickMacroEntryDialog(
                    context: context,
                    copy: (english, _) => english,
                    mealLabel: 'Breakfast',
                    initialTime: const TimeOfDay(hour: 9, minute: 41),
                    onSave: (_) async {},
                  ),
                  child: const Text('Open quick macros'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open quick macros'));
        await tester.pumpAndSettle();

        final title = find.text('Meal');
        final tile = find.ancestor(of: title, matching: find.byType(ListTile));
        final badge = find.descendant(
          of: tile,
          matching: find.byType(BilSemanticIconBadge),
        );

        expect(tile, findsOneWidget);
        expect(badge, findsOneWidget);
        expect(tester.widget<ListTile>(tile).horizontalTitleGap, 12);
        expect(Directionality.of(tester.element(tile)), direction);
        expect(
          _directionalGap(
            direction: direction,
            leading: tester.getRect(badge),
            title: tester.getRect(title),
          ),
          greaterThanOrEqualTo(12),
        );
      },
    );
  }
}

void _setPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _localizedApp({
  required TextDirection direction,
  required Widget home,
}) => MaterialApp(
  theme: BilFlagshipTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => Directionality(
    textDirection: direction,
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

double _directionalGap({
  required TextDirection direction,
  required Rect leading,
  required Rect title,
}) => switch (direction) {
  TextDirection.ltr => title.left - leading.right,
  TextDirection.rtl => leading.left - title.right,
};

void _noop() {}
