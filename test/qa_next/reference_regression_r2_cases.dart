import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_next_workspace.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void registerReferenceRegressionCases() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('shared navigation survives missing BIL delegate $locale', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            bottomNavigationBar: BilReferenceBottomBar(
              selected: 3,
              onSelected: taps.add,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final home = NextWorkspaceRuntimeCopy.resolve(
        'Home',
        locale.toLanguageTag(),
      );
      expect(find.text(home!), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(Key('bil-reference-nav-$i')));
      }
      expect(taps, [0, 1, 2, 3, 4]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'Arabic and mixed script text has bundled fallback in English UI',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachMessageText(
              text: 'Breakfast سجل فطوري',
              createdAt: DateTime(2026, 10, 5),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'Roboto'),
            ),
          ),
        ),
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, 'Breakfast سجل فطوري');
      expect(text.style!.fontFamilyFallback, contains('BILArabic'));
      expect(text.style!.fontFamily, 'Roboto');
      expect(tester.takeException(), isNull);
    },
  );
}
