import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_message_presentation.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_plain_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_presentation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'support/coach_message_presentation_fixture.dart';

Future<void> mountMessageBody(
  WidgetTester tester,
  Widget Function(BuildContext) body, {
  bool arabic = false,
  bool dark = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final theme = dark
      ? BilFlagshipTheme.dark(isArabic: arabic)
      : BilFlagshipTheme.light(isArabic: arabic);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(arabic ? 'ar' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        theme,
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Builder(builder: body),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  group('assistant body visual integration', () {
    testWidgets(
      'saved comparison notes use selected units without changing canonical kg cm or inventing unknown differences',
      (tester) async {
        final previous = CoachVisualWeightPoint(
          recordedAtUtc: DateTime.utc(2026, 10, 4),
          dayKey: '2026-10-04',
          kg: 84,
          context: 'morning',
        );
        final saved = CoachVisualWeightPoint(
          recordedAtUtc: DateTime.utc(2026, 10, 6),
          dayKey: '2026-10-06',
          kg: 82.4,
          context: 'differentConditions',
        );
        String? weightNote, measurementsNote;
        CoachVisualNutritionColumn column(
          String day,
          double waist,
          double? neck,
        ) => CoachVisualNutritionColumn(
          title: 'Body measurements',
          dayKey: day,
          metrics: [fixtureMetric('waist', waist), fixtureMetric('neck', neck)],
          sourceKinds: const ['saved_measurements'],
          capturedAtUtc: presentationFixtureClock,
        );
        final beforeMeasurements = column('2026-10-04', 89, null);
        final savedMeasurements = column('2026-10-06', 87, 38);
        await mountMessageBody(tester, (context) {
          final copy = CoachMessagePlainCopy(
            context,
            system: MeasurementSystem.imperial,
          );
          weightNote = copy.previousWeightNote(previous, saved);
          measurementsNote = copy.previousMeasurementNote(
            beforeMeasurements,
            savedMeasurements,
          );
          return CoachMessagePresentationView(
            presentation: CoachMessagePresentation.localRead(
              ownerKey: presentationFixtureOwnerKey,
              capturedAtUtc: presentationFixtureClock,
              kind: CoachVisualKind.weight,
              title: 'Weight',
              fromDay: saved.dayKey,
              throughDay: saved.dayKey,
              weightPoints: [saved],
              notes: [weightNote!],
            ),
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
            copy: copy,
          );
        });
        expect(find.text('181.66 lb'), findsOneWidget);
        expect(weightNote, contains('-3.53 lb'));
        expect(weightNote, contains('Oct 4, 2026'));
        expect(weightNote, contains('Measurement conditions may differ.'));
        expect(measurementsNote, contains('Waist: -0.79 in'));
        expect(measurementsNote, isNot(contains('Neck:')));
        expect(saved.kg, 82.4);
        expect(savedMeasurements.metrics.first.completeValue, 87);
        expect(
          find.byKey(const ValueKey('coach-weight-timeline')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'partial estimated subtotal announces coverage and unknown does not become zero',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final visual = fixtureVisual(
          columns: [
            CoachVisualNutritionColumn(
              title: 'Lunch',
              dayKey: '2026-10-09',
              mealType: 'lunch',
              capturedAtUtc: presentationFixtureClock,
              sourceKinds: const ['estimated_portion'],
              metrics: [
                fixtureMetric(
                  'fiber',
                  2,
                  known: 1,
                  missing: 1,
                  estimated: true,
                ),
                fixtureMetric('magnesium', null),
              ],
            ),
          ],
        );
        try {
          await mountMessageBody(
            tester,
            (context) => CoachMessagePresentationView(
              presentation: visual,
              expectedOwnerKey: presentationFixtureOwnerKey,
              ownerVisitIsCurrent: () => true,
            ),
          );
          expect(find.text('~2 g'), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              RegExp('Fiber:.*incomplete coverage.*Estimated'),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Nutrition details'));
          await tester.tap(find.text('Nutrition details'));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Magnesium: Unknown'), findsOneWidget);
          expect(find.text('0 mg'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          semantics.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'multi-day comparison has a real horizontal table without 31 giant cards',
      (tester) async {
        final columns = List.generate(
          20,
          (i) => CoachVisualNutritionColumn(
            title: 'Day summary',
            dayKey: '2026-10-${(i + 1).toString().padLeft(2, '0')}',
            capturedAtUtc: presentationFixtureClock,
            metrics: [fixtureMetric('calories', 100 + i.toDouble())],
            sourceKinds: const ['immutable_food_details'],
          ),
        );
        final visual = CoachMessagePresentation.localRead(
          ownerKey: presentationFixtureOwnerKey,
          capturedAtUtc: DateTime.utc(2026, 10, 20),
          kind: CoachVisualKind.comparison,
          title: 'Comparison',
          fromDay: '2026-10-01',
          throughDay: '2026-10-20',
          columns: columns,
        );
        await mountMessageBody(
          tester,
          (context) => CoachMessagePresentationView(
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          ),
          width: 600,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Comparison'));
        await tester.pumpAndSettle();
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        expect(horizontal, findsOneWidget);
        await tester.drag(horizontal, const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'ordinary text stays text and does not create a card',
      (tester) async {
        await mountMessageBody(
          tester,
          (context) => CoachMessageBody(
            text: 'A brief ordinary answer.',
            archive: null,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
            textBuilder: (text) => SelectableText(text),
          ),
        );
        expect(find.text('A brief ordinary answer.'), findsOneWidget);
        expect(find.byType(CoachMessagePresentationView), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'invalid same-owner block falls back to text without raw JSON',
      (tester) async {
        await mountMessageBody(
          tester,
          (context) => CoachMessageBody(
            text: 'Saved readable explanation.',
            archive: {
              'schema': 'new-v99',
              'ownerKey': presentationFixtureOwnerKey,
            },
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
            textBuilder: (text) => SelectableText(text),
          ),
        );
        expect(find.text('Saved readable explanation.'), findsOneWidget);
        expect(find.textContaining('new-v99'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'confirmed foreign-owner block hides facts in fallback and copy',
      (tester) async {
        String? plain;
        await mountMessageBody(tester, (context) {
          plain = CoachMessagePlainCopy(context).plain(
            fallback: 'Foreign private health 777',
            presentation: null,
            archivedOwnerKey: 'foreign-owner',
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          );
          return CoachMessageBody(
            text: 'Foreign private health 777',
            archive: {'schema': 'unknown', 'ownerKey': 'foreign-owner'},
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
            textBuilder: (text) => SelectableText(text),
          );
        });
        expect(find.textContaining('777'), findsNothing);
        expect(plain, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'same fact projection renders known zero unknown fiber net and copy',
      (tester) async {
        String? plain;
        final visual = fixtureVisual();
        await mountMessageBody(tester, (context) {
          final copy = CoachMessagePlainCopy(context);
          plain = copy.plain(
            fallback: 'Do not duplicate this prose.',
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          );
          return CoachMessageBody(
            text: 'Do not duplicate this prose.',
            archive: null,
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
            copy: copy,
            textBuilder: (text) => SelectableText(text),
          );
        });
        expect(find.text('Do not duplicate this prose.'), findsNothing);
        expect(find.text('130 kcal'), findsOneWidget);
        final caloriesText = tester.widget<Text>(
          find.byKey(const ValueKey('coach-fact-calories')),
        );
        final spans = (caloriesText.textSpan! as TextSpan).children!;
        expect(caloriesText.textSpan!.toPlainText(), '130 kcal');
        expect((spans.first as TextSpan).text, '130');
        final unit = spans.last as TextSpan;
        expect(unit.text, ' kcal');
        expect(unit.style!.fontSize!, lessThan(caloriesText.style!.fontSize!));
        expect(find.text('0 mg'), findsOneWidget);
        expect(find.text('Fiber'), findsOneWidget);
        expect(find.text('Net carbs'), findsOneWidget);
        expect(plain, contains('Fiber: 2 g'));
        expect(plain, contains('Potassium: 0 mg'));
        expect(plain, contains('Magnesium: Unknown'));
        expect(plain, contains('Net carbs: 16 g'));
        expect(plain, contains('Vitamin A: Unknown'));
        expect(plain, isNot(contains(presentationFixtureOwnerKey)));
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'folding actual nutrition details shows sources and never changes facts',
      (tester) async {
        final visual = fixtureVisual();
        await mountMessageBody(
          tester,
          (context) => CoachMessagePresentationView(
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          ),
        );
        expect(find.text('Vitamin A'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('coach-nutrition-details')),
        );
        await tester.tap(find.text('Nutrition details'));
        await tester.pumpAndSettle();
        expect(find.text('Vitamin A'), findsOneWidget);
        expect(find.text('Reference'), findsOneWidget);
        expect(visual.columns.single.metrics.first.completeValue, 130);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    testWidgets(
      'actual dated weight points stay sparse selectable and neutral',
      (tester) async {
        final visual = fixtureWeight();
        String? plain;
        await mountMessageBody(tester, (context) {
          plain = CoachMessagePlainCopy(context).plain(
            fallback: '',
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          );
          return CoachMessagePresentationView(
            presentation: visual,
            expectedOwnerKey: presentationFixtureOwnerKey,
            ownerVisitIsCurrent: () => true,
          );
        });
        expect(find.text('81.5 kg'), findsOneWidget);
        final rect = tester.getRect(
          find.byKey(const ValueKey('coach-weight-timeline')),
        );
        await tester.tapAt(Offset(rect.left + 8, rect.center.dy));
        await tester.pump();
        expect(find.text('81.4 kg'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('coach-weight-point-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('coach-weight-point-3')),
          findsNothing,
        );
        expect(plain, contains('81.7 kg'));
        expect(plain, contains('Difference: -0.2 kg'));
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    for (final arabic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          'comparison adapts 320px 2x ${arabic ? 'AR ' : 'EN '}${dark ? 'dark' : 'light'}',
          (tester) async {
            final visual = fixtureVisual(
              kind: CoachVisualKind.comparison,
              columns: [
                fixtureColumn(),
                fixtureColumn(meal: 'dinner'),
              ],
            );
            await mountMessageBody(
              tester,
              (context) => CoachMessagePresentationView(
                presentation: visual,
                expectedOwnerKey: presentationFixtureOwnerKey,
                ownerVisitIsCurrent: () => true,
              ),
              arabic: arabic,
              dark: dark,
              width: 320,
              scale: 2,
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(CoachMessagePresentationView), findsOneWidget);
            expect(find.text(arabic ? 'الغداء' : 'Lunch'), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          timeout: const Timeout(Duration(seconds: 60)),
        );
      }
    }
  });
}
