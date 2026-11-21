import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const copies =
      <
        String,
        ({String title, String prompt, List<String> options, String save})
      >{
        'en': (
          title: 'Weight',
          prompt: 'Choose an option',
          options: ['Pounds', 'Kilograms', 'Stone'],
          save: 'Save',
        ),
        'ar': (
          title: 'الوزن',
          prompt: 'اختر خيارًا',
          options: ['أرطال', 'كيلوغرامات', 'ستون'],
          save: 'حفظ',
        ),
        'fr': (
          title: 'Poids',
          prompt: 'Choisissez une option',
          options: ['Livres', 'Kilogrammes', 'Stones'],
          save: 'Enregistrer',
        ),
        'es': (
          title: 'Peso',
          prompt: 'Elige una opción',
          options: ['Libras', 'Kilogramos', 'Stones'],
          save: 'Guardar',
        ),
        'tr': (
          title: 'Ağırlık',
          prompt: 'Bir seçenek seçin',
          options: ['Pound', 'Kilogram', 'Stone'],
          save: 'Kaydet',
        ),
      };
  for (final entry in copies.entries) {
    final language = entry.key;
    final copy = entry.value;
    testWidgets(
      'unit chooser localized options and accessible Save [$language]',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final preferences = PreferencesRepository(database);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                preferencesRepositoryProvider.overrideWithValue(preferences),
              ],
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: const ReferenceUnitPreferencesPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(ListTile).first);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(AppBar, copy.title), findsOneWidget);
          expect(find.text(copy.prompt), findsOneWidget);
          for (final option in copy.options) {
            expect(find.text(option), findsOneWidget);
            expect(find.text(option).hitTestable(), findsOneWidget);
          }
          if (language != 'en') {
            expect(find.text('Choose your weight'), findsNothing);
            expect(find.text('Choose an option'), findsNothing);
            expect(find.text('Pounds'), findsNothing);
            expect(find.text('Kilograms'), findsNothing);
          }
          final icon = find.widgetWithIcon(IconButton, Icons.check_rounded);
          expect(icon, findsOneWidget);
          final save = find.byTooltip(copy.save);
          expect(save, findsOneWidget);
          final node = tester.getSemantics(save);
          final data = node.getSemanticsData();
          // Tooltip supplies a semantics tooltip, not a label. Android's
          // AccessibilityBridge also maps it to an otherwise unnamed button's
          // content description. Require the real named, actionable node.
          expect(data.tooltip, copy.save);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(data.flagsCollection.isButton, isTrue);
          expect(icon.hitTestable(), findsOneWidget);
          final rect = tester.getRect(icon);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          final viewport = Offset.zero & tester.view.physicalSize;
          expect(
            rect.left >= viewport.left &&
                rect.top >= viewport.top &&
                rect.right <= viewport.right &&
                rect.bottom <= viewport.bottom,
            isTrue,
            reason: 'Save rect: $rect; viewport: $viewport',
          );
          await tester.tap(find.text(copy.options.first));
          await tester.pump();
          // Invoke the actual exposed accessibility action, not a test callback.
          node.owner!.performAction(node.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(
            find.widgetWithIcon(IconButton, Icons.check_rounded),
            findsNothing,
          );
          expect(await preferences.get('units.weight'), 'Pounds');
          expect(await preferences.get('units'), 'imperial');
          expect(tester.takeException(), isNull);
        } finally {
          try {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          } finally {
            semantics.dispose();
          }
        }
      },
    );
  }
}
