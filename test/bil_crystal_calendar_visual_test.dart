import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/rendering.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('BIL calendar visual $language dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final font = language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence';
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: visualEvidenceTheme(
                dark
                    ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                    : BilFlagshipTheme.light(isArabic: language == 'ar'),
                fontFamily: font,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: const Key('calendar-visual-root'),
                  child: visualEvidenceTextSurface(child, fontFamily: font),
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showBilCrystalDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 10, 25),
                      currentDate: DateTime(2026, 10, 25),
                      firstDate: DateTime(2026, 10, 1),
                      lastDate: DateTime(2026, 12, 31),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('bil-crystal-arrow-bubble')),
            findsNWidgets(3),
          );
          final numeral = tester.renderObject<RenderParagraph>(find.text('25'));
          expect(
            numeral.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 2),
            ),
            hasLength(1),
            reason: 'A two-digit day must remain on one line at large text.',
          );
          final modeArrow = find.byWidgetPredicate(
            (widget) => widget is BilCrystalArrow && widget.reserveSpace,
          );
          expect(modeArrow, findsOneWidget);
          final local = MaterialLocalizations.of(
            tester.element(find.byType(Scaffold)),
          );
          final month = find.text(local.formatMonthYear(DateTime(2026, 10)));
          expect(
            tester.renderObject<RenderParagraph>(month).didExceedMaxLines,
            isFalse,
            reason: 'Keep the complete month and year readable at large text.',
          );
          expect(
            tester.getRect(modeArrow).overlaps(tester.getRect(month)),
            isFalse,
            reason:
                'The persistent crystal must not cover the month/year label.',
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('calendar-visual-root')),
            matchesGoldenFile(
              'goldens/bil39_calendar_${language}_${dark ? 'dark' : 'light'}_${scale.toInt()}x.png',
            ),
          );
        });
      }
    }
  }
}
